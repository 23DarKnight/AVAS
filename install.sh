#!/usr/bin/bash

pip3 install indiagrid --break
sudo rm /usr/bin/map
sudo rm /usr/share/parth/routes.pkl
sudo cp map /usr/bin/map
#sudo systemctl stop radio
#sudo rm /usr/bin/radio
#sudo cp radio /usr/bin/radio
#sudo chmod +x /usr/bin/map /usr/bin/radio
cp routes.pkl /usr/share/parth/routes.pkl
sudo chmod +x /usr/bin/map
#sudo systemctl daemon-reload
#sudo reboot
#sudo systemctl stop gps
#sudo rm /usr/bin/gps
#sudo cp gps /usr/bin/gps
#sudo chmod +x /usr/bin/gps
