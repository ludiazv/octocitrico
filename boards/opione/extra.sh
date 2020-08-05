# WIP Based on OPI ZERO
# Fix wifi in networkmanager on debian
#echo -e "[device]\nwifi.scan-rand-mac-address=no\n" >> /etc/NetworkManager/NetworkManager.conf

# Add i2c & spidev udev rules
echo 'SUBSYSTEM=="spidev", GROUP="spi", MODE="0660"' > /etc/udev/rules.d/49-spidev.rules
echo 'SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0660"' > /etc/udev/rules.d/50-i2cdev.rules

# Add add overlays to enable spidev 0 I2c 0 & uart 3
add_overlay i2c0
add_overlay spi-spidev "param_spidev_spi_bus=0"
add_overlay uart3