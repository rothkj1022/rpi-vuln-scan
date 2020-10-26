#!/usr/bin/env bash

sudo apt update
sudo apt upgrade -y

if ! command -v COMMAND &> /dev/null
then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
fi

docker run hello-world
