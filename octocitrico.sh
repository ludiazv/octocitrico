#!/bin/bash
ARMBIAN_REPO="https://github.com/armbian/build"
ARMBIAN_VER="v23.08"
ARMBIAN_TAG="remotes/origin/v23.08"
OCTOPI_REPO="https://github.com/guysoft/OctoPi"
MJPGSTREAMER_REPO="https://github.com/jacksonliam/mjpg-streamer.git"
FFMPEG_HLS_COMMIT=c6fdbe26ef30fff817581e5ed6e078d96111248a
OCTOPI_TAG="1.0.0"
AR_DIR=armbian_build
UP_DIR=$AR_DIR/userpatches
OV_DIR=$UP_DIR/overlay
RT_DIR=/tmp/overlay

BOS=$(uname -s)


set -e 
echo "OptoCitrico script => $1 [runining on $BOS]"

if [ $# -eq 0 ] ; then
   echo "Usage:"
   echo " $0 clean            : clean docker build env"
   echo " $0 assets           : download build assets"
   #echo " $0 build <board>    : Build image for board <board> uisng vagrant"
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
    if [ -z $build_mode ] ; then
        dest_conf="$UP_DIR/config-dbuild.conf"
    else
        dest_conf="$UP_DIR/config-native.conf"
    fi
    # Copy the board config + config config common.
    cp -v    -p boards/$board/config.conf $dest_conf
    cp -v    -p boards/common.conf $UP_DIR/config-common.conf

    # errase clean level if enable cache
    if [[ ! -z $enable_cache ]] ; then
        echo "Setting max cache!"
        ${SEDI} "s/^CLEAN_LEVEL=\".*\"/CLEAN_LEVEL=\"\"/" $UP_DIR/config-common.conf
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
export CURRENT_ARCH=\$(uname -m)
source $RT_DIR/manifest
source $RT_DIR/common.sh
echo_green "Starting customization script...."
# Base packs are installed via lib variable
if [[ ! -z "$BASE_PACKS" ]] ; then
    apt-get -y update
    apt-get install --no-install-recommends --yes $BASE_PACKS $BASE_UTILS
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
# !!! This is not supported anymore
#cat > $UP_DIR/lib.config <<EOF
#PACKAGE_LIST_ADDITIONAL="\$PACKAGE_LIST_ADDITIONAL ${BASE_UTILS} ${BASE_PACKS}"
#EOF

    chmod +x $UP_DIR/customize-image.sh
  
    echo "Launching build mode=[$build_mode]..."
    if [ -z $build_mode ] ; then
        pushd $AR_DIR
        ./compile.sh dbuild
        popd
    else
        echo "Native build not ready yet!"
        exit 1
    fi
}



if [ "$1" == "assets" ] ; then

    # clone armbian buil repository
    if [ -d $AR_DIR ] ; then
       echo "$AR_DIR exists please remove the directory to download a fresh repository of armbian"
       exit 1
    fi
    git clone --depth=1 --branch=$ARMBIAN_VER $ARMBIAN_REPO $AR_DIR
    #pushd $AR_DIR
    #git fetch && git fetch --tags
    #git checkout $ARMBIAN_TAG
    #popd

    mkdir -p $OV_DIR
    source boards/manifest
    # download octoprint archive & plugins
    pushd $OV_DIR
      wget -O octoprint.tar.gz $OCTOPRINT_ARCHIVE
      
      #plugins
      mkdir -p plugins
      pushd plugins
        i=0
        touch plugins.txt
        for plug in "${OCTOPRINT_PLUGINS[@]}"
        do
            wget -O $i.zip $plug
            echo "$RT_DIR/plugins/$i.zip" >> plugins.txt
            ((i=i+1))
        done
      popd

    popd

    # get ffmpeg archive
    pushd $OV_DIR
      wget https://api.github.com/repos/FFmpeg/FFmpeg/tarball/${FFMPEG_COMMIT} -O ffmpeg.tar.gz
    popd

    # clone octopi repo
    [ ! -d opi_source ] && git clone $OCTOPI_REPO opi_source
    pushd opi_source
    git fetch && git fetch --tags
    git checkout $OCTOPI_TAG
    popd
    pushd $OV_DIR
    git clone --depth 1 $MJPGSTREAMER_REPO mjpg-streamer
    #git clone --depth 1 $KLIPPER_REPO klipper
    popd

    # Extract octoprint version
    echo $OCTOPRINT_VERSION > opi_source/octoprint_version.txt

    # download extra repos
    pushd $OV_DIR
    wget $MARLIN2_ARCHIVE -O marlin2.zip
    wget $MARLIN1_ARCHIVE -O marlin1.zip
    popd
    exit $?
fi

# Build 
if [ "$1" == "build" ] || [ "$1" == "native" ] ; then

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


if [ "$1" == "clean" ] ; then
    set +e
    echo "Purge docker..."
    pushd $AR_DIR
    #docker ps -a | awk '{print $1}' | xargs docker stop 
    docker container ls -a | grep armbian | awk '{print $1}' | xargs docker container rm 
    docker image ls | grep armbian | awk '{print $3}' | xargs docker image rm 
    docker volume ls | grep armbian-c | awk '{print $2}' | xargs docker volume rm
    popd
    echo "Removing assets..."
    sudo rm -fR armbian_build
    rm -fR opi_source
    #echo "Removing ouputs...."
    #rm -fR images
    set -e
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
    imgs=$(ls $AR_DIR/output/images/*.img.xz)
    ls -lh $AR_DIR/output/images/*.img.xz
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
        printf "\n\n" >> release.tmp
        echo $rel | jq -r .body[] >> release.tmp
        printf "\n## Upstream versions:\n\n" >> release.tmp
        echo " - Armbian: $(cat $AR_DIR/VERSION)" >> release.tmp
        echo " - OctoPi: $OCTOPI_TAG" >> release.tmp
        echo " - Octoprint: $(cat opi_source/octoprint_version.txt)" >> release.tmp
        printf "\n\n" >> release.tmp

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




