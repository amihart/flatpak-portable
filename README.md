# flatpak-portable
A script to package flatpak in a more portable fashion.

This script will compile flatpak 1.16.1. using the ```meson``` and ```ninja```. Make sure you can compile flatpak on your system without errors first before running the script. If it crashes while trying to compile flatpak, you probably have dependency issues, which you should resolve that prior to running the script. The three lines below should work independently of this script.

```
cd flatpak-1.16.1
meson setup --prefix=/ builddir
ninja -C builddir
```

If you can successfully build flatpak on your machine (and you have ```lddtree``` installed), then run the script. The script will compile flatpak and package it into a tarball called ```flatpak-portable.tar```.

We will distinguish between the client and host machine. The host compiles the portable version of Flatpak, and the client is the machine in which it will be deployed on.

After the host produces flatpak-portable.tar, the client can install it using the lines shown below.

```
sudo mkdir /opt/flatpak-portable
sudo chmod -R 777 /opt/flatpak-portable #unsure the ideal permissions
tar -xvf flatpak-portable.tar -C /opt/flatpak-portable
cat 'PATH=$PATH:/opt/flatpak-portable/bin/:/opt/flatpak-portable/libexec/' >> ~/.bashrc
```

Log out and log back in, and then you should be able to verify flatpak is available with ```flatpak --version```.

For Steam, you will want to also make sure are running ```flatpak-portal``` before launching Steam.

```
nohup flatpak-portal -r &
```

This script will package ALL of the dependencies for Flatpak used by the host machine, so the client should not need any additional dependencies in most cases (although Steam will ask for steam-devices which is needed controller support). This will even bring over glibc and the interpreter, so it does not matter if the client's glibc is outdated as the included wrappers will automatically launch flatpak with the glibc from the host machine and not the client.

### Debian

If you set the "makedeb" flag to 1 in the script, it will build a .DEB package. This package can be installed using the commands shown below.

```
sudo apt install ./flatpak-1.16.1-x86_64.deb
systemctl --user daemon-reload
systemctl --user enable flatpak-portal.service
```
