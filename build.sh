#!/bin/bash

#
# Color UI
#
grn=$(tput setaf 2)             # green
yellow=$(tput setaf 3)          # yellow
bldgrn=${txtbld}$(tput setaf 2) # bold green
red=$(tput setaf 1)             # red
txtbld=$(tput bold)             # bold
bldblu=${txtbld}$(tput setaf 4) # bold blue
blu=$(tput setaf 4)             # blue
txtrst=$(tput sgr0)             # reset
blink=$(tput blink)             # blink

COMPILER_TYPE="Proton"

#
# Clean stuff
#
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    rm -rf "out/arch/arm64/boot/Image.gz-dtb"
fi

#
# 1) Check for push key
# 2) Check internet connect
#
if [ ${1} ]; then
    #
    #  Test internet connection
    #
    wget -q --spider http://google.com

    if [ $? -eq 0 ]; then
        SEND=true
        echo "Online"
    else
        SEND=false
        echo "Offline"
    fi
fi

#
# My grp chat id
#
chat_id="-1001441002138"

#
# build from
#
export KBUILD_BUILD_USER="Peppe289"
export KBUILD_BUILD_HOST="RaveRules"

#
# start build date
#
DATE=$(date +"%Y%m%d-%H%M")

#
# Compiler type
#
TOOLCHAIN_DIRECTORY="../toolchain"
TOOLCHAIN_ARM32="gcc-arm"
TOOLCHAIN_ARM64="gcc-arm64"

#
# Build defconfig
#
DEFCONFIG="lavender-perf_defconfig"

#
# Check for compiler
#
if [ ! -d "$TOOLCHAIN_DIRECTORY" ]; then
    mkdir $TOOLCHAIN_DIRECTORY
fi

if [ $COMPILER_TYPE == "GCC" ]; then

    if [ -d "$TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM32" ]; then
        echo -e "${bldgrn}"
        echo "Toolchain arm32 ready"
        echo -e "${txtrst}"
    else
        echo -e "${red}"
        echo "Need to download toolchain arm32"
        echo -e "${txtrst}"
        git clone --depth=1 https://github.com/Rave-Project/arm-linux-androideabi-4.9.git $TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM32
    fi

    if [ -d "$TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM64" ]; then
        echo -e "${bldgrn}"
        echo "Toolchain arm64 ready"
        echo -e "${txtrst}"
    else
        echo -e "${red}"
        echo "Need to download toolchain arm64"
        echo -e "${txtrst}"
        git clone --depth=1 https://github.com/Rave-Project/aarch64-linux-android-4.9.git $TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM64
    fi
else
    if [ -d "$TOOLCHAIN_DIRECTORY/clang" ]; then
        echo -e "${bldgrn}"
        echo "Proton-Clang is ready"
        echo -e "${txtrst}"
    else
        echo -e "${red}"
        echo "Need to download Proton-Clang"
        echo -e "${txtrst}"
        git clone --depth=1 https://github.com/Peppe289/proton-clang.git $TOOLCHAIN_DIRECTORY/clang
    fi
fi

if [ $SEND ]; then
    curl -s -X POST https://api.telegram.org/bot"${1}"/sendMessage \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d chat_id="$chat_id" \
        -d text="<b>• Build For Lavender started •</b>"
fi

if [ $COMPILER_TYPE == "GCC" ]; then
    #
    # Build start with GCC
    #
    export CROSS_COMPILE=$(pwd)/$TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM64/bin/aarch64-linux-androidkernel-
    export CROSS_COMPILE_ARM32=$(pwd)/$TOOLCHAIN_DIRECTORY/$TOOLCHAIN_ARM32/bin/arm-linux-androideabi-

    export ARCH=arm64
    export SUBARCH=arm64

    make O=out $DEFCONFIG
    make O=out -j$(nproc --all)
else
    #
    # Build start with Proton Clang
    #
    PATH="$(pwd)/$TOOLCHAIN_DIRECTORY/clang/bin:${PATH}"
    make O=out ARCH=arm64 $DEFCONFIG
    make -j$(nproc --all) O=out \
				ARCH=arm64 \
				CC=clang \
				AR=llvm-ar \
				NM=llvm-nm \
				OBJCOPY=llvm-objcopy \
				OBJDUMP=llvm-objdump \
				STRIP=llvm-strip \
				CROSS_COMPILE=aarch64-linux-gnu- \
				CROSS_COMPILE_ARM32=arm-linux-gnueabi-
fi

if [ ! -f "out/arch/arm64/boot/Image.gz-dtb" ]; then
    echo -e "${red}"
    echo "Error"
    echo -e "${txtrst}"
    if [ $SEND ]; then
        curl -s -X POST https://api.telegram.org/bot"${1}"/sendMessage \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d chat_id="$chat_id" \
            -d text="<b>Error in build</b>"
    fi
    exit
fi

git clone --depth=1 https://github.com/Peppe289/AnyKernel3.git -b lavender anykernel
cp out/arch/arm64/boot/Image.gz-dtb anykernel
cd anykernel
zip -r9 ../Rave-$DATE.zip * -x .git README.md *placeholder
cd ..
rm -rf anykernel
echo "kernel is: $(pwd)/Rave-$DATE.zip"

if [ $SEND ]; then
    curl -F chat_id="$chat_id" \
        -F caption="-Keep Rave" \
        -F document=@"Rave-$DATE.zip" \
        https://api.telegram.org/bot"${1}"/sendDocument

    curl -s -X POST "https://api.telegram.org/bot"${1}"/sendMessage" \
	    -d chat_id="$chat_id" \
	    -d "disable_web_page_preview=true" \
	    -d "parse_mode=html" \
	    -d text="<b>Branch</b>: <code>$(git rev-parse --abbrev-ref HEAD)</code>%0A<b>Last Commit</b>: <code>$(git log --pretty=format:'%s' -1)</code>%0A<b>Kernel Version</b>: <code>$(make kernelversion)</code>"
fi
