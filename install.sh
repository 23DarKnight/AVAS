#!/usr/bin/bash

sudo rm /usr/bin/gps
sudo mv gps /usr/bin/gps
sudo chmod +x /usr/bin/gps
sudo systemctl daemon-reload
sudo systemctl status gps
