# EmbedTools

Scripts to configure raspbian for use in embedded systems. Replaces the old readonlyhelper.

WORK IN PROGRESS. MOSTLY UNTESTED. THE OLD SCRIPT IS GONE BECAUSE IT BROKE NEWER RASPBIANS.


## Use
Run embedtools.sh and follow the prompts. Many features are inherited from the original
https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/ script.


Unless you tell it to, it will NOT actually make the system read only. It will
however majorly reduce unnecesary writes, and set things up to work correctly if you do
make it read only.

As in the original script, it's going to let you set up a GPIO pin to power off, 
config the watchdog, etc.

There is NO uninstaller for any of this.

## Scripted use
Use these command  flags:
 -s: scripted mode, no interactive prompts
 -j: Use the RW jumper 
 -p: Pi version(1: Zero W or pi 3, 2: anything else)
 -h: Install GPIO halt
 -r: Actually make the system read only
 -w: Enable the watchdog timer

You must reboot manually  in your script if you want to reboot after
## Adding a real time clock

This script adds services to handle that automatically, including keeping it synced with
NTP or Chrony
All you have to do is add a line like:

`dtoverlay=i2c-rtc,ds3231`

to /boot/config.txt. You may also need to enable i2c, with the config tool,
or by uncommenting `dtaparam=i2c_arm=on`.


Don't bother with any of the oter steps in the usual tutorials,
they will probably break something.


## What it Does

* Disables timesyncd's hourly writing of the current time(and fake-hwclock too)
  Note: without a RTC, you will have times that appear to go backwards until
  NTP syncs.
  
* Disables dphys-swapfile if present which disables swap completey on raspbian
* Stops the system from saving any entropy on boot. 
  That's kinda important, so we have to generate entropy at boot(currently 32 bytes) which
  takes a long time if there is no HWRNG. Maybe even a few minutes. If /dev/hwrng is available, 
  it will instead generate 256 hardware random bytes at boot almost instantly.
* Saves the sudo timestamps in a tmpfs owned by root
* puts a tmpfs over logrotate's state dir, dhcp and dhcpcd5's state dir, tmp, and /var/log/
* Disables systemd's logging
* Creates a log file in the tmpfs at boot so apache doesn't refuse to start(Note: that was years ago and might have been fixed by now)
* Disables systemd-readahead-collect.service and systemd-readahead-replay.service
* Ensure /etc/mtab is a symlink /proc/mounts
* Adds a service that keeps the RTC synced to the system clock, but only if we are synced with NTP or Chrony
* Installs NTP
* A few other related things inherited from adafruit


## What user_readonly_helper.sh does

* Symlinks .bash_history and .python_history to /dev/null 
