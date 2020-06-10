# OctoPrint for other fruits

A custom distribution based on [Armbian](https://www.armbian.com) for running [OctoPrint](https://octoprint.org) for other Pi-like single board computers.   

Credits of this project are for the awesome Armbian team and the outstanding work of @guysoft creating the custom distribution [OctoPi](http://github.com/guysoft/OctoPi) . This port reuse most of OctoPi's code adapting it to the armbian build process and board specs.


## Features

Core (installed and enabled):
* Optimized armbian Debian buster.
* Latest stable octoprint version.
* HAProxy with self signed keys for ssl access.
* SSH console access.
* USB OTG console access (if available in the board)
* Enabled i2c-dev,spidev (if available on the board)

3D printer related software (installed but disabled):
* Klipper 
* PlatformIo core for building 3D printer firmware.
* Marlin 1.1.x & Marlin 2.x.x firmware  
* Selection of top octoprint plugins.

Extras (installed but disabled):
* MPGStreamer USB camera support (experimental)
* SMB shares to remote edit configuration files from a remote PC.


## Usage :

The most easy 

1. Download & extract disk image (*.img.7z) from *releases*.
2. Burn the image in a SD card (>8GB recommended) using *Etcher*, *Win32DiskImager* or the image burner of your choice.
3. Plug the SD card on the board and apply power.

First boot tipically require a few minutes. After octoprint will be available to use.

## Adding boards
TODO



## Building

Building the distribution requires:

- Linux or MacOs
- Vagrant + virtualbox
- 40Gb of free disk space.

'''bash
$ git clone <this repository>
$ cd optocitrico
$ ./optocitrico.sh box
$ ./optocitrico.sh assets
$ ./optocitrico.sh build <board_name>
'''

Build process is slow and verbose it could take up to 3h depending on your hardware. Be patient.  

## Cleaning
Building process could use a lot of space of your disk. To free this space after building you can execute '''./optocitrico.sh clean'''. This will clean all files used for the build including virtual machines and vagrant boxes.

## Tested boards

- Orange Pi Zero 256 Mb
- Orange Pi Zero 512 Mb

## Contributing

PRs are wellcome to fix bugs and add new boards.


