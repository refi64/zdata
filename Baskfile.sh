NDK_BUILD="`which ndk-build`"
if [ -z "$NDK_BUILD" ]; then
  echo 'Cannot find ndk-build binary.'
  exit 1
fi


NDK="`dirname "$NDK_BUILD"`"

BOOST_URL="https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz"


arch_task() {
  local name="$1"
  eval "task_$1:arm() { local arch=arm; arch_task_$1 \"\$@\"; }"
  eval "task_$1:x86() { local arch=x86; arch_task_$1 \"\$@\"; }"
  eval "task_$1() { bask_depends $1:arm; bask_depends $1:x86; }"
}


set_current_toolchain() {
  local arch="$1"

  TOOLCHAIN_ROOT="$PWD/toolchain/$arch"
  TOOLCHAIN_CC="$TOOLCHAIN_ROOT/bin/clang"
  TOOLCHAIN_CXX="$TOOLCHAIN_ROOT/bin/clang++"
  TOOLCHAIN_TRIPLE="$arch-linux-androideabi"
}


set_current_abi() {
  local arch="$1"

  case "$arch" in
  arm) ABI=armeabi-v7a ;;
  x86) ABI=x86 ;;
  esac
}


task_default() {
  echo "Run 'bask everything' for a full build, or bask -l to list individual targets."
  false
}


arch_task_toolchain() {
  rm -rf toolchain/$arch
  bask_run "$NDK/build/tools/make_standalone_toolchain.py" \
    --stl libc++ --api 23 --arch $arch --install-dir toolchain/$arch
}

arch_task toolchain


task_boost:download() {
  mkdir -p boost-android
  rm -f boost-android/boost.tgz
  aria2c -o boost-android/boost.tgz "$BOOST_URL"
}


task_boost:extract() {
  rm -rf boost-android/boost
  mkdir boost-android/boost
  tar -C boost-android/boost --strip 1 -xf boost-android/boost.tgz
}


task_boost:bootstrap() {
  cd boost-android/boost
  ./bootstrap.sh --with-toolset=clang
  cd ../..
}


task_boost:config() {
  rm boost-android/boost/toolchains.jam

  for arch in arm x86; do
    set_current_toolchain $arch
    cat >> boost-android/boost/toolchains.jam <<EOF
  using clang : ${arch}droid : $TOOLCHAIN_CXX :
    <cxxflags>-stdlib=libc++
    <cxxflags>-I$TOOLCHAIN_ROOT/include/c++/v1
    # Please, don't ask...
    <cxxflags>-D_LIBCPP_ABI_VERSION=ndk1 ;
EOF
  done
}


arch_task_boost:build() {
  [ -f boost-android/boost/toolchains.jam ] || bask_depends boost:config

  cd boost-android/boost
  ./b2 -j2 --user-config=toolchains.jam --stagedir=$arch/stage --build-dir=$arch/build \
       --with-filesystem --with-iostreams --with-program_options --with-serialization \
       --with-system link=static runtime-link=static toolset=clang-${arch}droid \
       target-os=linux variant=release
  cd ../..
}

arch_task boost:build


task_boost:setup() {
  bask_depends boost:download
  bask_depends boost:extract
  bask_depends boost:bootstrap
}


task_boost() {
  bask_depends boost:setup
  bask_depends boost:build
}


arch_task_boost:clean() {
  rm -rf boost-android/boost/$arch
}

arch_task boost:clean


task_libmagic:autoreconf() {
  cd libmagic-android/file
  autoreconf -i
  cd ../..
}


arch_task_libmagic:configure() {
  [ -f libmagic-android/file/configure ] || bask_depends libmagic:autoreconf
  set_current_toolchain $arch

  mkdir -p libmagic-android/$arch
  cd libmagic-android/$arch

  ../file/configure --enable-zlib --enable-static --disable-shared \
                    --host="$TOOLCHAIN_TRIPLE" CC="$TOOLCHAIN_CC"
  cd ../..
}

arch_task libmagic:configure


arch_task_libmagic:build() {
  cd libmagic-android/$arch/src
  make magic.h libmagic.la
  cp .libs/libmagic.a .
  cd ../../..
}

arch_task libmagic:build


arch_task_libmagic() {
  bask_depends libmagic:configure:$arch
  bask_depends libmagic:build:$arch
}

arch_task libmagic


arch_task_libmagic:clean() {
  rm -rf libmagic-android/$arch
}

arch_task libmagic:clean


arch_task_tools() {
  set_current_abi $arch

  if [ "$1" == "--verbose" ]; then
    local args="V=1"
  fi

  ndk-build -C fs/jni APP_ABI=$ABI $args
  rm -rf fs/build/$ABI
  cp -r fs/libs/$ABI fs/build/$ABI
}

arch_task tools


arch_task_tools:clean() {
  set_current_abi $arch

  rm -rf fs/build/$ABI fs/libs/$ABI fs/obj/local/$ABI
}

arch_task tools:clean


task_app() {
  cd app
  flutter build apk "$@"
  cd ..
}


task_app:install:debug() {
  adb install -r app/build/app/outputs/apk/app-debug.apk
}


task_app:install:release() {
  adb install -r app/build/app/outputs/apk/app-release.apk
}


task_app:run() {
  cd app
  flutter run "$@"
  cd ..
}


task_app:clean() {
  rm -rf app/build app/android/app/build
}


task_everything() {
  bask_depends toolchain
  bask_depends boost
  bask_depends libmagic
  bask_depends tools
  bask_depends app
}


# From the old build.py build script
# liblzma was too slow to be useful when I tested it...
# @arch_task('liblzma:configure')
# def liblzma_configure(arch):
#     target_dir = setup_target_dir('liblzma-android', arch, clean=True)
#     toolchain = toolchain_info(arch)

#     run([ap('liblzma-android/xz/autogen.sh')], cwd='liblzma-android/xz')
#     run([ap('liblzma-android/xz/configure'), '--enable-static', '--disable-shared',
#          f'--host={toolchain.triple}', f'CC={toolchain.cc}'], cwd=target_dir)
#     delete('liblzma-android/xz/m4/extern-inline.m4')


# @arch_task('liblzma:build')
# def liblzma_build(arch):
#     target_dir = setup_target_dir('liblzma-android', arch)

#     run(['make','liblzma.la'], cwd=f'{target_dir}/src/liblzma')
#     copy(f'{target_dir}/src/liblzma/.libs/liblzma.a', f'{target_dir}/src')
