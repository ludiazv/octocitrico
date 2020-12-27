
# Fix wifi in networkmanager on debian
echo -e "[device]\nwifi.scan-rand-mac-address=no\n" >> /etc/NetworkManager/NetworkManager.conf

# Add i2c & spidev udev rules
echo 'SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"' > /etc/udev/rules.d/49-spidev.rules
echo 'SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"' > /etc/udev/rules.d/50-i2cdev.rules

# Add gpio udev rules
  cat <<EOT >> /etc/udev/rules.d/51-gpio.rules
SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="/bin/sh -c 'chown root:gpio /sys/class/gpio/export /sys/class/gpio/unexport ; chmod 220 /sys/class/gpio/export /sys/class/gpio/unexport'"
SUBSYSTEM=="gpio", KERNEL=="gpio*", ACTION=="add", \
PROGRAM="/bin/sh -c 'chown -h root:gpio /sys/class/gpio/%k; chown root:gpio /sys%p/value /sys%p/active_low /sys%p/direction /sys%p/edge ; \
        chmod 660 /sys%p/value /sys%p/active_low /sys%p/direction /sys%p/edge'"
EOT

# Add add overlays to enable spidev 1 I2c 0 & uart 1
add_overlay i2c0
add_overlay spi-spidev "param_spidev_spi_bus=1"
add_overlay uart1