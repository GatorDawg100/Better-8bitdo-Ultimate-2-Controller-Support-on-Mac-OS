import Foundation
import IOKit
import IOKit.hid
#if canImport(CoreHID)
import CoreHID
#endif

public enum DualSenseVirtualDeviceError: LocalizedError {
    case accessibilityDenied
    case deviceCreationFailed
    case dispatchFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .accessibilityDenied:
            return "Accessibility permission is required by macOS to create virtual controllers. Please enable it in System Settings > Privacy & Security > Accessibility."
        case .deviceCreationFailed:
            return "Failed to instantiate virtual DualSense HID device. Ensure the app has Accessibility permissions and restart."
        case .dispatchFailed(let reason):
            return "Failed to dispatch input report to virtual DualSense: \(reason)"
        }
    }
}

/// Creates and manages the virtual DualSense controller on macOS using CoreHID or IOKit.
public actor DualSenseVirtualDevice {
    public var onRumbleReceived: (@Sendable (Float, Float) -> Void)?
    
    private var isStarted = false
    
    #if canImport(CoreHID)
    @available(macOS 15, *)
    private final class VirtualDeviceDelegateWrapper: HIDVirtualDeviceDelegate, @unchecked Sendable {
        weak var parent: DualSenseVirtualDevice?
        
        init(parent: DualSenseVirtualDevice) {
            self.parent = parent
        }
        
        func hidVirtualDevice(
            _ device: HIDVirtualDevice,
            receivedSetReportRequestOfType type: HIDReportType,
            id: HIDReportID?,
            data: Data
        ) async throws {
            if let parent = parent {
                await parent.handleOutputReport(data: data)
            }
        }
        
        func hidVirtualDevice(
            _ device: HIDVirtualDevice,
            receivedGetReportRequestOfType type: HIDReportType,
            id: HIDReportID?,
            maxSize: Int
        ) async throws -> Data {
            return Data()
        }
    }
    
    private var coreHIDDevice: Any? // HIDVirtualDevice
    private var coreHIDDelegate: Any?
    #endif
    
    // IOKit Fallback Device
    private var ioKitDevice: IOHIDUserDevice?
    private let queue = DispatchQueue(label: "com.deencodes.ds5.virtualdevice", qos: .userInteractive)
    
    public init(onRumbleReceived: (@Sendable (Float, Float) -> Void)? = nil) {
        self.onRumbleReceived = onRumbleReceived
    }
    
    public func setRumbleHandler(_ handler: (@Sendable (Float, Float) -> Void)?) {
        self.onRumbleReceived = handler
    }
    
    public func start() async throws {
        guard !isStarted else { return }
        
        guard PermissionHelper.isAccessibilityGranted() else {
            PermissionHelper.requestAccessibility()
            throw DualSenseVirtualDeviceError.accessibilityDenied
        }
        
        #if canImport(CoreHID)
        if #available(macOS 15, *) {
            do {
                try await startCoreHID()
                isStarted = true
                print("[DualSenseEmulationKit] Successfully activated CoreHID DualSense Virtual Device")
                return
            } catch {
                print("[DualSenseEmulationKit] CoreHID activation attempt failed: \(error). Falling back to IOKit.")
            }
        }
        #endif
        
        try startIOKit()
        isStarted = true
        print("[DualSenseEmulationKit] Successfully activated IOKit DualSense Virtual Device")
    }
    
    public func stop() {
        guard isStarted else { return }
        
        #if canImport(CoreHID)
        if #available(macOS 15, *) {
            coreHIDDevice = nil
            coreHIDDelegate = nil
        }
        #endif
        
        if let dev = ioKitDevice {
            IOHIDUserDeviceCancel(dev)
            ioKitDevice = nil
        }
        
        isStarted = false
        print("[DualSenseEmulationKit] Stopped virtual DualSense device")
    }
    
    public func dispatchReport(data: Data) async throws {
        guard isStarted else { return }
        
        #if canImport(CoreHID)
        if #available(macOS 15, *) {
            if let dev = coreHIDDevice as? HIDVirtualDevice {
                do {
                    try await dev.dispatchInputReport(data: data, timestamp: .now)
                    return
                } catch {
                    throw DualSenseVirtualDeviceError.dispatchFailed(error.localizedDescription)
                }
            }
        }
        #endif
        
        if let dev = ioKitDevice {
            var reportBytes = [UInt8](data)
            let res = IOHIDUserDeviceHandleReportWithTimeStamp(dev, mach_absolute_time(), &reportBytes, CFIndex(reportBytes.count))
            if res != kIOReturnSuccess {
                throw DualSenseVirtualDeviceError.dispatchFailed("IOHIDUserDeviceHandleReportWithTimeStamp returned \(res)")
            }
        }
    }
    
    // MARK: - CoreHID Implementation
    
    #if canImport(CoreHID)
    @available(macOS 15, *)
    private func startCoreHID() async throws {
        let descData = Data(DualSenseConstants.reportDescriptor)
        
        let properties = HIDVirtualDevice.Properties(
            descriptor: descData,
            vendorID: DualSenseConstants.vendorID,
            productID: DualSenseConstants.productID,
            transport: .usb,
            product: DualSenseConstants.productName,
            manufacturer: DualSenseConstants.manufacturer,
            versionNumber: DualSenseConstants.versionNumber,
            serialNumber: "DS5-08BITDO-001",
            locationID: 0x10000002
        )
        
        guard let dev = HIDVirtualDevice(properties: properties) else {
            throw DualSenseVirtualDeviceError.deviceCreationFailed
        }
        
        let delegate = VirtualDeviceDelegateWrapper(parent: self)
        await dev.activate(delegate: delegate)
        
        self.coreHIDDevice = dev
        self.coreHIDDelegate = delegate
    }
    #endif
    
    // MARK: - IOKit Fallback Implementation
    
    private func startIOKit() throws {
        let descData = Data(DualSenseConstants.reportDescriptor)
        
        let dict: [String: Any] = [
            kIOHIDReportDescriptorKey as String: descData,
            kIOHIDVendorIDKey as String: Int(DualSenseConstants.vendorID),
            kIOHIDProductIDKey as String: Int(DualSenseConstants.productID),
            kIOHIDVersionNumberKey as String: Int(DualSenseConstants.versionNumber),
            kIOHIDProductKey as String: DualSenseConstants.productName,
            kIOHIDManufacturerKey as String: DualSenseConstants.manufacturer,
            kIOHIDSerialNumberKey as String: "DS5-08BITDO-001",
            kIOHIDTransportKey as String: "USB",
            kIOHIDMaxInputReportSizeKey as String: DualSenseConstants.inputReportLength,
            kIOHIDMaxOutputReportSizeKey as String: DualSenseConstants.outputReportLength,
            kIOHIDPrimaryUsagePageKey as String: 1,
            kIOHIDPrimaryUsageKey as String: 5,
            kIOHIDLocationIDKey as String: 0x10000002
        ]
        
        guard let dev = IOHIDUserDeviceCreateWithProperties(kCFAllocatorDefault, dict as CFDictionary, 0) else {
            throw DualSenseVirtualDeviceError.deviceCreationFailed
        }
        
        IOHIDUserDeviceRegisterSetReportBlock(dev) { [weak self] type, reportID, report, reportLength in
            guard let self = self, reportLength > 0 else { return kIOReturnSuccess }
            let data = Data(bytes: report, count: Int(reportLength))
            Task {
                await self.handleOutputReport(data: data)
            }
            return kIOReturnSuccess
        }
        
        IOHIDUserDeviceSetDispatchQueue(dev, queue)
        IOHIDUserDeviceActivate(dev)
        
        self.ioKitDevice = dev
    }
    
    // MARK: - Output Report / Rumble Extraction
    
    public func handleOutputReport(data: Data) {
        // DualSense Output Report 0x02:
        // Byte 1: flags
        // Byte 3: Right Motor (high frequency) (0..255)
        // Byte 4: Left Motor (low frequency) (0..255)
        guard data.count >= 6 else { return }
        
        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            let highFreq = Float(bytes[3]) / 255.0
            let lowFreq = Float(bytes[4]) / 255.0
            onRumbleReceived?(lowFreq, highFreq)
        }
    }
}
