#!/usr/bin/env bash

sudo apt update
sudo apt upgrade -y

if ! command -v docker &> /dev/null
then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

sudo docker run hello-world
sudo reboot
