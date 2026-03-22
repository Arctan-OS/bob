export ARC_BUILD_SUPPORT="$PWD/build-support"
export ARC_HOST_PREFIX="$PWD/sysroot/usr"

mkdir -p $ARC_HOST_PREFIX

CFLAGS="-O2 -pipe -fstack-clash-protection"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"

export LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now"
export ARC_SET_BUILD_COMPILER_ENV_FLAGS="CFLAGS=$CFLAGS CXXFLAGS=$CXXFLAGS LDFLAGS=$LDFLAGS"
export ARC_SET_TARGET_COMPILER_ENV_FLAGS="CFLAGS_FOR_TARGET=$CFLAGS CXXFLAGS_FOR_TARGET=$CXXFLAGS"

source ./bob.sh
