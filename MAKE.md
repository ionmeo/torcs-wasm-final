# Emscripten Build Guide

This guide documents how to build TORCS for WebAssembly using Emscripten on Windows (Git Bash).

## Usage

```bash
# After running configure (see CONFIGURE.md)
make
```

---

## Build Details

The sections below document the changes needed to get `make` working with Emscripten on Windows (Git Bash). This may be useful if you are porting something to WebAssembly or need to debug build issues.

### Path Format Compatibility

When running `make`, the build system uses `$(shell pwd)` to determine `TORCS_BASE`. On Git Bash, this returns a Unix-style path (`/d/game/torcs-wasm`) that Windows Make cannot handle properly. So, the build stops without compiling anything:

```
make
<path to make.exe> TORCS_BASE=/d/game/torcs-wasm MAKE_DEFAULT=/d/game/torcs-wasm/Make-default.mk
make[1]: Entering directory 'D:/game/torcs-wasm'
make[1]: 'Make-config' is up to date.
make[1]: Leaving directory 'D:/game/torcs-wasm'
```

To fix this issue, `Makefile` is modified to use `$(CURDIR)` on Windows, which returns a Windows-compatible path (`D:/game/torcs-wasm`):

```makefile
ifeq ($(OS),Windows_NT)
    TORCS_PWD = $(CURDIR)
else
    TORCS_PWD = $(shell pwd)
endif

TORCS_BASE = $(TORCS_PWD)
```

### Paths with Spaces

The `mkinstalldirs` variable in `Make-config.in` is defined as:

```makefile
mkinstalldirs = $(SHELL) $(top_srcdir)/mkinstalldirs
```

When `$(SHELL)` expands to a path containing spaces (e.g., `C:/Program Files/Git/usr/bin/sh.exe`), the shell interprets it as separate arguments, causing errors like:

```
/usr/bin/sh: line 3: C:/Program: No such file or directory
ln: failed to create symbolic link 'D:/game/torcs-wasm/export/include/car.h': No such file or directory
```

To fix this issue, add quotes around the paths in `Make-config`:

```makefile
mkinstalldirs = "$(SHELL)" "$(top_srcdir)/mkinstalldirs"
```

### Filtering X11 Libraries

The configure script detects X11 libraries which do not exist in Emscripten. As a result, the following errors show up when running `make`:

```
wasm-ld: error: unable to find library -lXrandr
wasm-ld: error: unable to find library -lXrender
...
```

To fix this, use `filter-out` to remove the X11 libraries in `Make-config.in`.

```makefile
EXT_LIBS = $(filter-out -lXrandr -lXrender -lXxf86vm -lXmu -lXi -lXt -lSM -lICE -lXext,@LIBS@)
```

### Using Emscripten Ports for Libraries

Along with the X11 errors, the following errors also appear:

```
wasm-ld: error: unable to find library -lvorbisfile
wasm-ld: error: unable to find library -lpng
wasm-ld: error: unable to find library -lz
```

Emscripten's port system provides pre-built versions of these libraries via `-sUSE_*` flags. So, `LDFLAGS` in `Make-config.in` is modified to use these flags:

```makefile
LDFLAGS = -L${EXPORTBASE}/lib $(filter-out -lvorbisfile,@LDFLAGS@) -L/usr/lib -sUSE_VORBIS=1 -sUSE_ZLIB=1 -sUSE_LIBPNG=1
```

`-lpng` and `-lz` are also filtered out from `EXT_LIBS` as they are now fetched using port flags:

```makefile
EXT_LIBS = $(filter-out -lXrandr -lXrender -lXxf86vm -lXmu -lXi -lXt -lSM -lICE -lXext -lpng -lz,@LIBS@)
```

Note: Since Emscripten's vorbis port is used, `external/vorbis` and `external/ogg` can be removed.

### PLIB Libraries

At this point, the linker fails with missing PLIB libraries:

```
wasm-ld: error: unable to find library -lplibjs
wasm-ld: error: unable to find library -lplibssgaux
wasm-ld: error: unable to find library -lplibssg
wasm-ld: error: unable to find library -lplibsm
wasm-ld: error: unable to find library -lplibsl
wasm-ld: error: unable to find library -lplibsg
wasm-ld: error: unable to find library -lplibul
```

TORCS depends on PLIB (Portable Game Library) for 3D rendering, scene graph management, and other features. PLIB must also be compiled with Emscripten and installed to `export/lib`. See `PLIB-BUILD.md` for instructions.

### X11 Headers in `fg_gm.cpp`

`src/libs/tgfclient/fg_gm.cpp` includes X11 headers for non-Windows platforms:

```c
#ifndef WIN32

#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
```

Emscripten does not have X11, so the build fails:

```
fg_gm.cpp:64:10: fatal error: 'X11/extensions/xf86vmode.h' file not found
   64 | #include <X11/extensions/xf86vmode.h>
```

To fix this issue, exclude Emscripten from the X11 code path:

```c
#if !defined(WIN32) && !defined(__EMSCRIPTEN__)

#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
```

### Non-Standard `uint` Type

Several files use `uint` which is a non-standard type alias not provided by Emscripten:

```
.\guifont.h:33:5: error: unknown type name 'uint'; did you mean 'int'?
   33 |     uint Tex;
```

To fix this issue, replace `uint` with `unsigned int` in:
- `src/libs/tgfclient/guifont.h`
- `src/libs/tgfclient/guifont.cpp`
- `src/libs/tgfclient/guiedit.cpp`

### XRandR Extension

`src/libs/tgfclient/screen.cpp` uses the X11 RandR extension for display mode detection:

```c
#ifdef USE_RANDR_EXT
#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/extensions/Xrandr.h>
#endif
```

This causes errors on Emscripten:

```
screen.cpp:55:10: fatal error: 'X11/extensions/Xrandr.h' file not found
```

Even after adding `!defined(__EMSCRIPTEN__)` to the include guard, X11 types like `Display`, `Window`, and `XRRScreenConfiguration` cause errors because `USE_RANDR_EXT` is still defined elsewhere:

```
screen.cpp:117:2: error: unknown type name 'Display'
screen.cpp:122:6: error: unknown type name 'Window'
screen.cpp:124:3: error: unknown type name 'XRRScreenConfiguration'
```

To fix this issue, we have to undefine `USE_RANDR_EXT` after the include block:

```c
#if defined(USE_RANDR_EXT) && !defined(__EMSCRIPTEN__)
#include <GL/glx.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <X11/extensions/Xrandr.h>
#else
#ifdef USE_RANDR_EXT
#undef USE_RANDR_EXT
#endif
#endif
```

### FreeGLUT Game Mode Functions

`src/libs/tgfclient/fg_gm.cpp` contains custom implementations of FreeGLUT game mode functions that use X11 internals:

```c
void fglutGameModeString( const char* string )
{
#ifndef WIN32
    int width = 640, height = 480, depth = 16, refresh = 72;
    ...
    fgState.GameModeSize.X  = width;
```

These reference internal FreeGLUT state (`fgState`) and X11 functions (`fghRememberState`, `fghChangeDisplayMode`) that don't exist in Emscripten:

```
fg_gm.cpp:492:5: error: use of undeclared identifier 'fgState'
fg_gm.cpp:508:5: error: use of undeclared identifier 'fghRememberState'
fg_gm.cpp:512:9: error: use of undeclared identifier 'fghChangeDisplayMode'
```

To fix this issue, add `__EMSCRIPTEN__` checks to all three game mode functions:

```c
void fglutGameModeString( const char* string )
{
#if !defined(WIN32) && !defined(__EMSCRIPTEN__)
```

```c
int fglutEnterGameMode( void )
{
#if !defined(WIN32) && !defined(__EMSCRIPTEN__)
```

```c
void fglutLeaveGameMode( void )
{
#if !defined(WIN32) && !defined(__EMSCRIPTEN__)
```

### Ambiguous `strndup`

Emscripten provides its own `strndup`, which conflicts with the fallback implementation in `src/libs/portability/portability.h`:

```
raceinit.cpp:152:24: error: call to 'strndup' is ambiguous
  152 |         ReInfo->_reFilename = strndup(s, e-s+1);
```

To fix this issue, we have to exclude Emscripten from the fallback:

```c
#if !defined(HAVE_STRNDUP) && !defined(__EMSCRIPTEN__)

static char *strndup(const char *str, int len)
{
    ...
}

#endif
```

### C++17 `register` Keyword

Emscripten defaults to C++17, which removed the `register` storage class specifier. Multiple files in both TORCS and PLIB use this keyword:

```
MathFunctions.cpp:183:3: error: ISO C++17 does not allow 'register' storage class specifier
  183 |                 register real d = (*a++) - (*b++);
```

Rather than modifying each file, add `-Wno-register` to `CXXFLAGS` in `emscripten-env.sh`:

```bash
export CXXFLAGS="$CPPFLAGS -Wno-register"
```

After this change, we have to run configure again for it to take effect:

```bash
source emscripten-env.sh
cp emscripten.cache config.cache
./configure -C --build=any --host=wasm
make
```

### OpenAL Music Player Null Pointer

`src/libs/musicplayer/OpenALMusicPlayer.cpp` incorrectly initializes a `const char*` with a character literal:

```c
const char* error = '\0';
```

This fails in C++:

```
OpenALMusicPlayer.cpp:164:14: error: cannot initialize a variable of type 'const char *' with an rvalue of type 'char'
```

Change it to:

```c
const char* error = nullptr;
```

### Duplicate jsJoystick Symbols

Both `libconfscreens` and `libtgfclient` have `LIBS = -lplibjs` in their Makefiles. When Emscripten builds shared libraries, it embeds the static library symbols into each `.so`, causing duplicates at link time:

```
wasm-ld: error: duplicate symbol: jsJoystick::jsJoystick(int)
>>> defined in D:/game/torcs-wasm/export/lib\libconfscreens.so
>>> defined in D:/game/torcs-wasm/export/lib\libtgfclient.so
```

The PLIB libraries are already linked when building the final `torcs-bin` executable via `EXT_LIBS` in `Make-config`:

```makefile
EXT_LIBS = ... -lplibjs -lplibssgaux -lplibssg -lplibsm -lplibsl -lplibsg -lplibul ...
```

So, the individual `.so` libraries don't need to link `-lplibjs` themselves. Therefore, `LIBS = -lplibjs` is commented out in both `src/libs/confscreens/Makefile` and `src/libs/tgfclient/Makefile`.

Run `make clean && make` for the change to take effect.

### Legacy OpenGL Emulation

At this point, the linker reports many undefined OpenGL symbols:

```
wasm-ld: error: D:/game/torcs-wasm/export/lib\libclient.so: undefined symbol: glTexCoord2f
wasm-ld: error: D:/game/torcs-wasm/export/lib\libclient.so: undefined symbol: glVertex3f
wasm-ld: error: D:/game/torcs-wasm/export/lib\libclient.so: undefined symbol: glEnd
wasm-ld: error: D:/game/torcs-wasm/export/lib\libclient.so: undefined symbol: glPushMatrix
...
```

TORCS and PLIB use OpenGL 1.x immediate mode functions (`glBegin`, `glEnd`, `glVertex3f`, etc.) which don't exist in WebGL. Emscripten provides `-sLEGACY_GL_EMULATION=1` to emulate these functions on top of WebGL.

So, add this flag to `LDFLAGS` in `Make-config.in`:

```makefile
LDFLAGS = -L${EXPORTBASE}/lib $(filter-out -lvorbisfile,@LDFLAGS@) -L/usr/lib -sUSE_VORBIS=1 -sUSE_ZLIB=1 -sUSE_LIBPNG=1 -sLEGACY_GL_EMULATION=1
```

This resolves many of the undefined symbols, leaving only functions that the legacy emulation does not support (display lists, selection/picking, pixel operations, etc.).

### Unsupported OpenGL Functions

To see all remaining undefined symbols, temporarily add `--error-limit=0` to `LDFLAGS` in `emscripten-env.sh`:

```bash
export LDFLAGS="-Wl,--error-limit=0"
```

After running `make`, the following undefined symbols remain:

```
wasm-ld: error: undefined symbol: glDeleteLists
wasm-ld: error: undefined symbol: glColorMaterial
wasm-ld: error: undefined symbol: glMaterialf
wasm-ld: error: undefined symbol: glCallList
wasm-ld: error: undefined symbol: glPushName
wasm-ld: error: undefined symbol: glLoadName
wasm-ld: error: undefined symbol: glPopName
wasm-ld: error: undefined symbol: glPushAttrib
wasm-ld: error: undefined symbol: glPopAttrib
wasm-ld: error: undefined symbol: glPushClientAttrib
wasm-ld: error: undefined symbol: glPopClientAttrib
wasm-ld: error: undefined symbol: glArrayElement
wasm-ld: error: undefined symbol: glRasterPos2i
wasm-ld: error: undefined symbol: glPixelZoom
wasm-ld: error: undefined symbol: glDrawPixels
wasm-ld: error: undefined symbol: glLightf
```

These are OpenGL 1.x functions that Emscripten's legacy GL emulation does not support:

- `glDeleteLists`, `glCallList` - Display lists (pre-compiled command sequences)
- `glPushName`, `glLoadName`, `glPopName` - Selection/picking (identifying objects under cursor)
- `glPushAttrib`, `glPopAttrib`, `glPushClientAttrib`, `glPopClientAttrib` - State stack operations
- `glRasterPos2i`, `glPixelZoom`, `glDrawPixels` - Pixel operations (direct framebuffer access)
- `glArrayElement` - Indexed vertex array access
- `glColorMaterial`, `glMaterialf`, `glLightf` - Fixed-function lighting

To fix this, create stub implementations in `src/libs/tgfclient/gl_stubs.c`:

```c
#ifdef __EMSCRIPTEN__

#include <GL/gl.h>

void glDeleteLists(GLuint list, GLsizei range) {}
void glCallList(GLuint list) {}
void glPushName(GLuint name) {}
void glLoadName(GLuint name) {}
void glPopName(void) {}
void glPushAttrib(GLbitfield mask) {}
void glPopAttrib(void) {}
void glPushClientAttrib(GLbitfield mask) {}
void glPopClientAttrib(void) {}
void glRasterPos2i(GLint x, GLint y) {}
void glPixelZoom(GLfloat xfactor, GLfloat yfactor) {}
void glDrawPixels(GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid *pixels) {}
void glArrayElement(GLint i) {}
void glColorMaterial(GLenum face, GLenum mode) {}
void glMaterialf(GLenum face, GLenum pname, GLfloat param) {}
void glLightf(GLenum light, GLenum pname, GLfloat param) {}

#endif
```

### Unsupported GLUT Functions

The following GLUT functions are also undefined:

```
wasm-ld: error: undefined symbol: glutInitDisplayString
wasm-ld: error: undefined symbol: glutGameModeString
wasm-ld: error: undefined symbol: glutGameModeGet
wasm-ld: error: undefined symbol: glutEnterGameMode
wasm-ld: error: undefined symbol: glutLeaveGameMode
wasm-ld: error: undefined symbol: glutExtensionSupported
wasm-ld: error: undefined symbol: glutWarpPointer
```

These are FreeGLUT extensions not available in Emscripten's GLUT implementation:

- `glutGameModeString`, `glutEnterGameMode`, `glutLeaveGameMode`, `glutGameModeGet` - Fullscreen game mode
- `glutInitDisplayString` - Advanced display configuration
- `glutExtensionSupported` - OpenGL extension queries
- `glutWarpPointer` - Mouse cursor repositioning

Create stub implementations in `src/libs/tgfclient/glut_stubs.cpp`:

```cpp
#ifdef __EMSCRIPTEN__

#include <GL/glut.h>

void glutGameModeString(const char *string) {}

int glutEnterGameMode(void) {
    return 0;
}

void glutLeaveGameMode(void) {}

int glutGameModeGet(GLenum mode) {
    switch (mode) {
    case GLUT_GAME_MODE_ACTIVE:
        return 0;
    case GLUT_GAME_MODE_POSSIBLE:
        return 0;
    case GLUT_GAME_MODE_DISPLAY_CHANGED:
        return 0;
    default:
        return 0;
    }
}

void glutInitDisplayString(const char *string) {}

int glutExtensionSupported(const char *name) {
    return 0;
}

void glutWarpPointer(int x, int y) {}

#endif
```

Add both stub files to `src/libs/tgfclient/Makefile`:

```makefile
SOURCES = guimenu.cpp \
    ...
    glfeatures.cpp \
    glut_stubs.cpp \
    gl_stubs.c
```

### SOLID Physics Library `uint` Type

`src/modules/simu/simuv2/SOLID-2.0/src/C-api.cpp` uses the non-standard `uint` type:

```
C-api.cpp:128:11: error: use of undeclared identifier 'uint'
  128 |   while ((uint)i < pointBuf.size() && !(pointBuf[i] == p)) ++i;
```

The file already has a typedef for Win32:

```c
#ifdef WIN32
#define uint unsigned int
#endif
```

Add `__EMSCRIPTEN__` to the guard:

```c
#if defined(WIN32) || defined(__EMSCRIPTEN__)
#define uint unsigned int
#endif
```

### OSS Audio in PLIB

`external/plib-1.8.5/src/sl/slPortability.h` enables OSS (Open Sound System) audio for Linux and BSD:

```c
#if (defined(UL_LINUX) || defined(UL_BSD)) && !defined(__NetBSD__)
#define SL_USING_OSS_AUDIO 1
#endif
```

When `SL_USING_OSS_AUDIO` is defined, `sl.h` includes `<soundcard.h>`:

```c
#ifdef SL_USING_OSS_AUDIO
#  if defined(__linux__)
#    include <soundcard.h>
```

Emscripten defines `__unix__` which triggers the `UL_BSD` fallback (see PLIB-BUILD.md), causing:

```
slPortability.h:73:14: fatal error: 'soundcard.h' file not found
   73 | #    include <soundcard.h>
```

OSS is a Linux/BSD kernel audio interface that doesn't exist in browsers. To fix this, exclude Emscripten from the OSS audio path in `slPortability.h`:

```c
#if (defined(UL_LINUX) || defined(UL_BSD)) && !defined(__NetBSD__) && !defined(UL_EMSCRIPTEN)
#define SL_USING_OSS_AUDIO 1
#endif
```

After this change, rebuild and reinstall PLIB:

```bash
cd external/plib-1.8.5
make install
cd ../..
make
```

### C++11 Narrowing in Olethros Driver

`src/drivers/olethros/driver.cpp` has a narrowing conversion error:

```
driver.cpp:805:13: error: non-constant-expression cannot be narrowed from type 'double' to 'float' in initializer list [-Wc++11-narrowing]
  805 |             rpmMax*2.0
```

The code initializes a `float` array with `double` expressions:

```c
float a [] = {
    0.0,
    rpmMaxTq,
    rpmMaxPw,
    rpmMax,
    rpmMax*2.0
};
```

`2.0` is a `double` literal, making `rpmMax*2.0` a `double`. C++11 disallows implicit narrowing in initializer lists. To fix this, use `float` literals:

```c
float a [] = {
    0.0f,
    rpmMaxTq,
    rpmMaxPw,
    rpmMax,
    rpmMax*2.0f
};
```

