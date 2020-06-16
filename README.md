# OctoPrint for other fruits

A custom distribution based on [Armbian](https://www.armbian.com) for running [OctoPrint](https://octoprint.org) for other Pi-like single board computers.   

Credits of this project are for the awesome Armbian team and the outstanding work of @guysoft creating the custom distribution [OctoPi](http://github.com/guysoft/OctoPi) . This port reuse most of OctoPi's code adapting it to the armbian build process and board specs.


## Features

Core (installed and enabled):
* Optimized armbian Debian buster.
* Latest stable octoprint version.
* HAProxy with self signed keys for ssl access.
* Avahi service: Bonjur addvertisement (this enable to acces with host-name.local via ssh or http/s)
* SSH console access.
* USB OTG console access (if available in the board)
* Enabled i2c-dev,spidev (if available on the board)

3D printer related software (installed but disabled):
* Klipper 
* PlatformIo core for building 3D printer firmware.
* Marlin 1.1.x & Marlin 2.x.x firmware (bugfix versions)  
* Selection of top octoprint plugins.

Extras (installed but disabled):
* MPGStreamer USB camera support (experimental)
* SMB shares to remote edit configuration files from a remote PC.


## Usage

Prebuilt images:

1. Download & extract disk image (*.img.7z) from *releases*.
2. Burn the image in a SD card (>8GB recommended) using *Etcher*, *Win32DiskImager*, *dd* or the image burner of your choice.
3. Plug the SD card on the board and apply power.

First boot tipically require a few minutes. Once booted octoprint will be available to use. If your computer is able to resolve mDns (macos or linux avahi) the name of the board is preconfigured as ```citrico-<board>.local```.

After boot you can access to octroprint server:
- Access to octoprint via https
- ssh session
- Console on Usb OGT (if the board support it)
- Console on board's serial interface with a USB-TTL 
- Conecting a keyboard and screen (if the board support it)

Armbian do not activate WiFi by default. Any initial network access requires ethernet connection if available on the board.

## Default users and passwords:

**octoCitrico** create a two users:
- ```root``` with default password ```octoroot``` 
- ```pi``` with default password ```pi```. This user has ```sudo``` rights.

It's recommended but not mandatory to change user passwords and disable root access via SSH.

## Customizing
For configuring WiFi or customize your instance you need to log into you octocitrico server and configure as you want as in any linux box. Armbian and octocitrico provides helper scripts to make easy the configuration of the box. 

Log with the ```pi``` user:

- ```armbian-config```: Fullfleged configuraion tool.
- ```nmtui```: Network configuration.
- ```scripts/citrico-config```: Enable or disable **octocitrico** default services and edit **octopi** camera configuraiton.

For accessing files via SMB(windows shares) you need to enable Samba service (preconfigured) using ```scripts/citrico-config```

## Adding boards
Adding boards to the project requires few steps:
1. Create a folder with the name of the board inside ```boards``` directory.
2. Inside the __new board__ directory create the a new file ```config.conf``` using as template the existing board.
3. Optionaly create ```extra.sh``` script to adjust specific board configuration.  

**PRs are wellcome with new boards support.**

## Building

Building the distribution requires:

- Linux or MacOs
- Vagrant + virtualbox
- 40Gb of free disk space.

```bash
$ git clone <this repository>
$ cd optocitrico
$ ./optocitrico.sh box
$ ./optocitrico.sh assets
$ ./optocitrico.sh build <board_name>
```

Build process is slow and verbose it could take up to 3h depending on your hardware. Be patient.  

## Cleaning
Building process could use a lot of space of your disk. To free this space after building you can execute ```./optocitrico.sh clean```. This will clean all files used for the build including virtual machines and vagrant boxes.

## Tested boards

- Orange Pi Zero 256 Mb (not recommended due tue low memory)
- Orange Pi Zero 512 Mb

## Contributing

PRs are wellcome to fix bugs and add new boards.


