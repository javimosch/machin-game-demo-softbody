#!/usr/bin/env bash
# Build machin-game-demo-softbody. Vendors raylib 5.0 if no system raylib.
# machin v0.48.0+.
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
SRC=softbody-demo.src
BIN=machin-game-demo-softbody

have_system_raylib() {
    pkg-config --exists raylib 2>/dev/null && return 0
    [ -f /usr/include/raylib.h ] || [ -f /usr/local/include/raylib.h ]
}

if have_system_raylib; then
    "$MACHIN" encode "$SRC" > softbody-demo.mfl
else
    RL_VER=5.0
    RL_TAR="raylib-${RL_VER}_linux_amd64"
    RL_DIR="vendor/${RL_TAR}"
    if [ ! -f "${RL_DIR}/lib/libraylib.a" ]; then
        echo "raylib not found system-wide; vendoring the prebuilt static release..."
        mkdir -p vendor
        curl -fsSL "https://github.com/raysan5/raylib/releases/download/${RL_VER}/${RL_TAR}.tar.gz" \
            | tar xz -C vendor
    fi
    INC="$PWD/${RL_DIR}/include"
    LIB="$PWD/${RL_DIR}/lib"
    tmp="$(mktemp)"
    "$MACHIN" encode "$SRC" \
        | sed "s#header \"raylib.h\"#cflags \"-I${INC} -L${LIB}\" header \"raylib.h\"#; s#link \"raylib\"#link \":libraylib.a\"#" \
        > "$tmp"
    mv "$tmp" softbody-demo.mfl
fi

"$MACHIN" build softbody-demo.mfl -o "$BIN"
echo "built ./$BIN"
