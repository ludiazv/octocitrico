#!/bin/bash

set -e

#BOARDS=( "opizero" "opione" "opilite" "opipc" "opipcplus" "bpim2z" "opioneplus" "rock64" "opizero2" "opi3lts" "bpm2p" )
BOARDS=( "opizero" "opione" "opilite" "opipc" "opipcplus" "bpim2z" "opioneplus" "opizero2" "opi3lts" "bpm2p" )
echo "==============================="
echo "Build all tested and WIP boards"
echo "==============================="
echo "This will build <${BOARDS[@]}>"
printf "Do you want to clean first?[y/N]?"
read -n 1 resp
if [ "$resp" == "y" ] || [ "$resp" == "Y" ] ; then
    set +e
    if [ "$1" == "docker" ] ; then
        echo
        echo "Cleaning docker build env..."
        pushd $AR_DIR
        ./octocitrico.sh clean_docker
        popd
        echo "Installing docker build env..."
        ./octocitrico.sh assets
    else
        echo 
        echo "Cleaning...."
        ./octocitrico.sh clean
        echo "Installing build environment...."
        ./octocitrico.sh box
        ./octocitrico.sh assets
        echo
    fi
    set -e
fi
echo
echo "Building...."
for i in "${BOARDS[@]}"
do
    echo "Build $i with cache...."
    ./octocitrico.sh build $i cache
    echo "Done!"
done

exit 0
