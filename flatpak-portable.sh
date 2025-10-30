#!/bin/bash
set -xe

#Pull down and compile flatpak-1.16.1
prefix=/opt/flatpak
out=flatpak-1.16.1-$(dpkg --print-architecture).tar
makedeb=0
rm -rf flatpak-1.16.1 flatpak-1.16.1.tar.xz .tmp
wget https://github.com/flatpak/flatpak/releases/download/1.16.1/flatpak-1.16.1.tar.xz
tar -xvf flatpak-1.16.1.tar.xz
cd flatpak-1.16.1
meson setup --prefix=$prefix builddir
ninja -C builddir
#sudo ninja -C builddir install
cd ..

#List of executables to package
f1=flatpak-1.16.1/builddir/app/flatpak
f2=flatpak-1.16.1/builddir/subprojects/bubblewrap/flatpak-bwrap
f3=flatpak-1.16.1/builddir/subprojects/dbus-proxy/flatpak-dbus-proxy
f4=flatpak-1.16.1/builddir/portal/flatpak-portal

#Fetch the interpreter
int=$(realpath $(lddtree flatpak-1.16.1/builddir/app/flatpak | grep '(interpreter' | sed -e 's/.*=>//' -e 's/)//' -e 's/ //'))

#Grab all the dependencies
mkdir -p .tmp/lib/ .tmp/run/
files="$(lddtree $f1 $f2 $f3 $f4 | grep -v interpreter | sed 's/.*=>//' | xargs)"
files="$files $(ldd flatpak-1.16.1/builddir/app/flatpak | grep ld-linux | sed 's/(.*//' | xargs)"
cd .tmp/lib/
iter=1
while true
do
	f=$(echo $files | cut -d' ' -f $iter)
	if [ "$f" == "" ]
	then
		break
	fi
	cp $(realpath $f) $(basename $f)
	iter=$((iter+1))
done
files="$f1 $f2 $f3 $f4"
cd ..
cp ../$f1 run/
cp ../$f2 run/
cp ../$f3 run/
cp ../$f4 run/

#Create wrappers and patches
iter=1
while true
do
	echo $f
	f=$(echo $files | cut -d' ' -f $iter)
	if [ "$f" == "" ]
	then
		break
	fi
	f=$(basename $f)
	echo '
#define _GNU_SOURCE
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>  // for basename()

int main(int argc, char *argv[]) {
    // Determine target basename from argv[0]
    char *self_copy = strdup(argv[0]);
    if (!self_copy) return 1;
    char *base = basename(self_copy);

    // Construct target path: "'$prefix$'/run/" + basename
    char target[4096];
    if (snprintf(target, sizeof(target), "'$prefix'/run/%s", base) >= (int)sizeof(target)) {
        free(self_copy);
        return 1; // path too long
    }
    free(self_copy);

    // Build new argv: [target, argv[1], ..., NULL]
    char **new_argv = malloc((argc + 1) * sizeof(char *));
    if (!new_argv) return 1;
    new_argv[0] = target;
    for (int i = 1; i < argc; ++i) {
        new_argv[i] = argv[i];
    }
    new_argv[argc] = NULL;

    // Set LD_LIBRARY_PATH
    setenv("LD_LIBRARY_PATH", "'$prefix'/lib/", 1);

    // Execute directly
    execv(target, new_argv);

    // execv failed
    return 1;
}
'>$f.c
	mkdir -p libexec/ bin/
	if [ "$f" == "flatpak" ]
	then
		gcc $f.c -o bin/$f -static
	else
		gcc $f.c -o libexec/$f -static
	fi
	rm $f.c
	echo patchelf --set-interpreter $prefix/lib/$(basename $int) run/$f
	patchelf --set-interpreter $prefix/lib/$(basename $int) run/$f
	iter=$((iter+1))
done

#Create the repo
mkdir -p var/lib/flatpak/repo/tmp var/lib/flatpak/repo/objects
echo '[core]
repo_version=1
mode=bare-user-only
min-free-space-size=500MB
'>var/lib/flatpak/repo/config

#Cleanup
tar -cvf $out *
mv $out ..
cd ..
rm -rf .tmp flatpak-1.16.1 flatpak-1.16.1.tar.xz

#Make DEB package [Optional]
if [ "$makedeb" == "1" ]
then

mkdir -p .tmp/DEBIAN/
echo 'Package: flatpak
Version: 1.16.1
Section: utils
Priority: optional
Architecture: '$(dpkg --print-architecture)'
Depends:
Maintainer: flatpak-portable.sh
Description: Built with flatpak-portable.sh
'>.tmp/DEBIAN/control

echo '
if [ -f /etc/bash.bashrc ]
then
	p=$(stat -c '\''%a'\'' /etc/bash.bashrc)
else
	p=644
fi
f=$(mktemp)
cat /etc/bash.bashrc | grep -v '\''PATH=$PATH:'$prefix'/bin:'$prefix'/libexec'\'' > $f
mv $f /etc/bash.bashrc
chmod $p /etc/bash.bashrc
echo '\''PATH=$PATH:'$prefix'/bin:'$prefix'/libexec'\'' >> /etc/bash.bashrc
'>.tmp/DEBIAN/postinst
cat .tmp/DEBIAN/postinst | grep -v echo > .tmp/DEBIAN/postrm
echo '
users=$(ls /home | xargs)
count=$(echo $users | awk '\''{print NF}'\'')
countp1=$(($count+1))
iter=1
while [ "$iter" != "$countp1" ]
do
        user=$(echo $users | cut -d " " -f $iter)
        echo '\''[Unit]
Description=Flatpak Portal

[Service]
Type=simple
ExecStart='$prefix'/libexec/flatpak-portal -r
Restart=always

[Install]
WantedBy=default.target
'\''>/home/$user/.config/systemd/user/flatpak-portal.service
        iter=$(($iter+1))
done
'>>.tmp/DEBIAN/postinst
echo "rm -f /home/*/.config/systemd/user/flatpak-portal.service">>.tmp/DEBIAN/postrm

chmod 0775 .tmp/DEBIAN/postinst .tmp/DEBIAN/postrm
mkdir -p .tmp$prefix
tar -xvf $out -C .tmp$prefix
pwd
dpkg-deb --build .tmp $(echo $out | sed 's/\.tar/\.deb/')
rm -rf .tmp

fi
