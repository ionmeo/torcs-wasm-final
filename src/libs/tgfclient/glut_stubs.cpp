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