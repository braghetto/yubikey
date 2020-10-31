#!/bin/bash


# Script Config
YUBIKEY_SLOT=1				# Select yubikey slot to be programmed as challenge-response
CHALLENGE_DIR="/etc/yubico"		# Select where to store challenges mappings
PAMMODE="sufficient"			# Select sufficient/required for pam mode
PAMFILE="/etc/pam.d/common-auth"	# Where yubikey pam module will be enabled
UDEVRULES="/etc/udev/rules.d"		# Where is udev rules
UDEVFILE="70-u2f.rules"			# Udev security keys rule file name
USERNAME=$USER				# User to setup pam login


# Installs
sudo add-apt-repository -y ppa:yubico/stable
sudo apt-get update
sudo apt -y install libpam-yubico yubikey-personalization yubikey-manager

# Setup udev rule for keys
cd "$(dirname "$0")"
if [ ! -f "$UDEVRULES/$UDEVFILE" ]; then
	# Install udev keys rule
	sudo cp $UDEVFILE $UDEVRULES
	udevadm control -R
fi

# Functions
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
B=$(tput bold)
N=$(tput sgr0)
slot_confirm() {
	# Advert user about yubikey slot to be writed
        read -r -p "Your ${B}Yubikey's Slot $YUBIKEY_SLOT${N} will be configured for challenge-response! Proceed? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY])
		        ;;
		*)
			# If you need to use slot 2 abort to change script conf
			rm -rf ~/.yubico/
			echo "Aborted. Change script conf to slot 2 if needed."
		        exit
		        ;;
	esac
}

user_confirm() {
	# Check username to be configured
	if [ $USERNAME = "root" ]; then
		echo "Do not execute this script as root!"
		echo "Login the user you want to configure."
                exit
        fi
	# Its possible to specify other user than the actual
	echo
	read -r -p "Actual user is ${B}$USERNAME${N}. Set a different user? [y/N] " response
	case "$response" in
        	[yY][eE][sS]|[yY]) 
                	read -r -p "Enter a different user: " USERNAME
	                UE=$(grep -c "^$USERNAME:" /etc/passwd)
                        if [ $USERNAME = "root" ]; then
                                echo "Root user is a invalid choice!"
                                exit
                        fi
			if [ $UE -eq 0 ]; then
				echo "This user does not exist!"
				exit
			fi
        	        ;;
	        *)
                	;;
	esac
}

set_challenge_file() {
	# Obtains a challenge-response file from yubikey
        ykpamcfg -$YUBIKEY_SLOT -v
        CHALLENGE_FILE=$(find ~/.yubico -name 'challenge-*' -type f -printf "%f\n" | head -n 1)
	# Map key and user
        KEY_SERIAL=${CHALLENGE_FILE#challenge-*}
	sudo mkdir -p $CHALLENGE_DIR
        sudo cp -f ~/.yubico/$CHALLENGE_FILE $CHALLENGE_DIR/$USERNAME-$KEY_SERIAL
	# Cleanup and security
        sudo rm -rf ~/.yubico/*
	sudo chown -R root:root $CHALLENGE_DIR
        sudo chmod 700 $CHALLENGE_DIR
        sudo chmod 600 $CHALLENGE_DIR/*
}

yubikey_set_challenge() {
	# Write challenge-response function to yubikey
	sudo mkdir -p $CHALLENGE_DIR
	ykpersonalize -$YUBIKEY_SLOT -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
}

yubikey_setup_p() {
	# Primary key provisioning
	echo
	echo "Insert your ${B}Primary Yubikey${N} now."
	slot_confirm
	# New key provision
	yubikey_set_challenge
	# Key user mapping
	set_challenge_file
}

yubikey_setup_b() {
	# Backup key provisioning
	echo
	echo "Insert your ${B}Backup Yubikey${N} now."
	slot_confirm
	# New key provision
	yubikey_set_challenge
	# Key user mapping
	set_challenge_file
}

set_pam_auth() {
	# Configure system to login using yunikey challenge-response
	CONFLINE="auth $PAMMODE pam_yubico.so mode=challenge-response chalresp_path=$CHALLENGE_DIR"
	# Only runs if this conf line not exists in pam file
	grep -q $CONFLINE $PAMFILE || sudo cp -f $PAMFILE $PAMFILE.old
	grep -q $CONFLINE $PAMFILE || sudo sed -i "3a $CONFLINE" $PAMFILE
}



### Entry Point

mkdir -p ~/.yubico
user_confirm
KEYS_MADE=0

echo
read -r -p "Do you need to configure the Primary Yubikey device? [y/N] " response
case "$response" in
	# If you need to program new challenge-response keys
	[yY][eE][sS]|[yY]) 
		# Provsion key and map user
        	yubikey_setup_p
		KEYS_MADE=1
		echo
		read -r -p "Do you need to configure the Backup Yubikey device? [y/N] " response
		case "$response" in
			[yY][eE][sS]|[yY])
				# Provision key and map user
				yubikey_setup_b
				KEYS_MADE=2
				;;
			*)
        			;;
	*)
		;;
		esac
esac

if [ $KEYS_MADE -eq 0 ]; then
	# If you already have you challenge-response keys
	echo
	echo "Using Yubikey ${B}Slot $YUBIKEY_SLOT${N}.  ctrl+c to abort"
	read -s -n 1 -p "Insert your ${B}Primary Yubikey${N} now."
	# Map key and user
	set_challenge_file
	KEYS_MADE=1
	echo
	read -r -p "Do you have a ${B}Backup Yubikey${N} device? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY])
			# Map key and user
			set_challenge_file
			KEYS_MADE=2
			;;
		*)
			;;
	esac
fi

if [ $KEYS_MADE -gt 0 ]; then
	# Final system setup and overview
        set_pam_auth
	echo
	echo "${GREEN}${B}Your PAM config file:${N}"
	sudo cat $PAMFILE
	echo
	echo "${GREEN}${B}User keys mapped:${N}"
	sudo ls $CHALLENGE_DIR
	echo
	echo "${RED}${B}Check PAM configuration file and its mapped keys, test access in other TTY before logout. Risk of losing access!${N}"
	echo
	echo "${GREEN}${B}Successfully configured.${N}"
	echo
fi

rm -rf ~/.yubico/

exit
