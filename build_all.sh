#!/bin/bash

set -e

BOARDS=( "opizero" "opione" "opilite" "opipc" "opipcplus" "bpim2z" "opioneplus" "rock64" )
echo "==============================="
echo "Build all tested and WIP boards"
echo "==============================="
echo "This will build <${BOARDS[@]}>"
printf "Do you want to clean first?[y/N]?"
read -n 1 resp
if [ "$resp" == "y" ] || [ "$resp" == "Y" ] ; then
    set +e
    echo 
    echo "Cleaning...."
    ./octocitrico.sh clean
    echo "Installing build environment...."
    ./octocitrico.sh box
    ./octocitrico.sh assets
    echo
    set -e
fi
echo
echo "Building...."
for i in "${BOARDS[@]}"
do
    echo "Build $i with cache...."
    ./octocitrico.sh build $i cache
done

exit 0