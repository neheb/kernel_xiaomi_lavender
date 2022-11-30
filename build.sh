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
chat_id="-1001340890952"

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
# Build defconfig
#
DEFCONFIG="lavender-perf_defconfig"

if [ $SEND ]; then
    curl -s -X POST https://api.telegram.org/bot"${1}"/sendMessage \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d chat_id="$chat_id" \
        -d text="<b>• Build For Lavender started •</b>"
fi

export CROSS_COMPILE=$(pwd)/../gcc-arm64/bin/aarch64-elf-
export CROSS_COMPILE_ARM32=$(pwd)/../gcc-arm/bin/arm-eabi-

export ARCH=arm64 && export SUBARCH=arm64

make O=out ARCH=arm64 $DEFCONFIG
make -j$CPU O=out

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
fi
