#!/bin/bash
ARMBIAN_REPO="https://github.com/armbian/build"
ARMBIAN_TAG="remotes/origin/v20.11"
OCTOPI_REPO="https://github.com/guysoft/OctoPi"
MJPGSTREAMER_REPO="https://github.com/jacksonliam/mjpg-streamer.git"
OCTOPI_TAG="0.17.0"
AR_DIR=armbian_build
UP_DIR=$AR_DIR/userpatches
OV_DIR=$UP_DIR/overlay
RT_DIR=/tmp/overlay
VAGRANT_DIR=armbian_build/config/templates
#VAGRANT_BOX="ubuntu/bionic64"
VAGRANT_BOX="ubuntu/focal64"

BOS=$(uname -s)


set -e 
echo "OptoCitrico script => $1 [runining on $BOS]"

if [ $# -eq 0 ] ; then
   echo "Usage:"
   echo " $0 box              : install ubuntu box for builing"
   echo " $0 drop             : destroy build virtual manchine"
   echo " $0 clean            : delete all build resources (assets,box,vm)"
   echo " $0 assets           : download build assets"
   echo " $0 build <board>    : Build image for board <board> uisng vagrant"
   echo " $0 dbuild <board>   : Build image for board <board> using docker"
   echo " $0 native <board>   : Build image in native supported Ubuntu"
   echo " $0 release <version>: Create a git release (use for maintenance)"
   exit 1
fi

if [ "$BOS" != "Darwin" ] && [ "$BOS" != "Linux" ] ; then
    echo "$BOS not supported."
    exit 2
fi

SEDI="sed -i bup -e"
[ "$BOS" == "Linux" ] && SEDI="sed -i"

function clean_vm() {
    if [ -d $VAGRANT_DIR ]; then
        pushd $VAGRANT_DIR
        echo "Cleaning virtual machine...."
        vagrant destroy
        popd
    else
        echo "$VAGRAT_DIR do not exist. nothing to clean"
    fi
}

function build_start() {
    local board=$1
    local build_mode=$2
    local enable_cache=$3

    echo "Setting up build environment for $board..."
    cp -v -R -p opi_source/src/modules/octopi/filesystem $OV_DIR        
    cp -v -p    boards/manifest  $OV_DIR
    cp -v -p    boards/common.sh $OV_DIR
    cp -v -R -p boards/common_fs $OV_DIR
    cp -v -R -p boards/$board    $OV_DIR
    dest_conf="$UP_DIR/config-vagrant-guest.conf"
    if [ -z $build_mode ] ; then
        dest_conf="$UP_DIR/config-vagrant-guest.conf"
    elif [ "$build_mode" == "docker" ] ; then
        dest_conf="$UP_DIR/config-dbuild.conf"
    else
        dest_conf="$UP_DIR/config-native.conf"
    fi
    cp -v    -p boards/$board/config.conf $dest_conf

    # errase clean level if enable cache
    if [[ ! -z $enable_cache ]] ; then
        echo "Setting max cache!"
        ${SEDI} "s/^CLEAN_LEVEL=\".*\"/CLEAN_LEVEL=\"\"/" $dest_conf
        echo 
    fi

    source boards/manifest
    # generate customize script
cat > $UP_DIR/customize-image.sh <<EOF
#! /bin/bash
set -x
set -e
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive
source $RT_DIR/manifest
source $RT_DIR/common.sh
echo_green "Starting customization script...."
if [[ ! -z "$BASE_PACKS" ]] ; then
    apt-get -y update
    apt-get -y install $BASE_PACKS
fi

customize $board $RT_DIR

if [ -f $RT_DIR/$board/extra.sh ] ; then
 echo_green "Starting extra customization for $board..."
 #chmod +x $RT_DIR/$board/extra.sh
 source $RT_DIR/$board/extra.sh
fi

customize_clean
echo_green "Done!"
EOF
    # Add additional pacakages to build
#source boards/manifest
cat > $UP_DIR/lib.config <<EOF
PACKAGE_LIST_ADDITIONAL="\$PACKAGE_LIST_ADDITIONAL ${BASE_UTILS} ${BASE_PACKS}"
EOF

    chmod +x $UP_DIR/customize-image.sh
  
    echo "Launching build mode=[$build_mode]..."
    if [ -z $build_mode ] ; then
        pushd $VAGRANT_DIR
        vagrant halt
        vagrant up
        vagrant ssh-config
        vagrant ssh -c "cd armbian ; \
                        sudo git fetch && sudo git fetch --tags ; \
                        if [ \"\$(git tag --points-at HEAD)\" != \"$ARMBIAN_TAG\" ] ; then \
                            sudo git checkout $ARMBIAN_TAG ; \
                        fi ; \
                        sudo ./compile.sh vagrant-guest"
        vagrant halt
        popd
    elif [ "$build_mode" == "docker" ] ; then 
        pushd $AR_DIR
        ./compile.sh docker dbuild
        popd
    else
        echo "Native build not ready yet!"
        exit 1
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
    git clone $ARMBIAN_REPO $AR_DIR
    pushd $AR_DIR
    git fetch && git fetch --tags
    git checkout $ARMBIAN_TAG
    popd
    # fix vm memory + Drive
    $SEDI 's/#vb\.memory = "8192"/vb\.memory="6144"/g' $VAGRANT_DIR/Vagrantfile
    $SEDI 's/#vb\.cpus = "4"/vb\.cpus = "4"/g' $VAGRANT_DIR/Vagrantfile
    $SEDI 's/disksize\.size = "40GB"/disksize\.size = "45GB"/g' $VAGRANT_DIR/Vagrantfile

    # clone octopi repo
    git clone $OCTOPI_REPO opi_source
    pushd opi_source
    git fetch && git fetch --tags
    git checkout $OCTOPI_TAG
    popd
    mkdir -p $OV_DIR
    pushd $OV_DIR
    git clone --depth 1 $MJPGSTREAMER_REPO mjpg-streamer
    #git clone --depth 1 $KLIPPER_REPO klipper
    popd
    exit $?
fi

# Build 
if [ "$1" == "build" ] || [ "$1" == "native" ] || [ "$1" == "dbuild" ] ; then

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
            build_start $2 "" $3
        elif [ "$1" == "dbuild" ] ; then
            build_start $2 "docker" $3
        else
            build_start $2 "native" $3
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

    if [ -z $2 ] ; then
        echo "Release require version as parameter."
        exit 1
    fi
    # Test if tag is in manifest
    echo "Fetching the release form releases.json"
    tag=$(jq -r ".[] | select(.tag == \"$2\") | .tag" releases.json) 
    if [ "$tag" != "$2" ] ; then
        echo "$2 version not found in releases aboring"
        exit 1
    fi
    
    # Check if pending to publish
    set +e
    git status -s | egrep 'M|\?\?' > /dev/null
    if [ $? -eq 0 ] ; then
        echo "There are pending commits aborting"
        exit 1
    fi
    
    git tag | grep $2 > /dev/null
    if [ $? -eq 1 ] ; then
        echo "Tag $2 don't exists in the repository"
        printf "Do you what to create it?[y/N]"
        read -n 1 resp
        if [ "$resp" == "Y" ] || [ "$resp" == "y" ] ; then
            git tag $tag
        else
            echo ".....Aborting!"
            exit 1
        fi
    fi
    set -e
    if [ "$tag" != "$(git tag --points-at HEAD)" ] ; then
        echo "HEAD is not poiting to $tag...Aborting"
        exit 1
    fi

    echo "Version $tag found. Details:"
    rel=$(jq -r ".[] | select(.tag == \"$2\")" releases.json)
    echo $rel | jq .
    PRE_RELEASE=""
    pr=$(echo $rel | jq -r .prerelease)
    [ "$pr" == "true" ] && PRE_RELEASE="-p"

    echo "Images found:"
    imgs=$(ls $AR_DIR/output/images/*.7z)
    ls -lh $AR_DIR/output/images/*.7z
    FILE_ASSETS=""
    for img in $imgs
    do
      FILE_ASSETS="$FILE_ASSETS -a $img"
    done

    printf "Proceed with release?[N/y]"
    read -n 1 resp
    if [ "$resp" == "y" ] || [ "$resp" == "Y" ] ; then
        echo "Puhsing repository..."
        git push
        git push --tags

        echo $rel | jq -r .name > release.tmp
        echo $rel | jq -r .body[] >> release.tmp
        printf "\n##Upstream versions:\n\n" >> release.tmp
        echo " - Armbian: $(cat $AR_DIR/VERSION)" >> release.tmp
        echo " - OctoPi: $OCTOPI_TAG" >> release.tmp

        set +e
        hub release | grep $tag
        if [ $? -eq 0 ] ; then
            set -e
            echo "Release $tag is already published. Do you want to delete it?"
            read -n 1 resp
            if [ "$resp" == "y" ] || [ "$resp" == "Y" ] ; then
                echo
                echo "Deleting $tag relese."
                hub release delete $tag
            fi
        fi
        set -e
        hub release create -F release.tmp $PRE_RELEASE $FILE_ASSETS $tag
        rm release.tmp
    else
        echo
        echo "Aborting!"
        exit 1
    fi
    exit $?
fi

echo "Invalid command"
exit 1




