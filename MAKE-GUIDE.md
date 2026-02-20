Using export LDFLAGS="-Wl,--error-limit=0" temporarily in emscripten-env.sh

we get the following undefined symbols are left after using LEGACY_GL_EMULATION

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
wasm-ld: error: undefined symbol: glutInitDisplayString
wasm-ld: error: undefined symbol: glutGameModeString
wasm-ld: error: undefined symbol: glutGameModeGet
wasm-ld: error: undefined symbol: glutEnterGameMode
wasm-ld: error: undefined symbol: glutLeaveGameMode
wasm-ld: error: undefined symbol: glutExtensionSupported
wasm-ld: error: undefined symbol: glutWarpPointer
wasm-ld: error: undefined symbol: glRasterPos2i
wasm-ld: error: undefined symbol: glPixelZoom
wasm-ld: error: undefined symbol: glDrawPixels

So, add stubs for the gl functions in src/libs/tgfclient/gl_stubs.c

```
#ifdef __EMSCRIPTEN__

#include <GL/gl.h>
#include <stdio.h>

void glDeleteLists(GLuint list, GLsizei range) {
}

void glCallList(GLuint list) {
}

void glPushName(GLuint name) {
}

void glLoadName(GLuint name) {
}

void glPopName(void) {
}

void glPushAttrib(GLbitfield mask) {
}

void glPopAttrib(void) {
}

void glPushClientAttrib(GLbitfield mask) {
}

void glPopClientAttrib(void) {
}

void glRasterPos2i(GLint x, GLint y) {
}

void glPixelZoom(GLfloat xfactor, GLfloat yfactor) {
}

void glDrawPixels(GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid *pixels) {
}

void glArrayElement(GLint i) {
}

void glColorMaterial(GLenum face, GLenum mode) {
}

void glMaterialf(GLenum face, GLenum pname, GLfloat param) {
}

void glLightf(GLenum light, GLenum pname, GLfloat param) {
}

#endif /* __EMSCRIPTEN__ */
```

Add stubs for the glut functions in src/libs/tgfclient/glut_stubs.cpp

```
#ifdef __EMSCRIPTEN__

#include <GL/glut.h>
#include <cstring>

void glutGameModeString(const char *string)
{
}

int glutEnterGameMode(void)
{
    return 0;
}

void glutLeaveGameMode(void)
{
}

int glutGameModeGet(GLenum mode)
{
    switch (mode)
    {
    case GLUT_GAME_MODE_ACTIVE:
        return 0; // Not active
    case GLUT_GAME_MODE_POSSIBLE:
        return 0; // Not possible
    case GLUT_GAME_MODE_DISPLAY_CHANGED:
        return 0; // Display not changed
    default:
        return 0;
    }
}

void glutInitDisplayString(const char *string)
{
}

int glutExtensionSupported(const char *name)
{
    return 0;
}

void glutWarpPointer(int x, int y)
{
}

#endif // __EMSCRIPTEN__
```

Modify src/libs/tgfclient/Makefile to use these stubs files

```
SOURCES   = 	guimenu.cpp \
		screen.cpp \
		gui.cpp \
		guifont.cpp \
		guiobject.cpp \
		guilabel.cpp \
		guibutton.cpp \
		guiedit.cpp \
		guihelp.cpp \
		img.cpp \
		guiscrollist.cpp \
		guiscrollbar.cpp \
		guiimage.cpp \
		control.cpp \
		fg_gm.cpp \
		tgfclient.cpp \
		glfeatures.cpp \
		glut_stubs.cpp \
		gl_stubs.c
```

Error:

C-api.cpp:128:11: error: use of undeclared identifier 'uint'
  128 |   while ((uint)i < pointBuf.size() && !(pointBuf[i] == p)) ++i;
      |           ^~~~
C-api.cpp:129:8: error: use of undeclared identifier 'uint'
  129 |   if ((uint)i == pointBuf.size()) pointBuf.push_back(p);
      |        ^~~~
C-api.cpp:165:8: error: unknown type name 'uint'; did you mean 'int'?
  165 |   for (uint i = 0; i < count; ++i) indices[i] = first + i;
      |        ^~~~
      |        int
3 errors generated.

Change

#ifdef WIN32
#define uint unsigned int
#endif

to

#if defined(WIN32) || defined(__EMSCRIPTEN__)
#define uint unsigned int
#endif

in src/modules/simu/simuv2/SOLID-2.0/src/C-api.cpp

Error:

D:/game2/torcs-wasm-final/export/include\plib\slPortability.h:73:14: fatal error: 'soundcard.h' file not found
   73 | #    include <soundcard.h>
      |              ^~~~~~~~~~~~~
1 error generated.

Change

#if (defined(UL_LINUX) || defined(UL_BSD)) && !defined(__NetBSD__)
#define SL_USING_OSS_AUDIO 1
#endif

to

#if (defined(UL_LINUX) || defined(UL_BSD)) && !defined(__NetBSD__) && !defined(UL_EMSCRIPTEN)
#define SL_USING_OSS_AUDIO 1
#endif

in external/plib/src/sl/slPortability.h

After this change, run:

cd external/plib
make install
cd ../..
make

Error:

driver.cpp:805:13: error: non-constant-expression cannot be narrowed from type 'double' to 'float' in initializer list [-Wc++11-narrowing]
  805 |             rpmMax*2.0
      |             ^~~~~~~~~~


Change

float a [] = {		
        0.0,
        rpmMaxTq,
        rpmMaxPw,
        rpmMax,
        rpmMax*2.0
};


to

float a [] = {
        0.0f,
        rpmMaxTq,
        rpmMaxPw,
        rpmMax,
        rpmMax*2.0f
};

in src/driers/olethros/driver.cpp

