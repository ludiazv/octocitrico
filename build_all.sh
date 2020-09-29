#!/bin/bash

set -e

BOARDS=( "opizero" "opione" "opipc" )
echo "==============================="
echo "Build all tested and WIP boards"
echo "==============================="
echo "This will build <${BOARDS[@]}>"
printf "Do you want to clean first?[y/N]?"
read -n 1 resp
if [ "$resp" == "y" ] || [ "$resp" == "Y" ] ; then
    echo 
    echo "Cleaning...."
fi
echo
echo "Building...."
for i in "${BOARDS[@]}"
do
    echo "Build $i with cache...."
    ./octocitrico build $i cache
done

exit 0