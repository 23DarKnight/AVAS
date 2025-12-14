#!/usr/bin/bash

pip3 install indiagrid --break
touch /usr/share/parth/routes.pkl
sudo rm /usr/bin/map
sudo cp map /usr/bin/map
sudo systemctl stop radio
sudo rm /usr/bin/radio
sudo cp radio /usr/bin/radio
sudo chmod +x /usr/bin/map /usr/bin/radio
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1
