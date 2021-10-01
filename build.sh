#!/bin/bash

THIS_FILE=$0
BOOST_VERSION=$1
TARGET_OS=$2
IS_BUILD=$3

ANDROID_NDK=~/Library/Android/sdk/ndk/23.0.7599858
ANDROID_BUILDTOOLS=${ANDROID_NDK}/toolchains/llvm/prebuilt/darwin-x86_64/bin

BOOST_VERSION_US=${BOOST_VERSION//./_}
BOOST_BUILD_LIBRARIES="atomic,chrono,date_time,regex,timer,thread,filesystem,system"

BOOST_FILE="boost_${BOOST_VERSION_US}.tar.bz2"
BOOST_EXTRACT_DIR="boost_${BOOST_VERSION_US}"

BOOST_DIR="src.${BOOST_VERSION}"

LIBS_IOS_DIR="libs.ios.${BOOST_VERSION}"
LIBS_ANDROID_DIR="libs.android.${BOOST_VERSION}"

function usage()
{
  echo "$0 x.y.z (android|ios|all) [build]"
} 

function build_ios()
{
  echo "build_ios"
 
  if [ -d ${LIBS_IOS_DIR} ]; then
    rm -R ${LIBS_IOS_DIR}
  fi

  if [ -e "${LIBS_IOS_DIR}.tar.bz2" ]; then
    rm "${LIBS_IOS_DIR}.tar.bz2"
  fi

  CWD=$(cd $(dirname $0); pwd)

  IOS_BUILD_DIR=${CWD}/build/ios

  if [ -d ${IOS_BUILD_DIR} ]; then
    rm -R ${IOS_BUILD_DIR}
  fi

  cd ${BOOST_DIR}

  XCODE_DIR=`xcode-select --print-path`

  IOS_SDK_VERSION=`xcodebuild -showsdks | grep iphoneos | egrep "[[:digit:]]+\.[[:digit:]]+" -o | tail -1`
  SDK_INCLUDE="${XCODE_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/usr/include"
  CFLAGS="-DBOOST_AC_USE_PTHREADS -DBOOST_SP_USE_PTHREADS -g -DNDEBUG \
      -std=c++14 -stdlib=libc++ -fvisibility=default \
      -fembed-bitcode -miphoneos-version-min=10.0"


  # jamファイルを定義（clangではなくclang++に変更するため）
  cat > ./tools/build/src/user-config.jam <<EOF
using darwin : iphone
: ${XCODE_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
: <striper> <root>${XCODE_DIR}/Platforms/iPhoneOS.platform/Developer
: <architecture>arm <target-os>iphone
;
EOF

  ./bootstrap.sh --with-libraries=${BOOST_BUILD_LIBRARIES}

  ./b2 \
    -j 8 \
    toolset=clang \
    cflags="${CFLAGS} -arch i386 -arch x86_64" \
    --build-dir=${IOS_BUILD_DIR}/iphonesim-build \
    --stagedir=${IOS_BUILD_DIR}/iphonesim-build/stage \
    architecture=x86 \
    target-os=iphone \
    link=static \
    threading=multi \
    define=_LITTLE_ENDIAN \
    stage


  ./b2 \
    -j 8 \
    toolset=darwin \
    cxxflags="${CFLAGS} -arch armv7 -arch armv7s -arch arm64" \
    --build-dir=${IOS_BUILD_DIR}/iphone-build \
    --stagedir=${IOS_BUILD_DIR}/iphone-build/stage \
    architecture=arm \
    target-os=iphone \
    macosx-version=iphone-${IOS_SDK_VERSION} \
    link=static \
    threading=multi \
    define=_LITTLE_ENDIAN \
    include=${SDK_INCLUDE} \
    stage

  cd ..

  mkdir ${LIBS_IOS_DIR}

  for file in `\find ${IOS_BUILD_DIR}/iphone-build/stage/lib -maxdepth 1 -type f`; do 
      echo lipo -> ${file}
      lipo -create \
          ${IOS_BUILD_DIR}/iphone-build/stage/lib/${file##*/} \
          ${IOS_BUILD_DIR}/iphonesim-build/stage/lib/${file##*/} \
          -output ./${LIBS_IOS_DIR}/${file##*/}
  done

  tar cvfj ${LIBS_IOS_DIR}.tar.bz2 ${LIBS_IOS_DIR}
}

function build_android()
{
  echo "build_android"

  if [ -d ${LIBS_ANDROID_DIR} ]; then
    rm -R ${LIBS_ANDROID_DIR}
  fi

  if [ -e "${LIBS_ANDROID_DIR}.tar.bz2" ]; then
    rm "${LIBS_ANDROID_DIR}.tar.bz2"
  fi

  CWD=$(cd $(dirname $0); pwd)

  ANDROID_BUILD_DIR=${CWD}/android-build

  if [ -d ${ANDROID_BUILD_DIR} ]; then
    rm -R ${ANDROID_BUILD_DIR}
  fi

  pushd ${BOOST_DIR}

  cat << EOS > tools/build/src/user-config.jam
import os ;

using clang : armv7
:
${ANDROID_BUILDTOOLS}/armv7a-linux-androideabi21-clang++
:
<ranlib>${ANDROID_BUILDTOOLS}/llvm-ranlib
<archiver>${ANDROID_BUILDTOOLS}/llvm-ar
<compileflags>-fPIC
;

using clang : arm64
:
${ANDROID_BUILDTOOLS}/aarch64-linux-android21-clang++
:
<ranlib>${ANDROID_BUILDTOOLS}/llvm-ranlib
<archiver>${ANDROID_BUILDTOOLS}/llvm-ar
<compileflags>-fPIC
;

using clang : x86
:
${ANDROID_BUILDTOOLS}/i686-linux-android21-clang++
:
<ranlib>${ANDROID_BUILDTOOLS}/llvm-ranlib
<archiver>${ANDROID_BUILDTOOLS}/llvm-ar
<compileflags>-fPIC
;

using clang : x86_64
:
${ANDROID_BUILDTOOLS}/x86_64-linux-android21-clang++
:
<ranlib>${ANDROID_BUILDTOOLS}/llvm-ranlib
<archiver>${ANDROID_BUILDTOOLS}/llvm-ar
<compileflags>-fPIC
;
EOS

  ./bootstrap.sh --with-libraries=${BOOST_BUILD_LIBRARIES}

  ./b2 \
  -j 8 \
  toolset=clang-armv7 \
  --build-dir=${ANDROID_BUILD_DIR}/armeabi-v7a \
  --stagedir=${ANDROID_BUILD_DIR}/armeabi-v7a/stage \
  target-os=android \
  link=static \
  threading=multi \
  threadapi=pthread \
  stage

  ./b2 \
  -j 8 \
  toolset=clang-arm64 \
  --build-dir=${ANDROID_BUILD_DIR}/arm64-v8a \
  --stagedir=${ANDROID_BUILD_DIR}/arm64-v8a/stage \
  target-os=android \
  link=static \
  threading=multi \
  threadapi=pthread \
  stage

  ./b2 \
  -j 8 \
  toolset=clang-x86 \
  --build-dir=${ANDROID_BUILD_DIR}/x86 \
  --stagedir=${ANDROID_BUILD_DIR}/x86/stage \
  target-os=android \
  link=static \
  threading=multi \
  threadapi=pthread \
  stage

  ./b2 \
  -j 8 \
  toolset=clang-x86_64 \
  --build-dir=${ANDROID_BUILD_DIR}/x86_64 \
  --stagedir=${ANDROID_BUILD_DIR}/x86_64/stage \
  target-os=android \
  link=static \
  threading=multi \
  threadapi=pthread \
  stage

  popd


  mkdir ${LIBS_ANDROID_DIR}
  mkdir ${LIBS_ANDROID_DIR}/armeabi-v7a
  mkdir ${LIBS_ANDROID_DIR}/arm64-v8a
  mkdir ${LIBS_ANDROID_DIR}/x86_64
  mkdir ${LIBS_ANDROID_DIR}/x86

  cp ${ANDROID_BUILD_DIR}/armeabi-v7a/stage/lib/*.a  ${LIBS_ANDROID_DIR}/armeabi-v7a
  cp ${ANDROID_BUILD_DIR}/arm64-v8a/stage/lib/*.a    ${LIBS_ANDROID_DIR}/arm64-v8a
  cp ${ANDROID_BUILD_DIR}/x86_64/stage/lib/*.a       ${LIBS_ANDROID_DIR}/x86_64
  cp ${ANDROID_BUILD_DIR}/x86/stage/lib/*            ${LIBS_ANDROID_DIR}/x86

  tar cvfj ${LIBS_ANDROID_DIR}.tar.bz2 ${LIBS_ANDROID_DIR}
} 

function delete_build()
{
  if [ -d "build" ]; then
    rm -R "build"
  fi
}

function extract_ios()
{
  echo "extract_ios"

  if [ ! -d ${LIBS_IOS_DIR} ]; then
    tar xvfj "${LIBS_IOS_DIR}.tar.bz2"
  fi
} 

function extract_android()
{
  echo "extract_android"

  if [ ! -d ${LIBS_ANDROID_DIR} ]; then
    tar xvfj "${LIBS_ANDROID_DIR}.tar.bz2"
  fi
} 


##############################################################################
# メイン処理
#
# ファイル・フォルダ構成
#   build.sh        ... このファイル
#   ${LIBS_ANDROID_DIR}.tar.gz ... android用生成ライブラリ
#   ${LIBS_IOS_DIR}.tar.gz     ... ios用生成ライブラリ
#
#   ${BOOST_DIR}/   ... boost ライブラリフォルダ
#                       インクルードパスはココに設定する
#   build/          ... ビルド作業用ディレクトリ
#   ${LIBS_ANDROID_DIR}/   ... android用のビルド済みライブラリ
#                       androidのライブラリパスはココを指定する
#   ${LIBS_IOS_DIR}/       ... ios用のビルド済みライブラリ
#                       iosのライブラリパスはココを指定する
#
##############################################################################

if [ ! -f ${BOOST_FILE} ]; then
  curl -L https://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/${BOOST_FILE} > ${BOOST_FILE}
fi

if [ "${IS_BUILD}" = "build" ]; then
  if [ -d ${BOOST_EXTRACT_DIR} ]; then
    rm -R ${BOOST_EXTRACT_DIR}
  fi
  if [ -d ${BOOST_DIR} ]; then
   rm -r ${BOOST_DIR}
  fi
fi

if [ ! -d ${BOOST_DIR} ]; then
  tar xvfj ${BOOST_FILE}
  mv ${BOOST_EXTRACT_DIR} ${BOOST_DIR}

  # error: unknown argument: '-fcoalesce-templates' の回避
  # https://github.com/zcash/zcash/issues/4333
  # https://trac.macports.org/ticket/60287
  cp darwin.jam ${BOOST_DIR}/tools/build/src/tools/darwin.jam
fi

if [ "${TARGET_OS}" = "ios" ]; then
  if [ "${IS_BUILD}" = "build" ]; then
    delete_build
    build_ios
  elif [ "${IS_BUILD}" = "" ]; then
    extract_ios
  else
    usage
  fi
elif [ "${TARGET_OS}" = "android" ]; then
  if [ "${IS_BUILD}" = "build" ]; then
    delete_build
    build_android
  elif [ "${IS_BUILD}" = "" ]; then
    extract_android
  else
    usage
  fi

elif [ "${TARGET_OS}" = "all" ]; then
  if [ "${IS_BUILD}" = "build" ]; then
    delete_build
    build_android
    build_ios
  else
    usage
  fi
else
  usage
fi
