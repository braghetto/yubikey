#!/bin/bash


# Script Config
YUBIKEY_SLOT=1				# Select yubikey slot to be programmed as challenge-response
CHALLENGE_DIR="/etc/yubico"		# Select where to store challenges mappings
PAMMODE="sufficient"			# Select sufficient/required for pam mode
PAMFILE="/etc/pam.d/common-auth"	# Where yubikey pam module will be enabled
USERNAME=$USER				# User to setup pam login


# Installs
sudo add-apt-repository -y ppa:yubico/stable 
sudo apt-get update
sudo apt -y install libpam-yubico yubikey-personalization yubikey-manager

# Functions
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
B=$(tput bold)
N=$(tput sgr0)
slot_confirm() {
        read -r -p "Your ${B}Yubikey's Slot $YUBIKEY_SLOT${N} will be configured for challenge-response! Proceed? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY]) 
		        ;;
		*)
			rm -rf ~/.yubico/
			echo "Aborted."
		        exit
		        ;;
	esac
}

user_confirm() {
	if [ $USERNAME = "root" ]; then
		echo "Do not execute this script as root!"
		echo "Login the user you want to configure."
                exit
        fi
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
        ykpamcfg -$YUBIKEY_SLOT -v
        CHALLENGE_FILE=$(find ~/.yubico -name 'challenge-*' -type f -printf "%f\n" | head -n 1)
        KEY_SERIAL=${CHALLENGE_FILE#challenge-*}
	sudo mkdir -p $CHALLENGE_DIR
        #sudo cp -f ~/.yubico/$CHALLENGE_FILE $CHALLENGE_DIR/root-$KEY_SERIAL		#enable just for first run, if you want.
        sudo cp -f ~/.yubico/$CHALLENGE_FILE $CHALLENGE_DIR/$USERNAME-$KEY_SERIAL
        sudo rm -rf ~/.yubico/*
	sudo chown -R root:root $CHALLENGE_DIR
        sudo chmod 700 $CHALLENGE_DIR
        sudo chmod 600 $CHALLENGE_DIR/*
}

yubikey_set_challenge() {
	sudo mkdir -p $CHALLENGE_DIR
	ykpersonalize -$YUBIKEY_SLOT -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
}

yubikey_setup_p() {
	echo
	echo "Insert your ${B}Primary Yubikey${N} now."
	slot_confirm
	yubikey_set_challenge
	set_challenge_file
}

yubikey_setup_b() {
	echo
	echo "Insert your ${B}Backup Yubikey${N} now."
	slot_confirm
	yubikey_set_challenge
	set_challenge_file
}

set_pam_auth() {
	CONFLINE="auth $PAMMODE pam_yubico.so mode=challenge-response chalresp_path=$CHALLENGE_DIR"
	grep -q $CONFLINE $PAMFILE || sudo cp -f $PAMFILE $PAMFILE.old
	grep -q $CONFLINE $PAMFILE || sudo sed -i "3a $CONFLINE" $PAMFILE
}



# Entry Point
mkdir -p ~/.yubico
user_confirm
KEYS_MADE=0
echo
read -r -p "Do you need to configure the Primary Yubikey device? [y/N] " response
case "$response" in
	[yY][eE][sS]|[yY]) 
        	yubikey_setup_p
		KEYS_MADE=1
		echo
		read -r -p "Do you need to configure the Backup Yubikey device? [y/N] " response
		case "$response" in
			[yY][eE][sS]|[yY])
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
	echo
	echo "Using Yubikey Slot $YUBIKEY_SLOT."
	read -s -n 1 -p "Insert your ${B}Primary Yubikey${N} now."
	set_challenge_file
	KEYS_MADE=1
	echo
	read -r -p "Do you have a ${B}Backup Yubikey${N} device? [y/N] " response
	case "$response" in
		[yY][eE][sS]|[yY]) 
			set_challenge_file
			KEYS_MADE=2
			;;
		*)
			;;
	esac
fi

if [ $KEYS_MADE -gt 0 ]; then
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
