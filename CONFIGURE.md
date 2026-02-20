# Emscripten Configuration Guide

This guide documents how to configure TORCS for WebAssembly using Emscripten on Windows (Git Bash).

## Usage

```bash
git clone https://github.com/ionmeo/torcs-wasm
cd torcs-wasm
source emscripten-env.sh
cp emscripten.cache config.cache
embuilder.bat build vorbis
./configure -C --build=any --host=wasm
```

**Note:** `emscripten-env.sh` assumes Emscripten is installed at `C:\emsdk`.

---

## Files Added for `configure`

```
torcs-wasm/
├── emstubs/          # Empty stub headers for X11
│   └── GL/
│       └── glx.h
├── external/         # Third-party dependency headers
│   ├── plib/
│   ├── AL/           # OpenAL/ALUT
├── emscripten-env.sh
└── emscripten.cache
```

---

## Configuration Details

The sections below document the changes needed to get `./configure` working with Emscripten. This may be useful if you are porting something to WebAssembly or need to debug configuration issues.

### Cross-Compilation Mode

To run in cross-compilation mode, we need to set different values for `--build` and `--host`. So, technically, you can run with `--build=a --host=b` instead of `--build=any --host=wasm`.

### Environment Variables

The `emscripten-env.sh` script sets up the Emscripten compilers and include paths:

```bash
export CC="/c/emsdk/upstream/emscripten/emcc.bat"
export CXX="/c/emsdk/upstream/emscripten/em++.bat"
export AR="/c/emsdk/upstream/emscripten/emar.bat"
export RANLIB="/c/emsdk/upstream/emscripten/emranlib.bat"
export LD="/c/emsdk/upstream/emscripten/emcc.bat"

export CPPFLAGS="-I$(pwd)/emstubs -I$(pwd)/external"
export CFLAGS="$CPPFLAGS"
export CXXFLAGS="$CPPFLAGS"
```

The compiler variables point to Emscripten's toolchain, and the include flags add `emstubs/` and `external/` to the header search path.

### Missing Headers

The `configure` script checks for headers that are either unavailable in Emscripten (such as X11 headers) or are external dependencies not included in the repository. The `external/` directory contains these headers so that `configure` works without additional setup.

**Stub headers** are empty files created to pass configure checks for headers we do not actually need. For example, `GL/glx.h` is the X11-specific OpenGL binding, but WebAssembly uses WebGL instead of X11, so an empty file is sufficient:

```bash
mkdir -p emstubs/GL
touch emstubs/GL/glx.h
```

**Dependency headers** are required when `configure` checks for external libraries. When `configure` fails with an error like `configure: error: Can't find plib/ssg.h`, download the package and copy the required header to `external/plib/ssg.h`. The general pattern is `external/<package name>/<filename>`.

Headers often include other headers, so you need to copy all dependency files as well. For example, `ssg.h` contains `#include "sg.h"` and `#include "ssgconf.h"`, so we need to copy those two files to `external/plib/`. Similarly, `sg.h` includes `ul.h`, so we need to copy `ul.h` to `external/plib/` too. If any header in the include chain is missing, `configure` will still report `Can't find <package>/<file>`. For example, if we have `ssg.h`, `sg.h`, and `ssgconf.h` in `external/plib/` but are missing `ul.h`, running `configure` will still show `Can't find plib/ssg.h`. To find the actual missing file, check `config.log` (which would reveal `ul.h` in this example).

| Dependency | Source | Folder | Headers |
|------------|--------|--------|---------|
| plib-1.8.5 | [sourceforge](https://plib.sourceforge.net/download.html) | `plib/` | `js.h`, `sg.h`, `ssg.h`, `ssgaFire.h`, `ssgaLensFlare.h`, `ssgaParticleSystem.h`, `ssgaScreenDump.h`, `ssgaShapes.h`, `ssgAux.h`, `ssgaWaveSystem.h`, `ssgconf.h`, `ul.h` |
| freealut | [github](https://github.com/vancegroup/freealut) | `AL/` | `alut.h` |

### Missing Libraries

`configure` checks for native libraries (libX11, libGL, libpng, etc.) that do not exist in Emscripten. These checks fail even though Emscripten provides web-based equivalents.

To bypass these checks, we provide the autoconf cache with "yes" answers:

```bash
export ac_cv_lib_GL_glGetString=yes
export ac_cv_lib_png_png_init_io=yes
# ... etc
```

Only checks that cause configure to error out need to be cached. Checks that simply report "no" without stopping (e.g., `checking for dlopen in -ldl... no`) can be ignored.

The following library checks are cached in `emscripten.cache`:

- X11 libraries (Xext, ICE, SM, Xt, Xi, Xmu, Xxf86vm, Xrender, Xrandr)
- Audio (openal, vorbisfile)
- System (dlopen function, zlib, libpng)
- Graphics (GL, GLU, glut)
- PLIB (plibul, plibsg, plibsl, plibsm, plibssg, plibssgaux, plibjs)