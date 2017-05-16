# Readonly Helper

This is meant to reduce the SD card and disk writes that linux just does in the background
to the minimum possible without being noticable by users. It works on systemd based debian
and maybe other distros. 

This doesn't actually make your drive read only, but it helps. If you do set up read only mounting,
you might want to use this anyway because it does a few handy things for readonly systems.

You can't undo this script except manually, but it does seem to work well at protecting SD cards.

It can't completely block writes though, because when you mount a filesystem I'm pretty sure it actually
increments a mount count.

This is not a substitute for industrial SD cards in most cases and
is definitely not a substiture for regular backups of important data.


## How to use
To use it, copy the whole readonly_helper folder over, enter it, as root run the readonly_helper.sh file, 
and as your normal user run user_readonly_helper.sh

You might want to read the code first though, it's not that long and you might not want all of it.

## What it Does

* Disables timesyncd's hourly writing of the current time(and fake-hwclock too)
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

## What user_readonly_helper.h does

* Symlinks .bash_history and .python_history to /dev/null 
