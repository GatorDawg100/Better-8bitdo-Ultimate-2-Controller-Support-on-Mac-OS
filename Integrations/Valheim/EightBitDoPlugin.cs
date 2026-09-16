using System;
using System.Runtime.InteropServices;
using System.Threading;
using BepInEx;
using BepInEx.Logging;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Layouts;
using UnityEngine.InputSystem.LowLevel;

namespace EightBitDoUltimate2Valheim
{
    /// <summary>
    /// Custom Gamepad layout registered into Unity InputSystem for the 8BitDo Ultimate 2 Wireless Controller.
    /// </summary>
    [InputControlLayout(stateType = typeof(GamepadState), displayName = "8BitDo Ultimate 2 Wireless")]
    public class EightBitDoGamepad : Gamepad
    {
    }

    [BepInPlugin(PluginGUID, PluginName, PluginVersion)]
    public class EightBitDoPlugin : BaseUnityPlugin
    {
        public const string PluginGUID = "com.deen.eightbitdo.valheim";
        public const string PluginName = "8BitDo Ultimate 2 Valheim Profile";
        public const string PluginVersion = "1.0.0";

        private static ManualLogSource _logger;
        private static EightBitDoGamepad _gamepad;
        private static Thread _ioThread;
        private static bool _isRunning = true;
        private static long _lastReportTime = 0;

        private void Awake()
        {
            _logger = Logger;
            _logger.LogInfo("[8BitDo] Initializing native 8BitDo Ultimate 2 profile for Valheim...");

            // 1. Register the custom layout with Unity's InputSystem
            try
            {
                InputSystem.RegisterLayout<EightBitDoGamepad>("EightBitDoGamepad");
                _logger.LogInfo("[8BitDo] Registered 'EightBitDoGamepad' layout.");

                InputSystem.RegisterLayoutMatcher<EightBitDoGamepad>(
                    new InputDeviceMatcher()
                        .WithInterface("HID")
                        .WithProduct("8BitDo Ultimate 2 Wireless")
                );
                InputSystem.RegisterLayoutMatcher<EightBitDoGamepad>(
                    new InputDeviceMatcher()
                        .WithCapability("vendorId", 0x2DC8)
                        .WithCapability("productId", 0x6012)
                );
                _logger.LogInfo("[8BitDo] Registered hardware matchers (0x2DC8:0x6012).");
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"[8BitDo] Layout registration note: {ex.Message}");
            }

            // 2. Instantiate and activate the Gamepad in Unity's InputSystem
            try
            {
                _gamepad = InputSystem.AddDevice<EightBitDoGamepad>();
                InputSystem.EnableDevice(_gamepad);
                _gamepad.MakeCurrent();
                _logger.LogInfo($"[8BitDo] Successfully created and activated Gamepad device! ID: {_gamepad.deviceId}");
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"[8BitDo] Could not create custom layout device, trying base Gamepad: {ex.Message}");
                try
                {
                    _gamepad = (EightBitDoGamepad)InputSystem.AddDevice("Gamepad", "8BitDo Ultimate 2 Wireless");
                    InputSystem.EnableDevice(_gamepad);
                    _gamepad.MakeCurrent();
                    _logger.LogInfo($"[8BitDo] Created Gamepad device using base layout. ID: {_gamepad.deviceId}");
                }
                catch (Exception ex2)
                {
                    _logger.LogError($"[8BitDo] Failed to create Gamepad in Unity: {ex2}");
                }
            }

            // 3. Start high-frequency userspace reader thread
            _ioThread = new Thread(IOKitReaderThread)
            {
                IsBackground = true,
                Name = "8BitDo_IOKit_Reader"
            };
            _ioThread.Start();
        }

        private void Update()
        {
            // Ensure this gamepad stays current when active
            if (_gamepad != null && Gamepad.current != _gamepad)
            {
                if (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - _lastReportTime < 2000)
                {
                    _gamepad.MakeCurrent();
                }
            }
        }

        private void OnDestroy()
        {
            _isRunning = false;
            if (_gamepad != null)
            {
                try
                {
                    InputSystem.RemoveDevice(_gamepad);
                }
                catch {}
            }
        }

        #region Native IOKit Background Reader

        private static IOHIDReportCallback _reportCallbackDelegate;

        private static void IOKitReaderThread()
        {
            try
            {
                IntPtr manager = IOHIDManagerCreate(IntPtr.Zero, 0);
                if (manager == IntPtr.Zero)
                {
                    _logger.LogError("[8BitDo] Failed to create IOHIDManager.");
                    return;
                }

                // Match 8BitDo Ultimate 2: VID 0x2DC8, PID 0x6012
                IntPtr matchDict = CreateMatchingDictionary(0x2DC8, 0x6012);
                IOHIDManagerSetDeviceMatching(manager, matchDict);

                // Register input report callback (64-byte buffer)
                byte[] reportBuffer = new byte[64];
                _reportCallbackDelegate = OnInputReportReceived;
                IOHIDManagerRegisterInputReportCallback(
                    manager,
                    _reportCallbackDelegate,
                    IntPtr.Zero
                );

                IntPtr runLoop = CFRunLoopGetCurrent();
                IntPtr modeDefault = GetCFRunLoopDefaultMode();
                IOHIDManagerScheduleWithRunLoop(manager, runLoop, modeDefault);

                int openResult = IOHIDManagerOpen(manager, 0);
                if (openResult != 0)
                {
                    _logger.LogError($"[8BitDo] IOHIDManagerOpen failed with error code: 0x{openResult:X}");
                    return;
                }

                _logger.LogInfo("[8BitDo] IOHIDManager opened and monitoring controller input reports...");

                while (_isRunning)
                {
                    CFRunLoopRunInMode(modeDefault, 0.05, false);
                }

                IOHIDManagerClose(manager, 0);
                CFRelease(manager);
                if (matchDict != IntPtr.Zero) CFRelease(matchDict);
            }
            catch (Exception ex)
            {
                _logger.LogError($"[8BitDo] Exception in IOKit reader thread: {ex}");
            }
        }

        private static void OnInputReportReceived(
            IntPtr context,
            int result,
            IntPtr sender,
            int type,
            uint reportID,
            IntPtr report,
            long reportLength)
        {
            if (report == IntPtr.Zero || reportLength < 10 || _gamepad == null) return;

            byte[] data = new byte[reportLength];
            Marshal.Copy(report, data, 0, (int)reportLength);

            // Byte 1: D-Pad Hat Switch (0=Up, 1=UR, 2=R, 3=DR, 4=D, 5=DL, 6=L, 7=UL, 15=None)
            byte hat = data[1];
            bool dpadUp = (hat == 0 || hat == 1 || hat == 7);
            bool dpadRight = (hat == 1 || hat == 2 || hat == 3);
            bool dpadDown = (hat == 3 || hat == 4 || hat == 5);
            bool dpadLeft = (hat == 5 || hat == 6 || hat == 7);

            // Thumbsticks (Bytes 2..5: 0..255, center = 127.5f)
            float lx = (data[2] - 127.5f) / 127.5f;
            float ly = -(data[3] - 127.5f) / 127.5f; // Invert Y so up is positive
            float rx = (data[4] - 127.5f) / 127.5f;
            float ry = -(data[5] - 127.5f) / 127.5f;

            // Byte 6: Face buttons & Bumpers
            byte b6 = data[6];
            bool btnA = (b6 & (1 << 0)) != 0; // South
            bool btnB = (b6 & (1 << 1)) != 0; // East
            bool btnX = (b6 & (1 << 3)) != 0; // West
            bool btnY = (b6 & (1 << 4)) != 0; // North
            bool btnLB = (b6 & (1 << 6)) != 0; // Left Shoulder
            bool btnRB = (b6 & (1 << 7)) != 0; // Right Shoulder

            // Byte 7: System & Stick Clicks
            byte b7 = data[7];
            bool btnSelect = (b7 & (1 << 2)) != 0;
            bool btnStart = (b7 & (1 << 3)) != 0;
            bool btnHome = (b7 & (1 << 4)) != 0;
            bool btnL3 = (b7 & (1 << 5)) != 0;
            bool btnR3 = (b7 & (1 << 6)) != 0;

            // Bytes 8 & 9: Continuous Analog Triggers (0..255 -> 0.0..1.0)
            float lt = data[8] / 255.0f;
            float rt = data[9] / 255.0f;

            // Byte 10: Grip Back Paddles
            bool pM1 = false;
            bool pM2 = false;
            if (reportLength > 10)
            {
                pM1 = (data[10] & 0x01) != 0; // Left Paddle (M1)
                pM2 = (data[10] & 0x02) != 0; // Right Paddle (M2)
            }

            // Build GamepadState
            var state = new GamepadState
            {
                leftStick = new Vector2(lx, ly),
                rightStick = new Vector2(rx, ry),
                leftTrigger = lt,
                rightTrigger = rt
            };

            // Map face buttons, shoulders, system
            state = state.WithButton(GamepadButton.A, btnA)
                         .WithButton(GamepadButton.B, btnB)
                         .WithButton(GamepadButton.X, btnX)
                         .WithButton(GamepadButton.Y, btnY)
                         .WithButton(GamepadButton.LeftShoulder, btnLB)
                         .WithButton(GamepadButton.RightShoulder, btnRB)
                         .WithButton(GamepadButton.Select, btnSelect || pM1) // Map M1 to Select (Map in Valheim)
                         .WithButton(GamepadButton.Start, btnStart)
                         .WithButton(GamepadButton.LeftStick, btnL3 || pM2)  // Map M2 to L3 (Sprint)
                         .WithButton(GamepadButton.RightStick, btnR3)
                         .WithButton(GamepadButton.DpadUp, dpadUp)
                         .WithButton(GamepadButton.DpadRight, dpadRight)
                         .WithButton(GamepadButton.DpadDown, dpadDown)
                         .WithButton(GamepadButton.DpadLeft, dpadLeft);

            // Queue in Unity
            InputSystem.QueueStateEvent(_gamepad, state);
            _lastReportTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        }

        #endregion

        #region P/Invoke & CoreFoundation / IOKit Helpers

        private const string IOKitLib = "/System/Library/Frameworks/IOKit.framework/IOKit";
        private const string CFLib = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation";

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

        [DllImport(IOKitLib)]
        private static extern IntPtr IOHIDManagerCreate(IntPtr allocator, uint options);

        [DllImport(IOKitLib)]
        private static extern void IOHIDManagerSetDeviceMatching(IntPtr manager, IntPtr matchingDictionary);

        [DllImport(IOKitLib)]
        private static extern void IOHIDManagerRegisterInputReportCallback(
            IntPtr manager,
            IOHIDReportCallback callback,
            IntPtr context
        );

        [DllImport(IOKitLib)]
        private static extern void IOHIDManagerScheduleWithRunLoop(IntPtr manager, IntPtr runLoop, IntPtr runLoopMode);

        [DllImport(IOKitLib)]
        private static extern int IOHIDManagerOpen(IntPtr manager, uint options);

        [DllImport(IOKitLib)]
        private static extern int IOHIDManagerClose(IntPtr manager, uint options);

        [DllImport(CFLib)]
        private static extern IntPtr CFRunLoopGetCurrent();

        [DllImport(CFLib)]
        private static extern int CFRunLoopRunInMode(IntPtr mode, double seconds, bool returnAfterSourceHandled);

        [DllImport(CFLib)]
        private static extern IntPtr CFDictionaryCreateMutable(
            IntPtr allocator,
            long capacity,
            IntPtr keyCallbacks,
            IntPtr valueCallbacks
        );

        [DllImport(CFLib)]
        private static extern void CFDictionarySetValue(IntPtr theDict, IntPtr key, IntPtr value);

        [DllImport(CFLib)]
        private static extern IntPtr CFStringCreateWithCString(IntPtr alloc, string cStr, uint encoding);

        [DllImport(CFLib)]
        private static extern IntPtr CFNumberCreate(IntPtr allocator, int theType, ref int valuePtr);

        [DllImport(CFLib)]
        private static extern void CFRelease(IntPtr cf);

        private static IntPtr CreateMatchingDictionary(int vid, int pid)
        {
            IntPtr dict = CFDictionaryCreateMutable(IntPtr.Zero, 0, IntPtr.Zero, IntPtr.Zero);
            if (dict == IntPtr.Zero) return IntPtr.Zero;

            const uint kCFStringEncodingUTF8 = 0x08000100;
            const int kCFNumberSInt32Type = 3;

            IntPtr kVID = CFStringCreateWithCString(IntPtr.Zero, "VendorID", kCFStringEncodingUTF8);
            IntPtr kPID = CFStringCreateWithCString(IntPtr.Zero, "ProductID", kCFStringEncodingUTF8);

            int vidVal = vid;
            int pidVal = pid;

            IntPtr numVID = CFNumberCreate(IntPtr.Zero, kCFNumberSInt32Type, ref vidVal);
            IntPtr numPID = CFNumberCreate(IntPtr.Zero, kCFNumberSInt32Type, ref pidVal);

            CFDictionarySetValue(dict, kVID, numVID);
            CFDictionarySetValue(dict, kPID, numPID);

            CFRelease(kVID);
            CFRelease(kPID);
            CFRelease(numVID);
            CFRelease(numPID);

            return dict;
        }

        private static IntPtr GetCFRunLoopDefaultMode()
        {
            const uint kCFStringEncodingUTF8 = 0x08000100;
            return CFStringCreateWithCString(IntPtr.Zero, "kCFRunLoopDefaultMode", kCFStringEncodingUTF8);
        }

        #endregion
    }
}
