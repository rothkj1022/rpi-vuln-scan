#!/usr/bin/env bash

sudo apt update
sudo apt upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
docker run hello-world
