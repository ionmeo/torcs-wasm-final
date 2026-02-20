# Compilers
export CC="/c/emsdk/upstream/emscripten/emcc.bat"
export CXX="/c/emsdk/upstream/emscripten/em++.bat"
export AR="/c/emsdk/upstream/emscripten/emar.bat"
export RANLIB="/c/emsdk/upstream/emscripten/emranlib.bat"
export LD="/c/emsdk/upstream/emscripten/emcc.bat"

# Include paths
export CPPFLAGS="-I$(pwd)/emstubs -I$(pwd)/external -I$(pwd)/export/include"
export CFLAGS="$CPPFLAGS"
export CXXFLAGS="$CPPFLAGS -Wno-register"
