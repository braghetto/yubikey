#!/bin/bash


# Install everthing
sudo apt -y install wget git gnupg2 gnupg-agent dirmngr cryptsetup scdaemon pcscd secure-delete hopenpgp-tools yubikey-personalization
sudo apt -y install python3-pip python3-pyscard
sudo python3 -m pip install PyOpenSSL
sudo python3 -m pip install yubikey-manager
sudo systemctl enable pcscd.service
sudo systemctl start pcscd.service

# Setup Gpg Agent for SSH
cat agentrc >> ~/.bashrc

# Setup Git
git config --global user.signingkey 0xF30A97F0712B0058
git config --global user.name "Arthur Mochiuti Braghetto"
git config --global user.email arthurmb@gmail.com
git config --global commit.gpgsign true

# Setup Gpg
mkdir ~/.gnupg
cp -f *.conf ~/.gnupg
chmod 600 ~/.gnupg/*.conf

# Import public key
wget https://arthur.mobi/public.key
gpg --import public.key

# Set key trust
echo -e "5\ny\n" |  gpg --command-fd 0 --expert --edit-key 0xF30A97F0712B0058 trust

# Test
echo
read -s -n 1 -p "Insert Yubikey to test..."
echo
ssh git@github.com
