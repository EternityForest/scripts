#!/bin/bash

#Generate 32 real hardware random bytes, plus we use 32
#Saved random bytes. I'm pretty sure this is enough entropy.
#16 bytes alone should be totally fine if the algorithms are good,

#If a hw rng is available, we use 256 generated bytes and a block of fixed saved bytes just because we can
#And also because we should probably not completely trust the hw rng
cat  /etc/unique-random-supplement > /dev/random > /dev/null

#If the on chip hwrng isn't random, this might actually help if there is a real RTC installed.
date +%s%N > /dev/random

if [ -e /dev/hwrng ] ; then
dd if=/dev/hwrng of=/dev/random bs=256 count=1 > /dev/null
else
dd if=/dev/random of=/dev/random bs=32 count=1 > /dev/null
fi

#HWRNG might have unpredictable timing, no reason not to use the timer again.
#Probably isn't helping much but maybe makes paranoid types feel better?
date +%s%N > /dev/random

#The RNG should already be well seeded, but the systemd thing needs to think its doing something
touch /var/lib/systemd/random-seed
touch /var/lib/urandom/random-seed
chmod 700 /var/lib/systemd/random-seed
chmod 700 /var/lib/urandom/random-seed
dd bs=1 count=32K if=/dev/urandom of=/var/lib/systemd/random-seed > /dev/null
dd bs=1 count=32K if=/dev/urandom of=/var/lib/urandom/random-seed > /dev/null
touch /run/cprng-seeded


###--------------------------------Apache shimming-----------------------------
#Only if var log is mounted a tmpfs.
if mount | grep "/var/log type tmpfs"; then

if [ ! -d /var/log/apache ] ; then
mkdir /var/log/apache
touch /var/log/apache/access.log
chmod 700 /var/log/apache/access.log

fi

if [ ! -d /var/log/apache2 ] ; then
mkdir /var/log/apache2
touch /var/log/apach2e/access.log
chmod 700 /var/log/apache2/access.log
fi
fi
