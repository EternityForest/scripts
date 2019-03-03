#!/bin/bash


# Used to confi




# Based on the readonly script from:
# https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/issues

#Plus an earlier script I wrote from a bunch of tutorials.

# CREDIT TO THESE TUTORIALS:
# petr.io/en/blog/2015/11/09/read-only-raspberry-pi-with-jessie
# hallard.me/raspberry-pi-read-only
# k3a.me/how-to-make-raspberrypi-truly-read-only-reliable-and-trouble-free

if [ $(id -u) -ne 0 ]; then
	echo "Installer must be run as root."
	echo "Try 'sudo bash $0'"
	exit 1
fi

clear





echo "This script configures a Raspberry Pi"
echo "with several options useful for"
echo "Always-on, headless use".
echo ""
echo "It does not make the card read only unless requested."
echo "But it does greatly reduce useless background card activity."

echo "You can choose to make the SD card to boot into read-only mode,"
echo "obviating need for clean shutdown."
echo "NO FILES ON THE CARD CAN BE CHANGED"
echo "WHEN PI IS BOOTED IN THIS STATE. Either"
echo "the filesystems must be remounted in"
echo "read/write mode, card must be mounted"
echo "R/W on another system, or an optional"
echo "jumper can be used to enable read/write"
echo "on boot."
echo
echo "Links to original tutorials are in"
echo "script source. THIS IS A ONE-WAY"
echo "OPERATION. THERE IS NO SCRIPT TO"
echo "REVERSE THIS SETUP! ALL other system"
echo "config should be complete before using"
echo "this script. MAKE A BACKUP FIRST."
echo
echo "Run time ~5 minutes. Reboot required."


# FEATURE PROMPTS ----------------------------------------------------------
# Installation doesn't begin until after all user input is taken.
# Unless we're in scripted mode

INSTALL_RW_JUMPER=0
INSTALL_HALT=0
INSTALL_WATCHDOG=0
ACTUALLY_RO=0
SCRIPTED=0
WD_TARGET=99

SYS_TYPES=(Pi\ 3\ /\ Pi\ Zero\ W All\ other\ models)
WATCHDOG_MODULES=(bcm2835_wdog bcm2708_wdog)
OPTION_NAMES=(NO YES)

while getopts 'srwhjp:' flag; do
  case "${flag}" in
    s) SCRIPTED=1 ;;
    j) INSTALL_RW_JUMPER=1  ;;
    p) WD_TARGET="${OPTARG}" ;;
    h) INSTALL_HALT=1 ;;
    r) ACTUALLY_RO=1 ;;
	w) INSTALL_WATCHDOG=1 ;;
	*) echo ""
       exit 1 ;;
  esac
done

if [ $SCRIPTED -eq 1 ]; then
	if [ $INSTALL_WATCHDOG -eq 1 ]; then
		if [ $WD_TARGET -eq 99 ]; then
			echo "You must specify the pi version to use the watchdog feature"
			exit 1
		fi
	fi
fi


if [ $SCRIPTED -eq 0 ]; then
	echo
	echo -n "CONTINUE? [y/N] "
	read
	if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
		echo "Canceled."
		exit 0
	fi


	# Given a list of strings representing options, display each option
	# preceded by a number (1 to N), display a prompt, check input until
	# a valid number within the selection range is entered.
	selectN() {
		for ((i=1; i<=$#; i++)); do
			echo $i. ${!i}
		done
		echo
		REPLY=""
		while :
		do
			echo -n "SELECT 1-$#: "
			read
			if [[ $REPLY -ge 1 ]] && [[ $REPLY -le $# ]]; then
				return $REPLY
			fi
		done
	}



	echo -n "Enable boot-time read/write jumper? [y/N] "
	read
	if [[ "$REPLY" =~ (yes|y|Y)$ ]]; then
		INSTALL_RW_JUMPER=1
		echo -n "GPIO pin for R/W jumper: "
		read
		RW_PIN=$REPLY
	fi

	echo -n "Install GPIO-halt utility? [y/N] "
	read
	if [[ "$REPLY" =~ (yes|y|Y)$ ]]; then
		INSTALL_HALT=1
		echo -n "GPIO pin for halt button: "
		read
		HALT_PIN=$REPLY
	fi

	echo -n "Enable kernel panic watchdog? [y/N] "
	read
	if [[ "$REPLY" =~ (yes|y|Y)$ ]]; then
		INSTALL_WATCHDOG=1
		echo "Target system type:"
		selectN "${SYS_TYPES[0]}" \
			"${SYS_TYPES[1]}"
		WD_TARGET=$?
	fi


	echo -n "Actually make system read only? If you choose no, the system will \n disable unnecessary disk writes,\n but will still have a writable FS [y/N] "
	read
	if [[ "$REPLY" =~ (yes|y|Y)$ ]]; then
		ACTUALLY_RO=1
	fi

#End interactive setup part
fi

# VERIFY SELECTIONS BEFORE CONTINUING --------------------------------------

echo
if [ $INSTALL_RW_JUMPER -eq 1 ]; then
	echo "Boot-time R/W jumper: YES (GPIO$RW_PIN)"
else
	echo "Boot-time R/W jumper: NO"
fi
if [ $INSTALL_HALT -eq 1 ]; then
	echo "Install GPIO-halt: YES (GPIO$HALT_PIN)"
else
	echo "Install GPIO-halt: NO"
fi
if [ $INSTALL_WATCHDOG -eq 1 ]; then
	echo "Enable watchdog: YES (${SYS_TYPES[WD_TARGET-1]})"
else
	echo "Enable watchdog: NO"
fi
echo

#Still display selections for logging and such,
#But don't do the prompt in scripted mode
if [ $SCRIPTED -eq 0 ]; then
	echo -n "CONTINUE? [y/N] "
	read
	if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
		echo "Canceled."
		exit 0
	fi
fi



# START INSTALL ------------------------------------------------------------
# All selections have been validated at this point...

# Given a filename, a regex pattern to match and a replacement string:
# Replace string if found, else no change.
# (# $1 = filename, $2 = pattern to match, $3 = replacement)
replace() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a replacement string:
# If found, perform replacement, else append file w/replacement on new line.
replaceAppend() {
	grep $2 $1 >/dev/null
	if [ $? -eq 0 ]; then
		# Pattern found; replace in file
		sed -i "s/$2/$3/g" $1 >/dev/null
	else
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append file with string on new line.
append1() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; append on new line (silently)
		echo $3 | sudo tee -a $1 >/dev/null
	fi
}

# Given a filename, a regex pattern to match and a string:
# If found, no change, else append space + string to last line --
# this is used for the single-line /boot/cmdline.txt file.
append2() {
	grep $2 $1 >/dev/null
	if [ $? -ne 0 ]; then
		# Not found; insert in file before EOF
		sed -i "s/\'/ $3/g" $1 >/dev/null
	fi
}

echo
echo "Starting installation..."
echo "Updating package index files..."
apt-get update

echo "Removing unwanted packages..."
#apt-get remove -y --force-yes --purge triggerhappy dbus \
# dphys-swapfile xserver-common lightdm fake-hwclock
# Let's keep dbus...that includes avahi-daemon, a la 'raspberrypi.local',
# also keeping xserver & lightdm for GUI login (WIP, not working yet)

#Also keeping logrotate, I'm just going to give it's config dir a tmpfs.
apt-get remove -y --force-yes --purge triggerhappy \
 dphys-swapfile fake-hwclock
apt-get -y --force-yes autoremove --purge

# Replace log management with busybox (use logread if needed)
echo "Installing ntp"

#Install NTP because timesyncd sucks
#However, don't override a user's choice of
#the arguably better but less common chrony.
if [ $(dpkg-query -W -f='${Status}' chrony 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
apt-get -y --force-yes install ntp ntpstat;
fi

#Copy over the modified hwclock-set.sh
cp hwclock-set.sh /lib/udev/hwclock-set

echo "Configuring system..."

# Install boot-time R/W jumper test if requested
GPIOTEST="gpio -g mode $RW_PIN up\n\
if [ \`gpio -g read $RW_PIN\` -eq 0 ] ; then\n\
\tmount -o remount,rw \/\n\
\tmount -o remount,rw \/boot\n\
fi\n"
if [ $INSTALL_RW_JUMPER -ne 0 ]; then
	apt-get install -y --force-yes wiringpi
	# Check if already present in rc.local:
	grep "gpio -g read" /etc/rc.local >/dev/null
	if [ $? -eq 0 ]; then
		# Already there, but make sure pin is correct:
		sed -i "s/^.*gpio\ -g\ read.*$/$GPIOTEST/g" /etc/rc.local >/dev/null

	else
		# Not there, insert before final 'exit 0'
		sed -i "s/^exit 0/$GPIOTEST\\nexit 0/g" /etc/rc.local >/dev/null
	fi
fi

# Install watchdog if requested
if [ $INSTALL_WATCHDOG -ne 0 ]; then
	apt-get install -y --force-yes watchdog
	# $MODULE is specific watchdog module name
	MODULE=${WATCHDOG_MODULES[($WD_TARGET-1)]}
	# Add to /etc/modules, update watchdog config file
	append1 /etc/modules $MODULE $MODULE
	replace /etc/watchdog.conf "#watchdog-device" "watchdog-device"
	replace /etc/watchdog.conf "#max-load-1" "max-load-1"
	# Start watchdog at system start and start right away
	# Raspbian Stretch needs this package installed first
	apt-get install -y --force-yes insserv
	insserv watchdog; /etc/init.d/watchdog start
	# Additional settings needed on Jessie
	append1 /lib/systemd/system/watchdog.service "WantedBy" "WantedBy=multi-user.target"
	systemctl enable watchdog
	# Set up automatic reboot in sysctl.conf
	replaceAppend /etc/sysctl.conf "^.*kernel.panic.*$" "kernel.panic = 10"
fi

# Install gpio-halt if requested
if [ $INSTALL_HALT -ne 0 ]; then
	apt-get install -y --force-yes wiringpi
	echo "Installing gpio-halt in /usr/local/bin..."
	cd /tmp
	curl -LO https://github.com/adafruit/Adafruit-GPIO-Halt/archive/master.zip
	unzip master.zip
	cd Adafruit-GPIO-Halt-master
	make
	mv gpio-halt /usr/local/bin
	cd ..
	rm -rf Adafruit-GPIO-Halt-master

	# Add gpio-halt to /rc.local:
	grep gpio-halt /etc/rc.local >/dev/null
	if [ $? -eq 0 ]; then
		# gpio-halt already in rc.local, but make sure correct:
		sed -i "s/^.*gpio-halt.*$/\/usr\/local\/bin\/gpio-halt $HALT_PIN \&/g" /etc/rc.local >/dev/null
	else
		# Insert gpio-halt into rc.local before final 'exit 0'
		sed -i "s/^exit 0/\/usr\/local\/bin\/gpio-halt $HALT_PIN \&\\nexit 0/g" /etc/rc.local >/dev/null
	fi
fi

#--------------------------------------------Make random numbers stay random
if [ ! -h /var/lib/systemd/random-seed ] ; then
#This one is actually kind of important for security, so we have a special service just for faking it.
rm -f /var/lib/systemd/random-seed
ln -s /run/random-seed /var/lib/systemd/random-seed
fi

if [ ! -h /var/lib/urandom/random-seed ] ; then
rm -fr /var/lib/urandom/random-seed
ln -s  /run/random-seed /var/lib/urandom/random-seed
fi

#This is a pregenerated block of randomness used to enhance the security of the randomness we generate at boot.
#This is really not needed, we generate enough at boot, but since we don't save any randomness at shutdown anymore,
#we might as well.
touch /etc/unique-random-supplement
chmod 700  /etc/unique-random-supplement
echo "Generating random numbers, this might be a while."

#Use hwrng if possible. If that exists, generate 128 bytes just because we can
if [ -e /dev/hwrng ] ; then
dd bs=1 count=256 if=/dev/hwrng  of=/etc/unique-random-supplement >/dev/null
else
dd bs=1 count=32 if=/dev/random  of=/etc/unique-random-supplement >/dev/null
fi
echo "Generated random numbers"

systemctl disable systemd-random-seed.service




####---------------------------Install boot script. This is our new entropy source-------------------

#Installl the readonly-random-seed service in systemd
cp -pf embedtools_service.sh /usr/bin/
cp -pf embedtools.service /etc/systemd/system
chmod 744 /usr/bin/embedtools_service.sh
chmod 744 /etc/systemd/system/embedtools.service

systemctl enable embedtools.service



###-----------------------------------------No systemd profiling storage stuff-----------------------
#Disable systemd services. We can keep the random seed one because we get there first and shim it.
systemctl disable systemd-readahead-collect.service
systemctl disable systemd-readahead-replay.service



# Add fastboot, noswap and/or ro to end of /boot/cmdline.txt
append2 /boot/cmdline.txt fastboot fastboot
append2 /boot/cmdline.txt noswap noswap

if [ $ACTUALLY_RO -eq 1 ]; then
append2 /boot/cmdline.txt ro^o^t ro
fi

# Move /var/spool to /tmp
rm -rf /var/spool
ln -s /tmp /var/spool

# Move /var/lib/lightdm and /var/cache/lightdm to /tmp
rm -rf /var/lib/lightdm
rm -rf /var/cache/lightdm
ln -s /tmp /var/lib/lightdm
ln -s /tmp /var/cache/lightdm

# Make SSH work
replaceAppend /etc/ssh/sshd_config "^.*UsePrivilegeSeparation.*$" "UsePrivilegeSeparation no"
# bbro method (not working in Jessie?):
#rmdir /var/run/sshd
#ln -s /tmp /var/run/sshd

# Change spool permissions in var.conf (rondie/Margaret fix)
replace /usr/lib/tmpfiles.d/var.conf "spool\s*0755" "spool 1777"

# Move dhcpd.resolv.conf to tmpfs
touch /tmp/dhcpcd.resolv.conf
rm /etc/resolv.conf
ln -s /tmp/dhcpcd.resolv.conf /etc/resolv.conf

#Set up symlinks in case we have dhcpcd5
if [ ! -h /var/lib/dhcpcd5 ] ; then
rm -r /var/lib/dhcpcd5
ln -s /var/lib/dhcp /var/lib/dhcpcd5
fi


# Make edits to fstab

##They should already have /run and /var/lock covered

# make / ro
# tmpfs /var/log tmpfs nodev,nosuid 0 0
# tmpfs /var/tmp tmpfs nodev,nosuid 0 0
# tmpfs /tmp     tmpfs nodev,nosuid 0 0

# and "just a few" a few others....

if [ $ACTUALLY_RO -eq 1 ]; then
replace /etc/fstab "vfat\s*defaults\s" "vfat    defaults,ro "
replace /etc/fstab "ext4\s*defaults,noatime\s" "ext4    defaults,noatime,ro "
fi


append1 /etc/fstab "/var/log" "tmpfs /var/log tmpfs nodev,nosuid,size=32M 0 0"
append1 /etc/fstab "/var/tmp" "tmpfs /var/tmp tmpfs nodev,nosuid,size=256M 0 0"
append1 /etc/fstab "\s/tmp"   "tmpfs /tmp    tmpfs nodev,nosuid,size=256M 0 0"


#NTP and Chrony are both valid choices. Can't really make people pick one....
mkdir -p /var/lib/ntp
append1 /etc/fstab "/var/lib/ntp" "tmpfs /var/lib/ntp tmpfs defaults,noatime,nosuid,nodev,noexec,size=1M 0 0"
mkdir -p /var/lib/chrony
append1 /etc/fstab "/var/lib/chrony" "tmpfs /var/lib/ntp tmpfs defaults,noatime,nosuid,nodev,noexec,size=1M 0 0"

#####Enable our replacement systemd RTC clock service
cp -pf rtcsync.sh /bin/
cp -pf rtcsync.service /etc/systemd/system
cp -pf rtcsync.timer /etc/systemd/system

chmod 744 /bin/rtcsync.sh
chmod 744 /etc/systemd/system/rtcsync.timer
chmod 744 /etc/systemd/system/rtcsync.service

systemctl enable rtcsync.timer
systemctl start rtcsync.timer

#We mayve don't need this anymore on systemD????
append1 /etc/fstab "/var/lib/urandom" "tmpfs /var/lib/urandom tmpfs defaults,noatime,nosuid,nodev,noexec,mode=700,size=1M 0 0"

#Keep logrotate. We want to clear old logs out of RAM
append1 /etc/fstab "/var/lib/logrotate" "tmpfs /var/lib/logrotate tmpfs defaults,noatime,nosuid,nodev,noexec,size=2M 0 0"

append1 /etc/fstab "/var/lib/sudo" "tmpfs /var/lib/sudo tmpfs defaults,noatime,nosuid,nodev,noexec,mode=700,size=2M 0 0"

mkdir -p /var/lib/pulse
append1 /etc/fstab "/var/lib/pulse" "tmpfs /var/lib/pulse tmpfs defaults,noatime,nosuid,nodev,noexec,mode=700,size=2M 0 0"






# PROMPT FOR REBOOT --------------------------------------------------------

echo "Done."
echo
echo "Settings take effect on next boot."
echo
echo -n "REBOOT NOW? [y/N] "


if [ $SCRIPTED -eq 0 ]; then
	read
	if [[ ! "$REPLY" =~ ^(yes|y|Y)$ ]]; then
		echo "Exiting without reboot."
		exit 0
	fi
fi

#Scripts can just handle reboot by themselves
if [ $SCRIPTED -eq 1 ]; then
	exit 0
fi

echo "Reboot started..."
reboot
exit 0