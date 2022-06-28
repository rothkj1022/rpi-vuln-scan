#!/usr/bin/env bash

sudo apt update
sudo apt upgrade -y

sudo apt -y install git swaks dnsutils

read -p "Please enter your username [pi]: " username
username=${username:-pi}
echo $username
read -p "Please enter email address to send to: " email_to
echo $email_to
read -p "Please enter email address to send from: " email_from
echo $email_from
PS3='How would you like to send email? '
mailers=("SMTP" "Mailgun" "Quit")
select mailer in "${mailers[@]}"; do
    case $mailer in
        "SMTP")
            echo "Enter your SMTP settings:"
            read -p "SMTP server: " smtp_server
            read -p "SMTP port: " smtp_port
            read -p "SMTP username: " smtp_user
            read -p "SMTP password: " smtp_pass
            break
        ;;
        "Mailgun")
            echo "Enter your Mailgun settings:"
            read -p "Mailgun API key: " mg_api_key
            read -p "Mailgun sending domain: " mg_domain
            break
        ;;
        "Quit")
            #echo "User requested exit"
            exit
        ;;
    *) echo "invalid option $REPLY";;
    esac
done

cd ~
mkdir /home/$username/rpi-scanner
(crontab -l ; echo "@reboot /bin/bash -c \". ~/.bashrc; /home/$username/rpi-scanner/rpi-scan.sh > /tmp/rpi-scanner.txt 2>&1\"") | crontab -

# Learned about heredoc magic: https://unix.stackexchange.com/questions/138418/passing-a-variable-to-a-bash-script-that-uses-eof-and-considers-the-variable-a
cat > /home/$username/rpi-scanner/rpi-scan.sh <<EOF
#!/usr/bin/env bash

# need to give network interfaces time to come up before starting
sleep 120

email="$email_to"

ip_addr=\$(/sbin/ifconfig eth0 | grep "inet " | awk '{print \$2}')
ip_subnet=\$(echo "\$ip_addr" | cut -d'.' -f1,2,3)
ip_subnet+=".0/24"
echo "Scanning \$ip_subnet..."

EOF

# Send email that scan has started
if [[ "$mailer" == 'SMTP' ]]; then
    cat >> /home/$username/rpi-scanner/rpi-scan.sh <<EOF
#send email that scan has started
swaks --auth \
--server $smtp_server \
--p $smtp_port \
--au $smtp_user \
--ap $smtp_pass \
--to $email_to \
--from $email_from \
--h-Subject: 'RPi Scan Started' \
--body "Hello,

Your Raspberry Pi Scan has started.

Scanning range: \$ip_subnet
External IP: \$(dig +short txt ch whoami.cloudflare @1.0.0.1)

Please be patient, sometimes scans take over 12 hours.
" \

EOF
elif [[ "$mailer" == 'Mailgun' ]]; then
    cat >> /home/$username/rpi-scanner/rpi-scan.sh <<EOF
curl -s --user "api:$mg_api_key" \
https://api.mailgun.net/v3/$mg_domain/messages \
-F to=$email_to \
-F from="$email_from" \
-F subject='RPi Scan Started' \
-F text="Hello,

Your Raspberry Pi Scan has started.

Scanning range: \$ip_subnet
External IP: \$(dig +short txt ch whoami.cloudflare @1.0.0.1)

Please be patient, sometimes scans take over 12 hours.

" \

EOF
fi

# Run docker command to update to latest and run scan
cat >> /home/$username/rpi-scanner/rpi-scan.sh <<EOF
#run scan
docker run --rm -v /tmp/:/reports/:rw pensivesecurity/rpi-scanner:latest python3 -u scan.py "\$ip_subnet" --debug --update --format="PDF" --output rpi-openvas-report.pdf --profile="Full and fast"

EOF

# Email report
if [[ "$mailer" == 'SMTP' ]]; then
    cat >> /home/$username/rpi-scanner/rpi-scan.sh <<EOF
#send email that scan has started
swaks --auth \
--server $smtp_server \
--p $smtp_port \
--au $smtp_user \
--ap $smtp_pass \
--to $email_to \
--from $email_from \
--h-Subject: 'RPi Scan Completed' \
--body 'See attached report.' \
--attach rpi-openvas-report.pdf

EOF
elif [[ "$mailer" == 'Mailgun' ]]; then
    cat >> /home/$username/rpi-scanner/rpi-scan.sh <<EOF
curl -s --user "api:$mg_api_key" \
https://api.mailgun.net/v3/$mg_domain/messages \
-F to=$email_to \
-F from="$email_from" \
-F subject='RPi Scan Completed' \
-F text='See attached report.' \
-F attachment=rpi-openvas-report.pdf

EOF
fi

chmod +x /home/$username/rpi-scanner/rpi-scan.sh

# Install Docker
if ! command -v docker &> /dev/null
then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    #sudo apt install docker
    sudo usermod -aG docker $username
fi

sudo docker run hello-world
echo "Installation finished successfully! Plug your RPi into your router with an Ethernet cable and restart it."
