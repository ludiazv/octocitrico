
function die () {
    echo >&2 "$@"
    exit 1
}

function pause() {
  # little debug helper, will pause until enter is pressed and display provided
  # message
  read -p "$*"
}

function echo_red() {
  echo -e -n "\e[91m"
  echo $@
  echo -e -n "\e[0m"
}

function echo_green() {
  echo -e -n "\e[92m"
  echo $@
  echo -e -n "\e[0m"
}

function echo_result() {
  if [ $1 -eq 0 ] ; then
    shift
    echo_green "Success" $@
  else
    shift
    echo_red "Error" $@
  fi
}


function unpack() {
  # call like this: unpack /path/to/source /target user -- this will copy
  # all files & folders from source to target, preserving mode and timestamps
  # and chown to user. If user is not provided, no chown will be performed

  local from=$1
  local to=$2
  local owner=
  if [ "$#" -gt 2 ]
  then
    owner=$3
  fi

  # $from/. may look funny, but does exactly what we want, copy _contents_
  # from $from to $to, but not $from itself, without the need to glob -- see 
  # http://stackoverflow.com/a/4645159/2028598
  cp -v -r --preserve=mode,timestamps $from/. $to
  if [ -n "$owner" ]
  then
    chown -hR $owner:$owner $to
  fi
}
function unpack_file() {
  local from=$1
  local to=$2
  local owner=
  if [ "$#" -gt 2 ]
  then
    owner=$3
  fi

  cp -v -r --preserve=mode,timestamps $from $to
  if [ -n "$owner" ]
  then
    chown -hR $owner:$owner $to
  fi

}


# Change the machine  name
# $1 -> new machine name
function change_host_name() {
  printf "Change hostname..."
  local hname=$1
  echo $hname > /etc/hostname
  chmod a+r /etc/hostname
  echo_result $? 
}
# Add overlay
# $1 -> Overlay name
# $2 -> Param texts appended 
function add_overlay() {
  local ov=$1
  local pars=$2
  if grep -q '^overlays=' /boot/armbianEnv.txt; then
    local line=$(grep '^overlays=' /boot/armbianEnv.txt | cut -d'=' -f2)
    if grep -qE "(^|[[:space:]])${ov}([[:space:]]|$)" <<< $line; then
		  echo "Overlay ${ov} was already added to /boot/armbianEnv.txt, skipping"
	  else
		sed -i -e "/^overlays=/ s/$/ ${ov}/" /boot/armbianEnv.txt
	  fi
  else
    #sed -i -e "\$overlays=${ov}" /boot/armbianEnv.txt
    echo -e "overlays=${ov}" >> /boot/armbianEnv.txt
  fi
  # adding parameters at the end of the file
  if [ ! -z $pars ] ; then
    echo -e "$pars" >> /boot/armbianEnv.txt
  fi

  echo_green $? "Added overlay $ov"

}

# Setup users
#  $1 -> root password
#  $2 -> user name
#  $3 -> user password
#  $4 -> webcam user
function users_and_groups() {
  
  local rootpwd="$1"
  local user="$2"
  local psw="$3"
  local wc_user="$4"
  
  printf "Change root password..."
  rm -f /root/.not_logged_in_yet
  echo -e "$rootpwd\n$rootpwd\n" | (passwd root)
  echo_result $?

  printf "Setting up IO groups..."
  getent group i2c  2>&1 > /dev/null || groupadd i2c
  getent group spi  2>&1 > /dev/null || groupadd spi
  getent group gpio 2>&1 > /dev/null || groupadd gpio
  echo_result $?
  
  printf "Setting up $user..."
  useradd -m $user -p $psw -s /bin/bash -m
  echo -e "$psw\n$psw\n" | (passwd $user)
  echo -e "$psw\n$psw\n" | (smbpasswd -a $user)
  
  usermod -a -G tty     $user
  usermod -a -G i2c     $user
  usermod -a -G dialout $user
  usermod -a -G gpio    $user
  usermod -a -G sudo    $user
  usermod -a -G spi     $user
  usermod -a -G video   $user
  echo_result $?

  printf "Setting up $wc_user..."
  useradd $wc_user
  usermod -aG video $wc_user
  echo_result $?

  printf "Setting up sudo..."
  echo "$user ALL=(ALL) NOPASSWD: /sbin/shutdown *" > /etc/sudoers.d/octoprint-shutdown
  echo "$user ALL= NOPASSWD: /bin/systemctl restart octoprint.service" > /etc/sudoers.d/octoprint-service
  echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tmp-nopsw
  # Fix permission found in bug #7
  chmod 0440 /etc/sudoers.d/*
  echo_result $?


  printf "Creating samba share..."
  cat >> /etc/samba/smb.conf <<EOT
  [$user-files]
  path =/home/$user
  valid users = $user
  read only = no
  browseable = yes
EOT

}

###  Install section
### ------------------
# Base software
function tweak_base() {
   printf "Tweak base system..."
   local url=$YQ_DOWNLOAD
   if [[ "$(uname -m)" == "aarch64" ]] ; then
      url=$YQ_DOWNLOAD64
   fi
   wget -O yq $url && chmod +x yq && mv yq /usr/local/bin
   # Remove ssl-certs
   rm /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem
   # Add piwheels to pip.conf
   echo "[global]" >> /etc/pip.conf
   echo "extra-index-url=https://www.piwheels.org/simple" >> /etc/pip.conf
   
   echo_result $? "[TWEAK BASE]"
}
# Install octroprint
# $1 -> user
function install_octoprint() {
  local user=$1
  pushd /home/$user
    printf "Installing octoprint..."
    su -c "python3 -m virtualenv --python=python3 oprint" -l $user
    su -c "/home/$user/oprint/bin/pip install --upgrade pip" -l $user
    #su -c "/home/$user/oprint/bin/pip --no-cache-dir install $PYBONJOUR_ARCHIVE" -l $user
    su -c "/home/$user/oprint/bin/pip --no-cache-dir install $rt_dir/octoprint.tar.gz" -l $user
  popd
  # Prepare systemd startup
cat > /etc/systemd/system/octoprint.service <<EOF
[Unit]
Description=OctoPrint - the snappy web interface for your 3D printer
Wants=network-online.target
After=network.target network-online.target

[Service]
# Default environment, for compatibility with scripts/octoprint.init
Environment=PORT=5000
Environment=BASEDIR=/home/$user/.octoprint
Environment=CONFIGFILE=/home/$user/.octoprint/config.yaml
# Optional daemon arguments, e.g. --host 127.0.0.1
Environment=DAEMON_ARGS=
Type=simple
User=$user
Group=$user
Nice=-2
Restart=on-failure
RestartSec=5
ExecStart=/home/$user/oprint/bin/octoprint serve --basedir \${BASEDIR} --config \${CONFIGFILE} --port \${PORT} \$DAEMON_ARGS
[Install]
WantedBy=multi-user.target
EOF
  echo_result $? "[OCTOPRINT]"
}
#install octoprint plugin
# $2 -> user
function install_octoprint_plugins() {
  local user=$1
  #pushd /home/$user
  #for plug in "${OCTOPRINT_PLUGINS[@]}"
  #do
  #  su -c "/home/$user/oprint/bin/pip --no-cache-dir install ${plug}" -l $user
  #done
  #popd  
  #Parallel pip
  su -c "xargs --max-args=1 --max-procs=4 /home/$user/oprint/bin/pip --no-cache-dir install < $rt_dir/plugins/plugins.txt" -l $user


}

#install mjpg_streamer
# $1 -> user
function install_mjpgstreamer() {
  local user=$1
  
  # Migrated to /opt/mjpg-streamer as octopi 1.0
  local install_dir=/opt/mjpg-streamer

  # unpack MJPG STREAMER temporary to root
  unpack $rt_dir/mjpg-streamer/mjpg-streamer-experimental   /root/mjpg-streamer   $OCTO_USER


  #pushd /home/$user
  #su -l $user -c "git clone --depth 1 $MJPGSTREAMER_REPO mjpg-streamer"
  #popd
  pushd /root/mjpg-streamer
    local build_dir=_build
    mkdir -p $build_dir
    pushd $build_dir
      cmake -DCMAKE_BUILD_TYPE=Release ..
    popd

    make -j $(nproc) -C $build_dir

    mkdir -p $install_dir

    install -m 755 $build_dir/mjpg_streamer $install_dir
    find $build_dir -name "*.so" -type f -exec install -m 644 {} $install_dir \;

    # copy bundled web folder
    cp -a -r ./www $install_dir
    chmod 755 $install_dir/www
    chmod -R 644 $install_dir/www

    # create our custom web folder and add a minimal index.html to it
    mkdir $install_dir/www-octopi
    pushd $install_dir/www-octopi
        cat <<EOT >> index.html
<html>
<head><title>mjpg_streamer test page</title></head>
<body>
<h1>Snapshot</h1>
<p>Refresh the page to refresh the snapshot</p>
<img src="./?action=snapshot" alt="Snapshot">
<h1>Stream</h1>
<img src="./?action=stream" alt="Stream">
</body>
</html>
EOT
    popd
      
  # /root/mjpg-streamer
  popd

  # remove tmp steamer sources
  rm -rf /root/mjpg-streamer

  # symlink for backwards compatibilitydd
  sudo -u $user ln -s $install_dir /home/$user/mjpg-streamer

}

# install custom ffmpeg
# $1 -> $user
function install_custom_ffmpeg() {
  local user=$1
  local ARCH="arm"
  local FFMPEG_HLS_DIR=/opt/ffmpeg-hls
  local FFMPEG_ARCHIVE=ffmpeg.tar.gz
  local FFMPEG_CACHE=$rt_dir/ffmpeg-hls-"${ARCH}"


  if [[ "$(uname -m)" == "aarch64" ]] ; then
     ARCH="aarch64"
  fi

  if [ -f $FFMPEG_CACHE ] ; then
    cp $FFMPEG_CACHE $FFMPEG_HLS_DIR/ffmpeg
  else

    FFMPEG_BUILD_DIR=$(mktemp -d)
    pushd ${FFMPEG_BUILD_DIR}
      #wget https://api.github.com/repos/FFmpeg/FFmpeg/tarball/${FFMPEG_COMMIT} -O ${FFMPEG_ARCHIVE}
      cp $rt_dir/${FFMPEG_ARCHIVE} ./${FFMPEG_ARCHIVE}
      tar xvzf ${FFMPEG_ARCHIVE}
      cd FFmpeg*
      ./configure \
        --arch="${ARCH}" \
        --disable-doc \
        --disable-htmlpages \
        --disable-manpages \
        --disable-podpages \
        --disable-txtpages \
        --disable-ffplay \
        --disable-ffprobe
      make -j$(nproc)
      mkdir -p ${FFMPEG_HLS_DIR}
      cp ffmpeg ${FFMPEG_HLS_DIR}/ffmpeg
      #cp ffmpeg $FFMPEG_CACHE
      #copy_and_export ffmpeg-hls-"${ARCH}" ffmpeg "${FFMPEG_HLS_DIR}"
    popd
    rm -r ${FFMPEG_BUILD_DIR}
  fi




}


#install extras
# $1 -> user
function install_extras() {
  local user=$1
  pushd /home/$user
  su -l $user -c "unzip $rt_dir/marlin1.zip"
  su -l $user -c "unzip $rt_dir/marlin2.zip"
  
  su -l $user -c "python3 -m virtualenv --python=python3 .platformio/penv"
  su -l $user -c "/home/$user/.platformio/penv/bin/pip --no-cache-dir install -U platformio"
  su -l $user -c "echo 'export PATH=\$PATH:~/.platformio/penv/bin' >> /home/$user/.profile"
  #su -l $user -c "git clone --depth 1 $KLIPPER_REPO"
  #sed -i 's/pip -r/pip --no-cache-dir -r /g' ./klipper/scripts/install-debian.sh
  #su -l $user -c "chmod u+x ./klipper/scripts/install-debian.sh && ./klipper/scripts/install-debian.sh"
  #systemctl disable klipper.service
  popd
  echo $? "[EXTRAS]"
}


# Customize script
# $1 -> Board name
# $2 -> Overlay directory in build time
function customize() {
  local board=$1
  local rt_dir=$2

  # Basic configuration
  echo "========================================================"
  echo " OctoCitrico customization script [START] $CURRENT_ARCH "
  echo "========================================================"
  users_and_groups $ROOTPASSWD $OCTO_USER $OCTO_PASSWD $WEBCAM_USER
  #install_base $BASE_PACKS
  #             $ROOTPASSWD
  #users_and_groups $ROOTPASSWD $OCTO_USER $OCTO_PASSWD
  tweak_base
  change_host_name "citrico-$board"
  
  # unpack FS octopi
  unpack_file $rt_dir/filesystem/boot/octopi.txt /boot/octopi.txt   root
  unpack $rt_dir/filesystem/home/root            /root              root
  unpack $rt_dir/filesystem/home/pi              /home/$OCTO_USER   $OCTO_USER
  unpack $rt_dir/filesystem/root/etc/haproxy     /etc/haproxy       root
  unpack $rt_dir/filesystem/root/etc/udev        /etc/udev          root
  unpack $rt_dir/filesystem/root/etc/systemd     /etc/systemd       root
  unpack $rt_dir/filesystem/root/etc/nginx       /etc/nginx         root 
  unpack $rt_dir/filesystem/root/usr/lib         /usr/lib           root    
  unpack $rt_dir/filesystem/root/var/lib         /var/lib           root 

  # Install octoprint
  install_octoprint $OCTO_USER
  install_octoprint_plugins $OCTO_USER

  # Unpack octocitrico files 
  unpack $rt_dir/common_fs/etc                   /etc               root
  unpack $rt_dir/common_fs/home/pi               /home/$OCTO_USER   $OCTO_USER


  # make home/$user/scripts executable
  chmod u+x /home/$OCTO_USER/scripts/*

  # Add sensbile defaults for camera in /boot/octopi.txt
  sed -i 's/#camera="auto"/camera="usb"/' /boot/octopi.txt
  sed -i -r 's/#camera_usb_options="(.+)"/camera_usb_options="-d \/dev\/video1 \1"/' /boot/octopi.txt
  sed -i 's/#camera_streamer=mjpeg/camera_streamer=mjpeg/' /boot/octopi.txt

  # fix haproxy configuration file name
  mv /etc/haproxy/haproxy.2.x.cfg /etc/haproxy/haproxy.cfg

  # unpack Klipper
  #unpack $rt_dir/klipper   /home/$OCTO_USER/klipper   $OCTO_USER

  # Install extras
  install_custom_ffmpeg $OCTO_USER
  install_mjpgstreamer $OCTO_USER
  install_extras $OCTO_USER

  #enable/disable services
  systemctl enable gencert.service
  systemctl enable octoprint.service
  systemctl disable nginx.service
  systemctl disable smbd.service

}

function customize_clean() {

  rm -f /etc/sudoers.d/tmp-nopsw
  apt-get clean
  apt-get autoremove -y
  echo "=================================================="
  echo " OctoCitrico customization script [END]"
  echo "=================================================="
}

