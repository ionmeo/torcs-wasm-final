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