#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Building 8BitDo Ultimate 2 Valheim Profile ==="
cd "${ROOT_DIR}"
dotnet build Integrations/Valheim/EightBitDoUltimate2Valheim.csproj -c Release

VALHEIM_PLUGIN_DIR="${HOME}/Library/Application Support/Steam/steamapps/common/Valheim/BepInEx/plugins/EightBitDoUltimate2"
mkdir -p "${VALHEIM_PLUGIN_DIR}"

echo "=== Installing Plugin to Valheim BepInEx ==="
cp "Integrations/Valheim/bin/Release/netstandard2.1/EightBitDoUltimate2Valheim.dll" "${VALHEIM_PLUGIN_DIR}/"

echo "=== Installation Complete! ==="
echo "Plugin installed at: ${VALHEIM_PLUGIN_DIR}/EightBitDoUltimate2Valheim.dll"
echo "Launch Valheim with your 8BitDo controller connected over Bluetooth or 2.4G dongle."
