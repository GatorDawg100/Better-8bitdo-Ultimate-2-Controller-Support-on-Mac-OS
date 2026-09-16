using System.Runtime.InteropServices;
using BepInEx;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Layouts;
using UnityEngine.InputSystem.LowLevel;
using UnityEngine.InputSystem.Utilities;

namespace EightBitDoUltimate2Valheim
{
    [BepInPlugin("com.deenleibovici.8bitdoultimate2valheim", "8BitDo Ultimate 2 Valheim Support", "1.0.0")]
    public class EightBitDoPlugin : BaseUnityPlugin
    {
        private void Awake()
        {
            Logger.LogInfo("[8BitDo] Initializing 8BitDo Ultimate 2 Wireless D-Input driver for Valheim macOS...");
            RegisterLayout();
            Logger.LogInfo("[8BitDo] Successfully registered custom Gamepad layout (VID: 0x2DC8, PID: 0x6012).");
        }

        private static void RegisterLayout()
        {
            // Register custom layout for 8BitDo Ultimate 2 in 2.4G D-Input mode (VID 0x2DC8, PID 0x6012)
            InputSystem.RegisterLayout<EightBitDoUltimate2Gamepad>(
                "8BitDoUltimate2Wireless",
                matches: new InputDeviceMatcher()
                    .WithInterface("HID")
                    .WithCapability("vendorId", 0x2dc8)
                    .WithCapability("productId", 0x6012)
            );
        }
    }

    [InputControlLayout(stateType = typeof(EightBitDoHIDState), displayName = "8BitDo Ultimate 2 Wireless")]
    public class EightBitDoUltimate2Gamepad : Gamepad
    {
        static EightBitDoUltimate2Gamepad()
        {
            InputSystem.RegisterLayout<EightBitDoUltimate2Gamepad>(
                "8BitDoUltimate2Wireless",
                matches: new InputDeviceMatcher()
                    .WithInterface("HID")
                    .WithCapability("vendorId", 0x2dc8)
                    .WithCapability("productId", 0x6012)
            );
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Init() { }
    }

    [StructLayout(LayoutKind.Explicit, Size = 34)]
    public struct EightBitDoHIDState : IInputStateTypeInfo
    {
        public FourCC format => new FourCC('H', 'I', 'D', ' ');

        [FieldOffset(0)]
        public byte reportId; // 0x01

        // Byte 1: D-Pad Hat Switch (0=Up, 1=UR, 2=R, 3=DR, 4=D, 5=DL, 6=L, 7=UL, 15=Neutral)
        [InputControl(name = "dpad", layout = "Dpad", format = "HAT")]
        [InputControl(name = "dpad/up", format = "BIT", parameters = "null")]
        [InputControl(name = "dpad/down", format = "BIT", parameters = "null")]
        [InputControl(name = "dpad/left", format = "BIT", parameters = "null")]
        [InputControl(name = "dpad/right", format = "BIT", parameters = "null")]
        [FieldOffset(1)]
        public byte dpadHat;

        // Byte 2 & 3: Left Stick (0..255, center 128)
        [InputControl(name = "leftStick", layout = "Stick", format = "VEC2")]
        [InputControl(name = "leftStick/x", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5")]
        [InputControl(name = "leftStick/left", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0,clampMax=0.5,invert")]
        [InputControl(name = "leftStick/right", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0.5,clampMax=1")]
        [InputControl(name = "leftStick/y", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5")]
        [InputControl(name = "leftStick/up", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0.5,clampMax=1")]
        [InputControl(name = "leftStick/down", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0,clampMax=0.5,invert")]
        [FieldOffset(2)]
        public byte leftStickX;

        [FieldOffset(3)]
        public byte leftStickY;

        // Byte 4 & 5: Right Stick (0..255, center 128)
        [InputControl(name = "rightStick", layout = "Stick", format = "VEC2")]
        [InputControl(name = "rightStick/x", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5")]
        [InputControl(name = "rightStick/left", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0,clampMax=0.5,invert")]
        [InputControl(name = "rightStick/right", offset = 0, format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0.5,clampMax=1")]
        [InputControl(name = "rightStick/y", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5")]
        [InputControl(name = "rightStick/up", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0.5,clampMax=1")]
        [InputControl(name = "rightStick/down", offset = 1, format = "BYTE", parameters = "invert,normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0.5,clamp=1,clampMin=0,clampMax=0.5,invert")]
        [FieldOffset(4)]
        public byte rightStickX;

        [FieldOffset(5)]
        public byte rightStickY;

        // Byte 6: Face buttons & Bumpers
        // Bit 0: A -> ButtonSouth
        // Bit 1: B -> ButtonEast
        // Bit 3: X -> ButtonWest
        // Bit 4: Y -> ButtonNorth
        // Bit 6: LB -> LeftShoulder
        // Bit 7: RB -> RightShoulder
        [InputControl(name = "buttonSouth", bit = 0, displayName = "A")]
        [InputControl(name = "buttonEast", bit = 1, displayName = "B")]
        [InputControl(name = "buttonWest", bit = 3, displayName = "X")]
        [InputControl(name = "buttonNorth", bit = 4, displayName = "Y")]
        [InputControl(name = "leftShoulder", bit = 6, displayName = "LB")]
        [InputControl(name = "rightShoulder", bit = 7, displayName = "RB")]
        [FieldOffset(6)]
        public byte buttons1;

        // Byte 7: System & Thumbstick Clicks
        // Bit 2: Select -> Back
        // Bit 3: Start -> Start
        // Bit 5: L3 -> LeftStickPress
        // Bit 6: R3 -> RightStickPress
        [InputControl(name = "select", bit = 2, displayName = "Back")]
        [InputControl(name = "start", bit = 3, displayName = "Start")]
        [InputControl(name = "leftStickPress", bit = 5, displayName = "L3")]
        [InputControl(name = "rightStickPress", bit = 6, displayName = "R3")]
        [FieldOffset(7)]
        public byte buttons2;

        // Byte 8 & 9: Analog Triggers (0..255)
        [InputControl(name = "leftTrigger", format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0")]
        [FieldOffset(8)]
        public byte leftTrigger;

        [InputControl(name = "rightTrigger", format = "BYTE", parameters = "normalize,normalizeMin=0,normalizeMax=1,normalizeZero=0")]
        [FieldOffset(9)]
        public byte rightTrigger;

        // Byte 10: Back Paddles (M1 = bit 0, M2 = bit 1)
        [InputControl(name = "paddle1", bit = 0, displayName = "M1")]
        [InputControl(name = "paddle2", bit = 1, displayName = "M2")]
        [FieldOffset(10)]
        public byte paddles;
    }
}
