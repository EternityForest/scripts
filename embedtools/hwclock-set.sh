#!/bin/sh

#Embedtools replacement for hwclock-set on the raspberry pi

# Reset the System Clock to UTC if the hardware clock from which it
# was copied by the kernel was in localtime.

dev=$1


#If user sey up an i2c RTC, we comment out the lines as per
#Many internet tutorials that have more info on why.

#Otherwise, we just exit like usual on systemd
if grep -q "i2c-rtc" /boot/config.txt; then
else

    if [ -e /run/systemd/system ] ; then
        exit 0
    fi
fi

if [ -e /run/udev/hwclock-set ]; then
    exit 0
fi

if [ -f /etc/default/rcS ] ; then
    . /etc/default/rcS
fi

# These defaults are user-overridable in /etc/default/hwclock
BADYEAR=no
HWCLOCKACCESS=yes
HWCLOCKPARS=
HCTOSYS_DEVICE=rtc0
if [ -f /etc/default/hwclock ] ; then
    . /etc/default/hwclock
fi


#We do our own system time to RTC stuff.
#Because I'd rather not set the RTC at all
if [ yes = "$BADYEAR" ] ; then
    /bin/rtcsync.sh
    /sbin/hwclock --rtc=$dev --hctosys --badyear
else
    /bin/rtcsync.sh
    /sbin/hwclock --rtc=$dev --hctosys
fi

# Note 'touch' may not be available in initramfs
> /run/udev/hwclock-set
