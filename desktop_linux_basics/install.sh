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
apt-get install wine krita ardour audacity wxmaxima clementine fbreader

#Yep really. I'm puting chrome.
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i google-chrome-stable_current_amd64.deb


#If there's no ntp, get rid of systemd's terrible simplified thing.
#If there is, maybe it's for a reason.
if [ $(dpkg-query -W -f='${Status}' ntp 2>/dev/null | grep -c "ok installed") -eq 0 ];
then
  apt-get install chrony;
fi


