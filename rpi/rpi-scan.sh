#!/usr/bin/env bash

email=""
ip_addr=$(ifconfig eth0 | grep "inet " | awk '{print $2}')
ip_subnet=$(echo $ip_addr | cut -d'.' -f1,2,3)
ip_subnet+=".0/24"
echo "Scanning $ip_subnet..."
curl "https://rpi.pensivesecurity.io/sendstart?recipient=$email"
sudo docker run --rm -v $(pwd):/reports/:rw pensivesecurity/rpi-scanner:latest python3 -u scan.py "$ip_subnet" --update --format="PDF" -m 256 --output rpi-openvas-report.pdf --profile="Full and fast"
file_url=$(sudo docker run --rm -it -v $(pwd):/data timvisee/ffsend upload -h https://pensivesecurity.io/ rpi-openvas-report.pdf)
curl "https://rpi.pensivesecurity.io/sendresults?recipient=$email&reporturl=$file_url"
