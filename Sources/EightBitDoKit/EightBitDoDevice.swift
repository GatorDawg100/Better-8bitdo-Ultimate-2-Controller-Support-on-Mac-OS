import Foundation
@preconcurrency import IOKit
@preconcurrency import IOKit.hid
import Combine

/// Native macOS IOKit Driver for the 8BitDo Ultimate 2 Wireless Controller in 2.4GHz / D-Input mode.
public final class EightBitDoDevice: ObservableObject, @unchecked Sendable {
    public static let shared = EightBitDoDevice()
    
    // Published State
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var state: EightBitDoState = EightBitDoState()
    @Published public private(set) var deviceName: String = "8BitDo Ultimate 2 Wireless"
    @Published public private(set) var packetsPerSecond: Double = 0.0
    
    // Callbacks
    public var onStateChanged: (@Sendable (EightBitDoState) -> Void)?
    public var onConnectionChanged: (@Sendable (Bool) -> Void)?
    public var onRawReportReceived: (@Sendable (Data) -> Void)?
    
    // Modern Swift Concurrency AsyncStreams
    private var stateContinuations: [UUID: AsyncStream<EightBitDoState>.Continuation] = [:]
    private var connectionContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
    
    /// Asynchronous stream of incoming controller state updates (500 Hz).
    /// Can be consumed directly using `for await state in device.states`.
    public var states: AsyncStream<EightBitDoState> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.stateContinuations[id] = continuation
            self.lock.unlock()
            
            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.stateContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
    
    /// Asynchronous stream of controller connection state changes.
    /// Yields the current connection state immediately upon subscription.
    public var connections: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            self.lock.lock()
            self.connectionContinuations[id] = continuation
            let currentConnection = self.device != nil
            self.lock.unlock()
            
            continuation.yield(currentConnection)
            
            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.connectionContinuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }
    
    /// Packet decoder and IMU sensor fusion configuration
    public var configuration: EightBitDoPacketDecoder.Configuration {
        get { decoder.configuration }
        set { decoder.configuration = newValue }
    }
    
    /// Current estimated stationary zero-rate gyroscope bias in deg/s (X, Y, Z).
    public var gyroBiasDeg: SIMD3<Float> {
        decoder.currentGyroBiasDeg
    }
    
    // Internal IOKit state
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var reportBuffer: UnsafeMutablePointer<UInt8>?
    private let decoder = EightBitDoPacketDecoder()
    
    private let queue = DispatchQueue(label: "com.deencodes.eightbitdo.driver", qos: .userInteractive)
    private var packetCounter: UInt64 = 0
    private var lastRateCalcTime: TimeInterval = 0
    private var ratePacketCount: UInt64 = 0
    private var scanTimer: DispatchSourceTimer?
    private let lock = NSLock()
    
    public init() {
        reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
    }
    
    deinit {
        stop()
        if let buf = reportBuffer {
            buf.deallocate()
            reportBuffer = nil
        }
    }
    
    /// Starts the IOHIDManager and listens for the 8BitDo controller.
    public func start() {
        queue.async { [weak self] in
            self?.setupManager()
        }
    }
    
    /// Stops the driver and releases IOKit resources.
    public func stop() {
        scanTimer?.cancel()
        scanTimer = nil
        
        lock.lock()
        for c in stateContinuations.values {
            c.finish()
        }
        stateContinuations.removeAll()
        for c in connectionContinuations.values {
            c.finish()
        }
        connectionContinuations.removeAll()
        
        if let dev = device {
            if let buf = reportBuffer {
                IOHIDDeviceRegisterInputReportCallback(dev, buf, 64, nil, nil)
            }
            IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
            device = nil
        }
        if let mgr = manager {
            IOHIDManagerClose(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
            manager = nil
        }
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
        }
    }
    
    /// Resets the estimated attitude and accumulated yaw to zero.
    public func resetOrientation() {
        decoder.resetOrientation()
    }
    
    /// Resets the estimated attitude to specific pitch, roll, and yaw angles.
    public func resetOrientation(pitch: Float = 0, roll: Float = 0, yaw: Float = 0) {
        decoder.resetOrientation(pitch: pitch, roll: roll, yaw: yaw)
    }
    
    /// Resets the stationary gyroscope zero-rate bias estimation.
    public func resetGyroBias() {
        decoder.resetGyroBias()
    }
    
    /// Sets a manual zero-rate gyro drift bias offset in deg/s.
    public func setGyroBias(deg: SIMD3<Float>) {
        decoder.setGyroBias(deg: deg)
    }
    
    /// Issues a force-feedback rumble report to the controller motors.
    /// - Parameters:
    ///   - lowFrequency: Heavy rumble motor (0.0 to 1.0)
    ///   - highFrequency: Light rumble motor (0.0 to 1.0)
    public func sendRumble(lowFrequency: Float, highFrequency: Float) {
        let heavy = UInt8(max(0.0, min(1.0, lowFrequency)) * 100.0)
        let light = UInt8(max(0.0, min(1.0, highFrequency)) * 100.0)
        sendRumbleMotors(heavy: heavy, light: light)
    }
    
    /// Issues a force-feedback rumble report for `duration` seconds via a dispatch timer.
    public func sendRumble(lowFrequency: Float, highFrequency: Float, duration: TimeInterval) {
        sendRumble(lowFrequency: lowFrequency, highFrequency: highFrequency)
        queue.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopRumble()
        }
    }
    
    /// Asynchronously activates the rumble motors for `duration` seconds and suspends until finished.
    /// Automatically stops the rumble if the task is cancelled or duration expires.
    public func sendRumble(lowFrequency: Float, highFrequency: Float, duration: TimeInterval) async {
        sendRumble(lowFrequency: lowFrequency, highFrequency: highFrequency)
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, duration) * 1_000_000_000))
        } catch {
            // Task cancelled early
        }
        stopRumble()
    }
    
    public func stopRumble() {
        sendRumbleMotors(heavy: 0, light: 0)
    }
    
    public func sendRumbleRaw(_ val: UInt8) {
        sendRumbleMotors(heavy: val, light: val)
    }
    
    public func sendRumbleMotors(heavy: UInt8, light: UInt8) {
        lock.lock()
        guard let dev = device else {
            lock.unlock()
            return
        }
        lock.unlock()
        
        queue.async {
            // Output Report ID 5: [heavy, light, heavy, light]
            var report5: [UInt8] = [heavy, light, heavy, light]
            let res = IOHIDDeviceSetReport(
                dev,
                kIOHIDReportTypeOutput,
                CFIndex(EightBitDoConstants.outputReportID),
                &report5,
                CFIndex(report5.count)
            )
            
            if res != kIOReturnSuccess {
                // Feature Report fallback
                _ = IOHIDDeviceSetReport(
                    dev,
                    kIOHIDReportTypeFeature,
                    CFIndex(EightBitDoConstants.outputReportID),
                    &report5,
                    CFIndex(report5.count)
                )
                
                // 2-byte Output Report fallback: [heavy, light]
                var report2: [UInt8] = [heavy, light]
                _ = IOHIDDeviceSetReport(
                    dev,
                    kIOHIDReportTypeOutput,
                    1,
                    &report2,
                    CFIndex(report2.count)
                )
            }
        }
    }
    
    // MARK: - Private Setup
    
    private func setupManager() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        
        let matchDict = [
            kIOHIDVendorIDKey as String: EightBitDoConstants.vendorID
        ] as CFDictionary
        IOHIDManagerSetDeviceMatching(mgr, matchDict)
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(mgr, { context, result, sender, device in
            guard let context = context else { return }
            let driver = Unmanaged<EightBitDoDevice>.fromOpaque(context).takeUnretainedValue()
            driver.attachDevice(device)
        }, context)
        
        IOHIDManagerRegisterDeviceRemovalCallback(mgr, { context, result, sender, device in
            guard let context = context else { return }
            let driver = Unmanaged<EightBitDoDevice>.fromOpaque(context).takeUnretainedValue()
            driver.detachDevice(device)
        }, context)
        
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openRes = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRes != kIOReturnSuccess {
            print("[EightBitDoKit] Failed to open IOHIDManager: \(openRes)")
            return
        }
        
        scanForDevice()
        
        // Start periodic scan timer to handle controller wake from sleep
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 2.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let connected = self.device != nil
            self.lock.unlock()
            if !connected {
                self.scanForDevice()
            }
        }
        timer.resume()
        scanTimer = timer
    }
    
    private func scanForDevice() {
        guard let mgr = manager else { return }
        guard let deviceSet = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> else { return }
        
        for dev in deviceSet {
            let vid = getIntProperty(device: dev, key: kIOHIDVendorIDKey)
            let name = (getStringProperty(device: dev, key: kIOHIDProductKey) ?? "").lowercased()
            
            let isVendorMatch = (vid == EightBitDoConstants.vendorID)
            let isNameMatch = name.contains("8bitdo") || name.contains("ultimate")
            
            if isVendorMatch || isNameMatch {
                attachDevice(dev)
                break
            }
        }
    }
    
    private func attachDevice(_ dev: IOHIDDevice) {
        lock.lock()
        if device == dev {
            lock.unlock()
            return
        }
        device = dev
        lock.unlock()
        
        let openRes = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRes != kIOReturnSuccess {
            print("[EightBitDoKit] Failed to open IOHIDDevice: \(openRes)")
            return
        }
        
        IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        
        guard let buffer = reportBuffer else { return }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            dev,
            buffer,
            64,
            { context, result, sender, type, reportID, report, reportLength in
                guard let ctx = context, result == kIOReturnSuccess else { return }
                let driver = Unmanaged<EightBitDoDevice>.fromOpaque(ctx).takeUnretainedValue()
                driver.handleInputReport(report: report, length: reportLength)
            },
            context
        )
        
        let name = getStringProperty(device: dev, key: kIOHIDProductKey) ?? "8BitDo Ultimate 2 Wireless"
        
        lock.lock()
        let connContinuations = Array(connectionContinuations.values)
        lock.unlock()
        for c in connContinuations {
            c.yield(true)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deviceName = name
            self.isConnected = true
            self.onConnectionChanged?(true)
            print("[EightBitDoKit] Connected: \(name)")
        }
    }
    
    private func detachDevice(_ dev: IOHIDDevice) {
        lock.lock()
        guard device == dev else {
            lock.unlock()
            return
        }
        device = nil
        let connContinuations = Array(connectionContinuations.values)
        lock.unlock()
        
        for c in connContinuations {
            c.yield(false)
        }
        
        IOHIDDeviceUnscheduleFromRunLoop(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        if let buf = reportBuffer {
            IOHIDDeviceRegisterInputReportCallback(dev, buf, 64, nil, nil)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isConnected = false
            self.onConnectionChanged?(false)
            print("[EightBitDoKit] Disconnected")
        }
    }
    
    private func handleInputReport(report: UnsafePointer<UInt8>, length: CFIndex) {
        guard length >= 27 else { return }
        let data = Data(bytes: report, count: length)
        let now = ProcessInfo.processInfo.systemUptime
        
        guard let newState = decoder.decode(data: data, timestamp: now) else { return }
        
        // Rate calculation
        packetCounter += 1
        ratePacketCount += 1
        if now - lastRateCalcTime >= 1.0 {
            let elapsed = now - lastRateCalcTime
            let rate = Double(ratePacketCount) / elapsed
            lastRateCalcTime = now
            ratePacketCount = 0
            DispatchQueue.main.async { [weak self] in
                self?.packetsPerSecond = rate
            }
        }
        
        onRawReportReceived?(data)
        onStateChanged?(newState)
        
        lock.lock()
        let continuations = Array(stateContinuations.values)
        lock.unlock()
        for c in continuations {
            c.yield(newState)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
    
    private func getIntProperty(device: IOHIDDevice, key: String) -> Int {
        guard let prop = IOHIDDeviceGetProperty(device, key as CFString) else { return 0 }
        var val: Int = 0
        if CFGetTypeID(prop) == CFNumberGetTypeID() {
            CFNumberGetValue((prop as! CFNumber), .intType, &val)
        }
        return val
    }
    
    private func getStringProperty(device: IOHIDDevice, key: String) -> String? {
        guard let prop = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
        if CFGetTypeID(prop) == CFStringGetTypeID() {
            return (prop as! String)
        }
        return nil
    }
}
