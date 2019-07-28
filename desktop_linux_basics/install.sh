#!/bin/sh

#This script installs the stuff I think every distro should have.
#I don't expect anyone to agree with me....

#If you're not a minimalist and you're coming from windows you might like
#my choices.

#Who doesn't want a cool file sync util?
# Add the release PGP keys:
curl -s https://syncthing.net/release-key.txt | apt-key add -
# Add the "stable" channel to your APT sources:
echo "deb https://apt.syncthing.net/ syncthing stable" | tee /etc/apt/sources.list.d/syncthing.list
# Update and install syncthing:
apt-get update
apt-get install syncthing


#Now for a good backup utility called Back in Time
add-apt-repository ppa:bit-team/stable
apt-get update
apt-get install backintime-qt4

#Install the 2 big "more friendly" shells
apt-get install fish zsh


#I'm not even going to pretend this script is for everyone..
apt-get install wine winetricks krita ardour audacity wxmaxima clementine fbreader gnome-disk-utility
apt-get install exfat-utils convertall

#As your user you'll need to run
#winetricks allfonts

#Yep really. I'm puting chrome.
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i google-chrome-stable_current_amd64.deb


#If there's no ntp, get rid of systemd's terrible simplified thing.
#If there is, maybe it's for a reason.
if [ $(dpkg-query -W -f='${Status}' ntp 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install chrony;
fi

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append file with string on new line.
append1() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}
#Install the drivers for a a common Realtek USB WiFi chipset that isn't mainline
# https://ubuntuforums.org/showthread.php?t=2410077
apt-get install git build-essential
git clone git://github.com/ulli-kroll/rtl8188fu
cd rtl8188fu
make
make installfw
modprobe cfg80211
insmod rtl8188fu.ko
cp rtl8188fu.ko /lib/modules/`uname -r`/kernel/drivers/usb/usbip/
append1 /etc/modules rtl8188fu rtl8188fu
depmod
