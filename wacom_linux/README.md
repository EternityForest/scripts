# Wacom linux fixes

Does your tablet stay in the clicked state of break your mouse pointer when you plug it in? You
probably have a bad threshold setting. Try this!

Put the config file in /etc/X11/xorg.conf.d(You mighth need to create the folder), logout, and log back in.

Currently this only works with the Wacom Bamboo, but I'm sure you can adapt it to others. Maybe make a pull request?