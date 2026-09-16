using System;
using System.Runtime.InteropServices;
using System.Threading;
using BepInEx;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.LowLevel;

namespace EightBitDoUltimate2Valheim
{
    [BepInPlugin("com.deenleibovici.8bitdoultimate2valheim", "8BitDo Ultimate 2 Valheim Support", "1.0.0")]
    public class EightBitDoPlugin : BaseUnityPlugin
    {
        private static Gamepad _gamepad;
        private static Thread _ioThread;
        private static volatile bool _isRunning = true;
        private static IntPtr _currentRunLoop = IntPtr.Zero;

        private void Awake()
        {
            Logger.LogInfo("[8BitDo] Initializing native in-process driver for Valheim macOS...");

            // 1. Create native Gamepad in Unity's Input System
            try
            {
                _gamepad = InputSystem.AddDevice<Gamepad>("8BitDo Ultimate 2 Wireless");
                _gamepad.MakeCurrent();
                Logger.LogInfo($"[8BitDo] Created in-engine Gamepad: {_gamepad.name} (ID: {_gamepad.deviceId}). Set as Gamepad.current.");
            }
            catch (Exception ex)
            {
                Logger.LogError($"[8BitDo] Failed to create Gamepad device: {ex.Message}");
            }

            // 2. Start native IOKit background thread to capture controller packets (Bluetooth & 2.4G Dongle)
            _isRunning = true;
            _ioThread = new Thread(IOKitWorker)
            {
                IsBackground = true,
                Name = "8BitDo-Native-IOKit"
            };
            _ioThread.Start();
            Logger.LogInfo("[8BitDo] IOKit background reader thread started.");
        }

        private void OnDestroy()
        {
            _isRunning = false;
            if (_currentRunLoop != IntPtr.Zero)
            {
                CFRunLoopStop(_currentRunLoop);
            }
            if (_gamepad != null && _gamepad.added)
            {
                InputSystem.RemoveDevice(_gamepad);
                _gamepad = null;
            }
        }

        private void Update()
        {
            if (_gamepad != null && Gamepad.current != _gamepad)
            {
                _gamepad.MakeCurrent();
            }
        }

        // MARK: - Native IOKit Background Worker

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void IOHIDReportCallback(
            IntPtr context,
            int result,
            IntPtr sender,
            int type,
            uint reportID,
            IntPtr report,
            long reportLength
        );

        private static IOHIDReportCallback _reportCallbackDelegate;
        private static IntPtr _reportBufferPtr = IntPtr.Zero;

        private void IOKitWorker()
        {
            _currentRunLoop = CFRunLoopGetCurrent();

            while (_isRunning)
            {
                try
                {
                    IntPtr manager = IOHIDManagerCreate(IntPtr.Zero, 0);
                    if (manager == IntPtr.Zero)
                    {
                        Thread.Sleep(1000);
                        continue;
                    }

                    IOHIDManagerSetDeviceMatching(manager, IntPtr.Zero);
                    int openRes = IOHIDManagerOpen(manager, 0);
                    if (openRes != 0)
                    {
                        CFRelease(manager);
                        Thread.Sleep(1000);
                        continue;
                    }

                    Logger.LogInfo("[8BitDo] IOHIDManager successfully opened. Scanning for 8BitDo controller...");
                    IntPtr matchedDevice = IntPtr.Zero;

                    while (_isRunning && matchedDevice == IntPtr.Zero)
                    {
                        matchedDevice = Find8BitDoDevice(manager);
                        if (matchedDevice == IntPtr.Zero)
                        {
                            Thread.Sleep(800);
                        }
                    }

                    if (!_isRunning || matchedDevice == IntPtr.Zero)
                    {
                        IOHIDManagerClose(manager, 0);
                        CFRelease(manager);
                        break;
                    }

                    Logger.LogInfo("[8BitDo] Found 8BitDo controller! Attaching input report callback...");

                    int devOpenRes = IOHIDDeviceOpen(matchedDevice, 0);
                    if (devOpenRes != 0)
                    {
                        Logger.LogWarning($"[8BitDo] IOHIDDeviceOpen returned {devOpenRes}. Retrying...");
                        IOHIDManagerClose(manager, 0);
                        CFRelease(manager);
                        Thread.Sleep(1000);
                        continue;
                    }

                    _reportBufferPtr = Marshal.AllocHGlobal(64);
                    _reportCallbackDelegate = HandleReportCallback;

                    IOHIDDeviceRegisterInputReportCallback(
                        matchedDevice,
                        _reportBufferPtr,
                        64,
                        _reportCallbackDelegate,
                        IntPtr.Zero
                    );

                    IntPtr runLoopMode = CFStringCreateWithCharacters(IntPtr.Zero, "kCFRunLoopCommonModes", 21);
                    IOHIDDeviceScheduleWithRunLoop(matchedDevice, _currentRunLoop, runLoopMode);
                    CFRelease(runLoopMode);

                    Logger.LogInfo("[8BitDo] Input callback active! Controller reports are now driving Unity Gamepad at 500 Hz.");

                    // Run the CFRunLoop to pump HID input reports
                    CFRunLoopRun();

                    // Cleanup if loop exits
                    IOHIDDeviceClose(matchedDevice, 0);
                    IOHIDManagerClose(manager, 0);
                    CFRelease(manager);

                    if (_reportBufferPtr != IntPtr.Zero)
                    {
                        Marshal.FreeHGlobal(_reportBufferPtr);
                        _reportBufferPtr = IntPtr.Zero;
                    }
                }
                catch (Exception ex)
                {
                    Logger.LogError($"[8BitDo] Error in IOKit thread: {ex.Message}");
                    Thread.Sleep(1000);
                }
            }
        }

        private IntPtr Find8BitDoDevice(IntPtr manager)
        {
            IntPtr deviceSet = IOHIDManagerCopyDevices(manager);
            if (deviceSet == IntPtr.Zero) return IntPtr.Zero;

            long count = CFSetGetCount(deviceSet);
            if (count <= 0)
            {
                CFRelease(deviceSet);
                return IntPtr.Zero;
            }

            IntPtr[] devices = new IntPtr[count];
            CFSetGetValues(deviceSet, devices);

            IntPtr matched = IntPtr.Zero;
            for (int i = 0; i < count; i++)
            {
                IntPtr dev = devices[i];
                int vid = GetIntProperty(dev, "VendorID");
                int pid = GetIntProperty(dev, "ProductID");
                string name = GetStringProperty(dev, "Product") ?? "";

                // Match VID 0x2DC8, PID 0x6012 OR product name
                if ((vid == 0x2DC8 && (pid == 0x6012 || pid == 0x3106 || pid == 0x3012)) ||
                    name.IndexOf("8BitDo", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    Logger.LogInfo($"[8BitDo] Matched Controller: '{name}', VID: 0x{vid:X4}, PID: 0x{pid:X4}");
                    matched = dev;
                    break;
                }
            }

            CFRelease(deviceSet);
            return matched;
        }

        // MARK: - Input Report Processing

        private static void HandleReportCallback(
            IntPtr context,
            int result,
            IntPtr sender,
            int type,
            uint reportID,
            IntPtr report,
            long reportLength
        )
        {
            if (report == IntPtr.Zero || reportLength < 10 || _gamepad == null) return;

            byte[] bytes = new byte[reportLength];
            Marshal.Copy(report, bytes, 0, (int)reportLength);

            // Byte 1: D-Pad Hat Switch
            byte hat = bytes[1];
            bool dpadUp = (hat == 0 || hat == 1 || hat == 7);
            bool dpadRight = (hat == 1 || hat == 2 || hat == 3);
            bool dpadDown = (hat == 3 || hat == 4 || hat == 5);
            bool dpadLeft = (hat == 5 || hat == 6 || hat == 7);

            // Bytes 2 & 3: Left Stick (0..255, center 127.5)
            float lx = ((float)bytes[2] - 127.5f) / 127.5f;
            float ly = -(((float)bytes[3] - 127.5f) / 127.5f);

            // Bytes 4 & 5: Right Stick (0..255, center 127.5)
            float rx = ((float)bytes[4] - 127.5f) / 127.5f;
            float ry = -(((float)bytes[5] - 127.5f) / 127.5f);

            // Byte 6: Face buttons & Bumpers
            byte b6 = bytes[6];
            bool btnA = (b6 & (1 << 0)) != 0;
            bool btnB = (b6 & (1 << 1)) != 0;
            bool btnX = (b6 & (1 << 3)) != 0;
            bool btnY = (b6 & (1 << 4)) != 0;
            bool btnLB = (b6 & (1 << 6)) != 0;
            bool btnRB = (b6 & (1 << 7)) != 0;

            // Byte 7: System buttons & Stick clicks
            byte b7 = bytes[7];
            bool btnSelect = (b7 & (1 << 2)) != 0;
            bool btnStart = (b7 & (1 << 3)) != 0;
            bool btnL3 = (b7 & (1 << 5)) != 0;
            bool btnR3 = (b7 & (1 << 6)) != 0;

            // Bytes 8 & 9: Analog Triggers (0..255)
            float lt = (float)bytes[8] / 255.0f;
            float rt = (float)bytes[9] / 255.0f;

            // Build Unity GamepadState
            var state = new GamepadState
            {
                leftStick = new Vector2(Mathf.Clamp(lx, -1f, 1f), Mathf.Clamp(ly, -1f, 1f)),
                rightStick = new Vector2(Mathf.Clamp(rx, -1f, 1f), Mathf.Clamp(ry, -1f, 1f)),
                leftTrigger = Mathf.Clamp01(lt),
                rightTrigger = Mathf.Clamp01(rt)
            };

            state = state.WithButton(GamepadButton.A, btnA)
                         .WithButton(GamepadButton.B, btnB)
                         .WithButton(GamepadButton.X, btnX)
                         .WithButton(GamepadButton.Y, btnY)
                         .WithButton(GamepadButton.LeftShoulder, btnLB)
                         .WithButton(GamepadButton.RightShoulder, btnRB)
                         .WithButton(GamepadButton.Select, btnSelect)
                         .WithButton(GamepadButton.Start, btnStart)
                         .WithButton(GamepadButton.LeftStick, btnL3)
                         .WithButton(GamepadButton.RightStick, btnR3)
                         .WithButton(GamepadButton.DpadUp, dpadUp)
                         .WithButton(GamepadButton.DpadDown, dpadDown)
                         .WithButton(GamepadButton.DpadLeft, dpadLeft)
                         .WithButton(GamepadButton.DpadRight, dpadRight);

            // Queue the state update into Unity's Input System
            InputSystem.QueueStateEvent(_gamepad, state);
        }

        // MARK: - Property Helpers

        private static int GetIntProperty(IntPtr device, string key)
        {
            IntPtr keyStr = CFStringCreateWithCharacters(IntPtr.Zero, key, key.Length);
            IntPtr valRef = IOHIDDeviceGetProperty(device, keyStr);
            CFRelease(keyStr);
            if (valRef == IntPtr.Zero) return 0;

            int val = 0;
            if (CFNumberGetValue(valRef, 3 /* kCFNumberSInt32Type */, ref val))
            {
                return val;
            }
            return 0;
        }

        private static string GetStringProperty(IntPtr device, string key)
        {
            IntPtr keyStr = CFStringCreateWithCharacters(IntPtr.Zero, key, key.Length);
            IntPtr valRef = IOHIDDeviceGetProperty(device, keyStr);
            CFRelease(keyStr);
            if (valRef == IntPtr.Zero) return null;

            long len = CFStringGetLength(valRef);
            if (len <= 0) return null;

            char[] chars = new char[len];
            CFStringGetCharacters(valRef, new CFRange(0, len), chars);
            return new string(chars);
        }

        // MARK: - P/Invoke Definitions

        [StructLayout(LayoutKind.Sequential)]
        private struct CFRange
        {
            public long location;
            public long length;
            public CFRange(long loc, long len) { location = loc; length = len; }
        }

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern IntPtr IOHIDManagerCreate(IntPtr allocator, uint options);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern void IOHIDManagerSetDeviceMatching(IntPtr manager, IntPtr matchingDictionary);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern int IOHIDManagerOpen(IntPtr manager, uint options);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern void IOHIDManagerClose(IntPtr manager, uint options);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern IntPtr IOHIDManagerCopyDevices(IntPtr manager);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern int IOHIDDeviceOpen(IntPtr device, uint options);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern void IOHIDDeviceClose(IntPtr device, uint options);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern IntPtr IOHIDDeviceGetProperty(IntPtr device, IntPtr key);

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern void IOHIDDeviceRegisterInputReportCallback(
            IntPtr device,
            IntPtr reportBuffer,
            long reportBufferLength,
            IOHIDReportCallback callback,
            IntPtr context
        );

        [DllImport("/System/Library/Frameworks/IOKit.framework/IOKit")]
        private static extern void IOHIDDeviceScheduleWithRunLoop(IntPtr device, IntPtr runLoop, IntPtr runLoopMode);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern IntPtr CFRunLoopGetCurrent();

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFRunLoopRun();

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFRunLoopStop(IntPtr runLoop);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern IntPtr CFStringCreateWithCharacters(IntPtr alloc, [MarshalAs(UnmanagedType.LPWStr)] string str, long count);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern long CFStringGetLength(IntPtr theString);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFStringGetCharacters(IntPtr theString, CFRange range, [Out] char[] buffer);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern bool CFNumberGetValue(IntPtr number, int theType, ref int valuePtr);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern long CFSetGetCount(IntPtr set);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFSetGetValues(IntPtr set, [Out] IntPtr[] values);

        [DllImport("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")]
        private static extern void CFRelease(IntPtr cf);
    }
}
