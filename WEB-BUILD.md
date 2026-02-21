# Building TORCS for Web (After `make` Works)

## Prerequisites
- Emscripten SDK installed (at `C:/emsdk`)
- `make` has successfully completed
- TORCS data files copied to `web/data/` from original TORCS

---

## Step 1: Verify Build Output

After `make` completes, verify you have:
- `src/linux/torcs-bin.wasm` - the compiled WASM binary
- `src/linux/main.o` and `src/linux/linuxspec.o` - object files
- `export/lib/*.so` - shared libraries (actually WASM files)
- `export/modules/` - dynamically loaded modules
- `export/drivers/` - AI drivers

---

## Step 2: Fix Data Directory Structure

TORCS expects specific paths. Your `web/data/` likely has nested structure (`web/data/data/`, `web/data/cars/`, etc.). You need:

**Create categories directory** (TORCS expects `categories/*.xml` at root):
```bash
mkdir -p web/data/categories
for dir in web/data/cars/categories/*/; do
    name=$(basename "$dir")
    if [ -f "$dir$name.xml" ]; then
        cp "$dir$name.xml" "web/data/categories/"
    fi
done
```

---

## Step 3: Copy Config Files

Config files aren't automatically installed. Copy them manually:
```bash
mkdir -p export/config/raceman

cp src/libs/tgfclient/screen.xml export/config/
cp src/modules/graphic/ssggraph/graph.xml export/config/
cp src/modules/graphic/ssggraph/sound.xml export/config/
cp src/libs/raceengineclient/raceengine.xml export/config/
cp src/libs/raceengineclient/style.xsl export/config/
cp src/raceman/*.xml export/config/raceman/
```

---

## Step 4: Create build-web.sh

Create the linking script:

```bash
#!/bin/bash
# Link TORCS for web browser
# Prerequisites: Run 'make' first

set -e
source emscripten-env.sh

echo "Linking for web..."

EXPORT_DIR="$(pwd)/export"
WEB_DIR="$(pwd)/web"

# Object files
OBJECTS="src/linux/main.o src/linux/linuxspec.o"

# TORCS libraries
SOLIBS="-lracescreens -lrobottools -lclient -lconfscreens -ltgf -ltgfclient -ltxml -lplibul -lraceengine -lmusicplayer -llearning"

# External libraries
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

# Dynamic linking (TORCS uses dlopen)
EM_FLAGS="$EM_FLAGS -sMAIN_MODULE=2"

# Debug flags (remove for release)
EM_FLAGS="$EM_FLAGS -sASSERTIONS=2"
EM_FLAGS="$EM_FLAGS -sGL_ASSERTIONS=1"
EM_FLAGS="$EM_FLAGS -sSAFE_HEAP=1"
EM_FLAGS="$EM_FLAGS -sSTACK_OVERFLOW_CHECK=2"
EM_FLAGS="$EM_FLAGS -g"

# Preload data files (adjust paths based on your structure)
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/data@data"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/cars@cars"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/tracks@tracks"
EM_FLAGS="$EM_FLAGS --preload-file $WEB_DIR/data/categories@categories"

# Preload modules, drivers, config
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/modules@modules"
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/drivers@drivers"
EM_FLAGS="$EM_FLAGS --preload-file $EXPORT_DIR/config@config"

# Output
EM_FLAGS="$EM_FLAGS -o $WEB_DIR/torcs.html"

# Link
/c/emsdk/upstream/emscripten/em++.bat \
    $OBJECTS \
    -L"$EXPORT_DIR/lib" \
    $SOLIBS \
    $EXT_LIBS \
    $EM_FLAGS

echo "Build complete: $WEB_DIR/torcs.html"
```

---

## Step 5: Run the Build

```bash
./build-web.sh
```

This generates in `web/`:
- `torcs.html` - HTML page
- `torcs.js` - JavaScript glue code
- `torcs.wasm` - WebAssembly binary
- `torcs.data` - Preloaded filesystem data

---

## Step 6: Run in Browser

```bash
cd web
python -m http.server 8080
```

Open: `http://localhost:8080/torcs.html`

---

## Important Notes

1. **Do NOT use `-sFULL_ES2=1`** - conflicts with `LEGACY_GL_EMULATION`

2. **Preload paths matter**: The `@` syntax maps filesystem paths:
   - `--preload-file source@destination` mounts `source` at `destination` in the virtual filesystem

3. **Debug flags for release**: Remove these for production builds:
   - `-sASSERTIONS=2`
   - `-sSAFE_HEAP=1`
   - `-sSTACK_OVERFLOW_CHECK=2`
   - `-g`

4. **Common errors**:
   - "No such file or directory" → Check preload paths match what TORCS expects
   - "Segfault in GenCarsInfo" → Missing categories directory
   - "Heap corruption" → Missing config files or insufficient memory

---

## Fixes Applied

### Fix 1: Black rectangle covering menu text

Change in `src/libs/tgfclient/guifont.cpp`:
```cpp
// Before
glTexImage2D(GL_TEXTURE_2D, 0, 2, font->TexWidth,
// After
glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE_ALPHA, font->TexWidth,
```