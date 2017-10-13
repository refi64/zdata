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


task_help() {
  echo '[:arch] can be either :arm or :x86. If not given, it will do both.'
  echo 'e.g. bask toolchain does both arm and x86, but toolchain:x86 only does x86.'
  echo
  echo -e 'bask everything\t\t\t\t Download and build everything from scratch.'
  echo -e 'bask toolchain[:arch]\t\t\t Prepares a toolchain.'
  echo -e 'bask boost:download\t\t\t Downloads Boost.'
  echo -e 'bask boost:extract\t\t\t Extracts Boost.'
  echo -e 'bask boost:bootstrap\t\t\t Bootstraps the Boost build system.'
  echo -e 'bask boost:config\t\t\t Writes Boost toolchain configuration data.'
  echo -e 'bask boost:build[:arch]\t\t\t Builds Boost.'
  echo -e 'bask boost:setup\t\t\t boost:download+boost:extract+boost:bootstrap.'
  echo -e 'bask boost:clean[:arch]\t\t\t Deletes the given Boost build.'
  echo -e 'bask libmagic:autoreconf\t\t Sets up libmagic configure scripts.'
  echo -e 'bask libmagic:configure[:arch]\t\t Configures libmagic.'
  echo -e 'bask libmagic:build[:arch]\t\t Builds libmagic.'
  echo -e 'bask libmagic\t\t\t\t libmagic:configure+libmagic:build.'
  echo -e 'bask libmagic:clean[:arch]\t\t Deletes the given libmagic build.'
  echo -e 'bask tools[:arch]\t\t\t Builds the zdata tools.'
  echo -e 'bask tools:clean\t\t\t Deletes the given zdata tools build.'
  echo -e 'bask app\t\t\t\t Builds the zdata client app in release mode.'
  echo -e 'bask app --debug\t\t\t Same as above, but in debug mode.'
  echo -e 'bask app:install:debug\t\t\t Installs the debug app apk via adb.'
  echo -e 'bask app:install:release\t\t Installs the release app apk via adb.'
  echo -e 'bask app:run\t\t\t\t Runs the app in debug via adb using flutter run.'
  echo -e 'bask app:run --release\t\t\t Runs the app in release via adb using flutter run.'
  echo -e 'bask app:clean\t\t\t\t Deletes the app build.'
}


task_default() {
  bask_depends help
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
  rm -f boost-android/boost/toolchains.jam

  for arch in arm x86; do
    set_current_toolchain $arch
    cat >> boost-android/boost/toolchains.jam <<EOF
  using clang : ${arch}droid : $TOOLCHAIN_CXX ;
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
  rm -f boost-android/boost/toolchains.jam
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
  cp -r fs/libs/$ABI fs/build/$arch
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
