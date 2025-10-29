#Flatpak Steam needs this
if [ "$UID" != "0" ]
then
        echo "You must run this script as root."
        exit
fi
wget https://raw.githubusercontent.com/ValveSoftware/steam-devices/refs/heads/master/60-steam-input.rules \
        -O /lib/udev/rules.d/60-steam-input.rules \
        --no-check-certificate
wget https://raw.githubusercontent.com/ValveSoftware/steam-devices/refs/heads/master/60-steam-vr.rules \
        -O /lib/udev/rules.d/60-steam-vr.rules \
        --no-check-certificate
udevadm control --reload-rules
udevadm trigger
