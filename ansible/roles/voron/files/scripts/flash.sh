#!/bin/sh
cd ~/klipper
cp octo.config .config && \
make menuconfig && \
make -j4  && \
#systemctl stop klipper && \
~/CanBoot/scripts/flash_can.py -i can0 -u 98fd6e742640 -f ~/klipper/out/klipper.bin 
#~/CanBoot/scripts/flash_can.py -d /dev/serial/by-id/usb-CanBoot_stm32f429xx_30004E000D50304738313820-if00 -f ~/klipper/out/klipper.bin && \
#~/CanBoot/scripts/flash_can.py -d /dev/serial/by-id/usb-Klipper_stm32f429xx_30004E000D50304738313820-if00 -f ~/klipper/out/klipper.bin && \
#systemctl start klipper
