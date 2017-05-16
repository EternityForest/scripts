#This file should configure debian to write as little as possible to the sd card in a way that is mostly not visible to the user.
#We expect that /var/run and /var/lock are taken care of already
#This cannot be uninstalled or undone any way except manually or by writing your own uninstall script.

#This only works on systemd systems.

echo "Making the system write less to disk. This script might try to disable things that are already off, so you can probably ignore most of the errors."


ln -sf /proc/mounts /etc/mtab

#Turn off systemd's logging, if present
rm -fr /var/log/journal

if [ ! -h /etc/fake-hwclock.data ] ; then
#Symlink this weird fake hardware clock thing the pi uses
rm /etc/fake-hwclock.data
ln -s  /run/fake-hwclock.data /etc/fake-hwclock.data
fi

sudo apt-get remove -y fake-hwclock

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


if [ ! -h /var/lib/systemd/clock ] ; then
#This is for systemd's timesyncd thing
rm -f /var/lib/systemd/clock
ln -s /run/fake-hwclock.data /var/lib/systemd/clock
fi

#Everything that is a directory, we put a tmpfs right over the top of
if ! grep /var/log /etc/fstab
then
echo  "tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev,noexec,size=25M 0 0"  >> /etc/fstab
fi

if ! grep /tmp /etc/fstab
then
echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,noexec,size=300M 0 0" >> /etc/fstab
fi

if ! grep /var/lib/dhcp /etc/fstab
then
echo "tmpfs /var/lib/dhcp tmpfs defaults,noatime,nosuid,nodev,noexec,size=8M 0 0" >> /etc/fstab
fi

#We still need this even on systemd to handle people who install NTP for various reasons
if ! grep /var/lib/ntp /etc/fstab
then
echo "tmpfs /var/lib/ntp tmpfs defaults,noatime,nosuid,nodev,noexec,size=1M 0 0" >> /etc/fstab
fi

if ! grep /var/lib/urandom /etc/fstab
then
echo "tmpfs /var/lib/urandom tmpfs defaults,noatime,nosuid,nodev,noexec,mode=700,size=1M 0 0" >> /etc/fstab
fi

if ! grep /var/lib/logrotate /etc/fstab
then
echo "tmpfs /var/lib/logrotate tmpfs defaults,noatime,nosuid,nodev,noexec,size=2M 0 0" >> /etc/fstab
fi

#var/lib/sudo stores sudo timestamps so you don't have to retype it every time
if ! grep /var/lib/sudo /etc/fstab
then
echo "tmpfs /var/lib/sudo tmpfs defaults,noatime,nosuid,nodev,noexec,mode=700,size=2M 0 0" >> /etc/fstab
fi

#Why not, let's mount them right away.
mount -a

#Set up symlinks in case we have dhcpcd5
if [ ! -h /var/lib/dhcpcd5 ] ; then
rm -r /var/lib/dhcpcd5
ln -s /var/lib/dhcp /var/lib/dhcpcd5
fi

#Installl the readonly-random-seed service in systemd
chmod 744 readonly-random-seed
chmod 744 readonly-random-seed.service
cp -pf readonly-random-seed /usr/lib/
cp -pf readonly-random-seed.service /etc/systemd/system
systemctl enable readonly-random-seed.service


#Installl the apache-shim service in systemd
chmod 744 apache-shim
chmod 744 apache-shim.service
cp -pf apache-shim /usr/lib/
cp -pf apache-shim.service /etc/systemd/system
systemctl enable apache-shim.service


#Disable the builtin systemd random seed, we don't need that
systemctl disable systemd-random-seed.service

# #What is swap doing on a ram system? Comment this out if you actually do need swap.
swapoff -a
yes | apt-get purge -y dphys-swapfile dphys-config

#Disable systemd services. We can keep the random seed one because we get there first and shim it.
systemctl disable systemd-readahead-collect.service
systemctl disable systemd-readahead-replay.service

