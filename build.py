#!/usr/bin/env python36
from tinymk import *

import os, shutil, tarfile, textwrap
from collections import namedtuple
from os.path import abspath as ap
from shutil import copy2 as copy


ToolchainInfo = namedtuple('ToolchainInfo', ['root', 'cc', 'cxx', 'triple'])


os.chdir(os.path.dirname(__file__))


NDK_BUILD = shutil.which('ndk-build')
if NDK_BUILD is None:
    raise Exception('ndk-build is not installed')

NDK = os.path.dirname(NDK_BUILD)


def arch_task(name=None):
    def inner(func):
        nonlocal name
        name = name or func.__name__

        @task(f'{name}:for')
        def arch_generic(arch):
            func(arch)

        @task(f'{name}:arm')
        def arch_arm():
            qinvoke(f'{name}:for', 'arm')

        @task(f'{name}:x86')
        def arch_arm():
            qinvoke(f'{name}:for', 'x86')

        @task(name)
        def arch_all():
            invoke(f'{name}:arm')
            invoke(f'{name}:x86')

    return inner


def delete(path):
    if os.path.exists(path):
        if os.path.isdir(path):
            shutil.rmtree(path)
        else:
            os.remove(path)


def setup_target_dir(root, arch, *, clean=False, mkdir=True):
    target_dir = f'{root}/{arch}'

    if clean:
        delete(target_dir)
    if mkdir:
        os.makedirs(target_dir, exist_ok=True)

    return target_dir


def toolchain_info(arch):
    root = ap(f'toolchain/{arch}')
    return ToolchainInfo(root=root,
                         cc=f'{root}/bin/clang',
                         cxx=f'{root}/bin/clang++',
                         triple=f'{arch}-linux-androideabi')


@arch_task()
def toolchain(arch):
    target_dir = setup_target_dir('toolchain', arch, clean=True)

    run([f'{NDK}/build/tools/make_standalone_toolchain.py', '--unified-headers',
         '--stl', 'libc++', '--api', '24', '--arch', arch, '--install-dir', target_dir])


@task('boost:download')
def boost_download():
    run(['curl', '-Lo', 'boost-android/boost.tgz',
         'https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz'])


@task('boost:extract')
def boost_extract():
    print('NOTE: This might take a while...')

    delete('boost-android/boost')
    with tarfile.open('boost-android/boost.tgz', mode='r:gz') as boost:
        boost.extractall('boost-android')
    os.rename('boost-android/boost_1_64_0', 'boost-android/boost')


@task('boost:bootstrap')
def boost_bootstrap():
    run([ap('boost-android/boost/bootstrap.sh'), '--with-toolset=clang'],
         cwd='boost-android/boost')


@task('boost:config')
def boost_config():
    toolchain_arm = toolchain_info('arm')
    toolchain_x86 = toolchain_info('x86')

    with open('boost-android/boost/toolchains.jam', 'w') as toolchain:
        toolchain.write(textwrap.dedent(f'''
        using clang : armdroid : {toolchain_arm.cxx} :
            <cxxflags>-stdlib=libc++
            <cxxflags>-I{toolchain_arm.root}/include/c++/4.9.x ;

        using clang : x86droid : {toolchain_x86.cxx} :
            <cxxflags>-stdlib=libc++
            <cxxflags>-I{toolchain_x86.root}/include/c++/4.9.x ;
        ''')[1:])


@task('boost:setup')
def boost_setup():
    invoke('boost:download')
    invoke('boost:extract')
    invoke('boost:bootstrap')
    invoke('boost:config')


@arch_task('boost:build')
def boost_build(arch):
    run([ap('boost-android/boost/b2'), '-j2', '--user-config=toolchains.jam',
         f'--stagedir={arch}/stage', f'--build-dir={arch}/build',
         '--without-context', '--without-fiber', '--without-coroutine',
         '--without-coroutine2', '--without-python',
         'variant=release', f'toolset=clang-{arch}droid', 'threading=multi',
         'threadapi=pthread', 'link=static', 'runtime-link=static', 'target-os=linux'],
        cwd='boost-android/boost')


@arch_task('libmagic:configure')
def libmagic_configure(arch):
    target_dir = setup_target_dir('libmagic-android', arch, clean=True)
    toolchain = toolchain_info(arch)

    run(['autoreconf', '-i'], cwd='libmagic-android/file')
    run([ap('libmagic-android/file/configure'), '--enable-zlib', '--enable-static',
         '--disable-shared', f'--host={toolchain.triple}', f'CC={toolchain.cc}'],
        cwd=target_dir)


@arch_task('libmagic:build')
def libmagic_build(arch):
    target_dir = setup_target_dir('libmagic-android', arch)

    run(['make', 'magic.h', 'libmagic.la'], cwd=f'{target_dir}/src')
    copy(f'{target_dir}/src/.libs/libmagic.a', f'{target_dir}/src')


@arch_task()
def libmagic(arch):
    invoke(f'libmagic:configure:{arch}')
    invoke(f'libmagic:build:{arch}')


ABI_MAP = {
    'arm': 'armeabi-v7a',
    'x86': 'x86',
}


@arch_task()
def tools(arch):
    abi = ABI_MAP[arch]
    target_dir = setup_target_dir('fs/build', arch, clean=True, mkdir=False)
    run([NDK_BUILD, '-C', 'fs/jni', f'APP_ABI={abi}'],)
    shutil.copytree(f'fs/libs/{abi}', target_dir)


@task()
def app(release=False):
    run(['flutter', 'build', 'apk', '--release' if release else '--debug'], cwd='app')


@task('app:install')
def app_install(release=False):
    run(['adb', 'install', '-r',
         f'app/build/app/outputs/apk/app-{"release" if release else "debug"}.apk'])


@task('app:run')
def app_run(release=False):
    run(['flutter', 'run', '--release' if release else '--debug'], cwd='app')


@task('app:clean')
def app_clean():
    delete('app/build')
    delete('app/android/app/build')


@task()
def all():
    invoke('toolchain')
    invoke('libmagic')
    invoke('boost')
    invoke('tools')
    invoke('app', release=True)


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


if __name__ == '__main__':
    main()
