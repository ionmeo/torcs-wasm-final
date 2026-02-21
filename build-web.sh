#!/bin/bash
# Link TORCS for web browser
# Prerequisites: Run 'make' first to build everything
# Usage: ./build-web.sh

set -e

# Source environment
source emscripten-env.sh

echo "Linking for web..."

EXPORT_DIR="$(pwd)/export"
WEB_DIR="$(pwd)/web"

# Object files from src/linux
OBJECTS="src/linux/main.o src/linux/linuxspec.o"

# TORCS shared libraries (order matters for dependencies)
SOLIBS="-lracescreens -lrobottools -lclient -lconfscreens -ltgf -ltgfclient -ltxml -lplibul -lraceengine -lmusicplayer -llearning"

# PLIB and external libraries
EXT_LIBS="-lplibjs -lplibssgaux -lplibssg -lplibsm -lplibsl -lplibsg -lplibul -lglut -lGLU -lGL -lm -lopenal"

# Emscripten flags
EM_FLAGS=""
EM_FLAGS="$EM_FLAGS -sUSE_VORBIS=1"
EM_FLAGS="$EM_FLAGS -sUSE_ZLIB=1"
EM_FLAGS="$EM_FLAGS -sUSE_LIBPNG=1"
EM_FLAGS="$EM_FLAGS -sLEGACY_GL_EMULATION=1"
EM_FLAGS="$EM_FLAGS -sALLOW_MEMORY_GROWTH=1"

# Memory settings
EM_FLAGS="$EM_FLAGS -sSTACK_SIZE=5MB"
EM_FLAGS="$EM_FLAGS -sINITIAL_MEMORY=128MB"

# Dynamic linking support (TORCS uses dlopen for modules)
EM_FLAGS="$EM_FLAGS -sMAIN_MODULE=2"

# Debug flags (remove for release)
EM_FLAGS="$EM_FLAGS -sASSERTIONS=2"
EM_FLAGS="$EM_FLAGS -sGL_ASSERTIONS=1"
EM_FLAGS="$EM_FLAGS -sSAFE_HEAP=1"
EM_FLAGS="$EM_FLAGS -sSTACK_OVERFLOW_CHECK=2"
EM_FLAGS="$EM_FLAGS -g"

# Preload data files
# TORCS looks for files at data/ (e.g., data/fonts/b7.glf)
# Note: web/data/ contains data/, cars/, tracks/ subdirectories
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/data@data"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/cars@cars"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/tracks@tracks"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/categories@categories"

# Preload modules, drivers, and config
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/modules@modules"
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/drivers@drivers"
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/config@config"

# Output settings
EM_FLAGS="$EM_FLAGS -o $WEB_DIR/torcs.html"

# Link
/c/emsdk/upstream/emscripten/em++.bat \
    $OBJECTS \
    -L"$EXPORT_DIR/lib" \
    $SOLIBS \
    $EXT_LIBS \
    $EM_FLAGS

echo "Build complete: $WEB_DIR/torcs.html"
echo "To run: cd web && python -m http.server 8080"
echo "Then open: http://localhost:8080/torcs.html"
