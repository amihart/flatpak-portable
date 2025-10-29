#Flatpak Steam needs this
if [ "$UID" != "0" ]
then
        echo "You must run this script as root."
        exit
fi
wget https://raw.githubusercontent.com/ValveSoftware/steam-devices/refs/heads/master/60-steam-input.rules \
        -O /lib/udev/rules.d/60-steam-input.rules
wget https://raw.githubusercontent.com/ValveSoftware/steam-devices/refs/heads/master/60-steam-vr.rules \
        -O /lib/udev/rules.d/60-steam-vr.rules
udevadm control --reload-rules
udevadm trigger
