#!/usr/bin/bash

sudo rm /usr/bin/map
sudo mv map.py /usr/bin/map
sudo chmod +x /usr/bin/map
sudo systemctl daemon-reload
sudo systemctl restart getty@tty1
