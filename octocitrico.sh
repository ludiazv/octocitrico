#!/bin/bash
ARMBIAN_REPO="https://github.com/armbian/build"
OCTOPI_REPO="https://github.com/guysoft/OctoPi"
OCTOPI_TAG="0.17.0"
AR_DIR=armbian_build
UP_DIR=$AR_DIR/userpatches
OV_DIR=$UP_DIR/overlay
RT_DIR=/tmp/overlay
VAGRANT_DIR=armbian_build/config/templates
VAGRANT_BOX="ubuntu/bionic64"
#VAGRANT_BOX="ubuntu/focal64"


set -e 
echo "OptoCitrico script => $1"

if [ $# -eq 0 ] ; then
   echo "Usage:"
   echo " $0 box            : install ubuntu box for builing"
   echo " $0 drop           : destroy build virtual manchine"
   echo " $0 clean          : delete all build resources"
   echo " $0 assets         : download build assets"
   echo " $0 build <board>  : Build image for board <board>"
   echo " $0 native <board> : Build image in native supported Ubuntu"
   echo " $0 release        : Create a git release (use for maintenance)"
   exit 1
fi


function clean_vm() {
    if [ -d $AR_DIR ] && [ -d $UP_DIR ]; then
        pushd $UP_DIR
        echo "Cleaning virtual machine...."
        vagrant destroy
        popd
    else
        echo "$UP_DIR do not exist. nothing to clean"
    fi
}

function build_start() {
    local board=$1
    local native=$2
    echo "Setting up build environment for $board..."
    cp -v -R -p opi_source/src/modules/octopi/filesystem $OV_DIR        
    cp -v -p    boards/manifest  $OV_DIR
    cp -v -p    boards/common.sh $OV_DIR
    cp -v -R -p boards/common_fs $OV_DIR
    cp -v -R -p boards/$board    $OV_DIR
    if [ -z $native ] ; then
        cp -v    -p boards/$board/config.conf $UP_DIR/config-vagrant-guest.conf
    else
        cp -v    -p boards/$board/config.conf $UP_DIR/config-native.conf
    fi

    # generate customize script
cat > $UP_DIR/customize-image.sh <<EOF
#! /bin/bash
set -x
#set -e
export LC_ALL=C
source $RT_DIR/manifest
source $RT_DIR/common.sh
echo_green "Starting customization script...."
customize $board $RT_DIR

if [ -f $RT_DIR/$board/extra.sh ] ; then
 echo_green "Starting extra customization for $board..."
 chmod +x $RT_DIR/$board/extra.sh
 source $RT_DIR/$board/extra.sh
fi

customize_clean
echo_green "Done!"
EOF
    # Add additional pacakages to build
source boards/manifest
cat > $UP_DIR/lib.config <<EOF
PACKAGE_LIST_ADDITIONAL="\$PACKAGE_LIST_ADDITIONAL ${BASE_PACKS}"
EOF

    chmod +x $UP_DIR/customize-image.sh

    echo "Launching..."
    if [ -z $native ] ; then
        pushd $VAGRANT_DIR
        vagrant halt
        vagrant up
        vagrant ssh-config
        vagrant ssh -c "cd armbian; sudo ./compile.sh vagrant-guest"
        vagrant halt
        popd
    else
        pushd $AR_DIR
        sudo ./compile.sh native
        popd
    fi
}


# Add vagrant box
if [ "$1" == "box" ] ; then
    # Make the Vagrant box available. This might take a while but only needs to be done once.
    vagrant --version
    if [ $? -ne 0 ] ; then
        echo "Vagrant not found. Install vagrant for compiling"
        exit 1
    fi
    echo "Setting up $VAGRANT box...."
    vagrant plugin install vagrant-disksize
    vagrant box add $VAGRANT_BOX
    vagrant box update
    exit $?
fi

if [ "$1" == "assets" ] ; then

    # clone armbian buil repository
    git clone --depth 1 $ARMBIAN_REPO armbian_build
    # clone octopi repo
    git clone $OCTOPI_REPO opi_source
    pushd opi_source
    git fetch && git fetch --tags
    git checkout $OCTOPI_TAG
    popd
    exit $?
fi

# Build 
if [ "$1" == "build" ] || [ "$1" == "native" ]; then

    if [ ! -d armbian_build ] ; then
        echo "Error:Armbian build asset not found"
        exit 1
    fi
    if [ ! -d opi_source ] ; then
        echo "Error:OctoPi asset not found"
        exit 1
    fi
    if [ $# -eq 1 ] ; then
        echo "Error: build require a board parameter"
        echo "Current supported boards:"
        ls -1d boards/*/ | grep -v common
        exit 1 
    fi

    if [ -d boards/$2 ] ; then
        mkdir -p $UP_DIR
        mkdir -p $OV_DIR
        if [ "$1" == "build" ] ; then
            build_start $2
        else
            build_start $2 "native"
        fi
        exit $?
    else
        echo "Board: $2 not supported."
        echo "Current supported boards:"
        ls -1d boards/*/ | grep -v common 
        exit 1
    fi
fi

if [ "$1" == "drop" ] ; then
   clean_vm
   exit $?
fi

if [ "$1" == "clean" ] ; then
   clean_vm
   echo "Uninstalling ubuntu box...."
   vagrant box remove $VAGRANT_BOX --all
   echo "Removing assets..."
   rm -fR armbian_build
   rm -fR opi_source
   echo "Removing ouputs...."
   rm -fR images
   exit $?
fi

if [ "$1" == "release" ] ; then
    echo "TODO automatic release"
    exit 1
fi

echo "Invalid command"
exit 1




