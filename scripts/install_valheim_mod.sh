#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
VALHEIM_PLUGIN_DIR="$HOME/Library/Application Support/Steam/steamapps/common/Valheim/BepInEx/plugins"

echo "==> Building 8BitDo Ultimate 2 Valheim Plugin..."
dotnet build "$REPO_DIR/Integrations/Valheim/EightBitDoUltimate2Valheim.csproj" -c Release

OUTPUT_DLL="$REPO_DIR/Integrations/Valheim/bin/Release/netstandard2.1/EightBitDoUltimate2Valheim.dll"

if [ ! -f "$OUTPUT_DLL" ]; then
    echo "[-] Build failed: $OUTPUT_DLL not found."
    exit 1
fi

if [ -d "$VALHEIM_PLUGIN_DIR" ]; then
    echo "==> Installing plugin into Valheim BepInEx plugins directory..."
    mkdir -p "$VALHEIM_PLUGIN_DIR/EightBitDoUltimate2"
    cp "$OUTPUT_DLL" "$VALHEIM_PLUGIN_DIR/EightBitDoUltimate2/"
    echo "[+] Successfully installed EightBitDoUltimate2Valheim.dll to: $VALHEIM_PLUGIN_DIR/EightBitDoUltimate2/"
    echo "[+] Launch Valheim via Steam or run_bepinex.sh with your 8BitDo in 2.4G D-Input mode!"
else
    echo "[!] Valheim BepInEx plugins directory not found at:"
    echo "    $VALHEIM_PLUGIN_DIR"
    echo "    Built DLL is located at: $OUTPUT_DLL"
fi
