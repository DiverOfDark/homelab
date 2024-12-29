#!/bin/sh
cd ~/klipper
cp sb2040.config .config && \
make menuconfig && \
make -j4 && \
#systemctl stop klipper && \
~/CanBoot/scripts/flash_can.py -i can0 -u 678b3311c83f -f ~/klipper/out/klipper.bin && \
#systemctl start klipper
echo done
