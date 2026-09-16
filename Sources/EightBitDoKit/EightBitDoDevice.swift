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
    
    public func resetOrientation() {
        decoder.resetOrientation()
    }
    
    /// Issues a force-feedback rumble report (Output Report ID 5) to the controller motors.
    /// - Parameters:
    ///   - lowFrequency: Heavy rumble motor (0.0 to 1.0)
    ///   - highFrequency: Light rumble motor (0.0 to 1.0)
    public func sendRumble(lowFrequency: Float, highFrequency: Float) {
        let intensity = max(0.0, min(1.0, max(lowFrequency, highFrequency)))
        let val = UInt8(intensity * 100.0)
        sendRumbleRaw(val)
    }
    
    public func sendRumble(lowFrequency: Float, highFrequency: Float, duration: TimeInterval) {
        sendRumble(lowFrequency: lowFrequency, highFrequency: highFrequency)
        queue.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.stopRumble()
        }
    }
    
    public func stopRumble() {
        sendRumbleRaw(0)
    }
    
    public func sendRumbleRaw(_ val: UInt8) {
        lock.lock()
        guard let dev = device else {
            lock.unlock()
            return
        }
        lock.unlock()
        
        queue.async {
            var report: [UInt8] = [val, val, val, val]
            let res = IOHIDDeviceSetReport(
                dev,
                kIOHIDReportTypeOutput,
                CFIndex(EightBitDoConstants.outputReportID),
                &report,
                CFIndex(report.count)
            )
            if res != kIOReturnSuccess {
                // Re-open device if communication timed out
                _ = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
                _ = IOHIDDeviceSetReport(
                    dev,
                    kIOHIDReportTypeOutput,
                    CFIndex(EightBitDoConstants.outputReportID),
                    &report,
                    CFIndex(report.count)
                )
            }
        }
    }
    
    // MARK: - Private Setup
    
    private func setupManager() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        manager = mgr
        
        IOHIDManagerSetDeviceMatching(mgr, nil)
        let openRes = IOHIDManagerOpen(mgr, IOOptionBits(kIOHIDOptionsTypeNone))
        if openRes != kIOReturnSuccess {
            print("[EightBitDoKit] Failed to open IOHIDManager: \(openRes)")
            return
        }
        
        scanForDevice()
        
        // Start periodic scan timer to handle controller wake from sleep
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1.0, repeating: 1.5)
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
            let pid = getIntProperty(device: dev, key: kIOHIDProductIDKey)
            let name = getStringProperty(device: dev, key: kIOHIDProductKey) ?? ""
            
            let isVendorMatch = (vid == EightBitDoConstants.vendorID) && (EightBitDoConstants.supportedProductIDs.contains(pid) || pid == 0)
            let isNameMatch = name.contains("8BitDo") && (name.contains("Ultimate") || name.contains("Wireless"))
            
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
        
        if let runLoop = CFRunLoopGetMain() {
            IOHIDDeviceScheduleWithRunLoop(dev, runLoop, CFRunLoopMode.commonModes.rawValue)
        }
        
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
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.deviceName = name
            self.isConnected = true
            self.onConnectionChanged?(true)
            print("[EightBitDoKit] Connected: \(name)")
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
