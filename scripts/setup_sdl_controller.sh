#!/bin/bash
# Configures SDL2 / SDL3 game controller mapping for 8BitDo Ultimate 2 in 2.4G D-Input mode on macOS.
# Works with Steam and any SDL2/SDL3 games (Hollow Knight, Dead Cells, Celeste, Hades, Emulators, etc.)

MAPPING="03000000c82d00001260000000000000,8BitDo Ultimate 2 Wireless,platform:Mac OS X,a:b0,b:b1,x:b3,y:b4,back:b2,start:b3,guide:b4,leftstick:b5,rightstick:b6,leftshoulder:b6,rightshoulder:b7,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,"

echo "==> Configuring SDL_GAMECONTROLLERCONFIG for 8BitDo Ultimate 2..."
echo "Mapping string: $MAPPING"

ZSHRC="$HOME/.zshrc"
LINE="export SDL_GAMECONTROLLERCONFIG=\"$MAPPING\""

if grep -q "03000000c82d00001260000000000000" "$ZSHRC" 2>/dev/null; then
    echo "[*] Mapping already present in $ZSHRC."
else
    echo "" >> "$ZSHRC"
    echo "# 8BitDo Ultimate 2 Controller mapping for SDL2/SDL3 games on macOS" >> "$ZSHRC"
    echo "$LINE" >> "$ZSHRC"
    echo "[+] Added mapping to $ZSHRC."
fi

echo "[+] To apply immediately in your current terminal session, run:"
echo "    export SDL_GAMECONTROLLERCONFIG=\"$MAPPING\""
