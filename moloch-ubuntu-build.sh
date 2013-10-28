#!/bin/sh
# Use this script to install OS dependencies, downloading and compile moloch dependencies, and compile moloch capture.

# This script will 
# * use apt-get/yum to install OS dependancies
# * download known working versions of moloch dependancies
# * build them statically 
# * configure moloch-capture to use them
# * build moloch-capture


YARA=1.7
PCAP=1.4.0
NIDS=1.24

TDIR="/data/moloch"
if [ "$#" -gt 0 ]; then
    TDIR="$1"
fi


# This scrip has been modified for ubuntu only
if [ "$(lsb_release -si)" != "Ubuntu" ]; then
  echo "Requires Ubuntu 12.04 or newer"
  exit 1
fi

# It has been based on Ubuntu 12.04 (current LTS) or greater
# if it was released sometime in 2012, we should be ok
if [ $(lsb_release -sr | cut -f 1 -d.) -lt 12 ]; then
  echo "Requires Ubuntu 12.04 or newer"
  exit 1
fi

apt_packages="git wget curl build-essential autoconf libpcre3-dev uuid-dev flex bison geoip-database-contrib \
libpng12-dev libgeoip-dev libglib2.0-dev libffi-dev libmagic-dev python-software-properties python-software-properties \
libhttp-message-perl libjson-perl libwww-perl"

## Your version may be different. Look for "Version:" in /var/lib/apt/lists/ppa.launchpad.net_chris-lea_node.js_[...]_Packages (ellipsised part of path varies with setup)
#sudo apt-get install nodejs=0.10.18-1chl1~precise1
echo "##### Installing apt dependancies #####"
echo " >> $apt_packages"
sudo apt-get -qq update
sudo apt-get -q install $apt_packages
if [ $? -ne 0 ]; then
  echo "MOLOCH - apt-get failed"
  exit 1
fi

echo "###### Adding PPA respositories ######"
sudo apt-get remove openjdk-7-jre
# Oracle Java
sudo add-apt-repository ppa:webupd8team/java
# Nodejs
if [ $(lsb_release -sr | cut -f 1 -d.) -lt 13 ];
then
	sudo add-apt-repository ppa:chris-lea/node.js
fi
sudo apt-get -qq update
sudo apt-get -q install oracle-java7-installer nodejs
if [ $? -ne 0 ]; then
  echo "MOLOCH - apt-get failed"
  exit 1
fi

echo "##### fetching codebase from git ######"
BUILDDIR=~/src
if [ ! -d $BUILDDIR ]; then
  mkdir $BUILDDIR
fi

cd $BUILDDIR
if [ ! -d "moloch" ]; then
  git clone https://github.com/aol/moloch.git
fi

echo "###### Downloading and building static thirdparty libraries ######"
# yara
if [ ! -f "yara-$YARA.tar.gz" ]; then
  wget http://yara-project.googlecode.com/files/yara-$YARA.tar.gz
fi
(tar zxf yara-$YARA.tar.gz && cd yara-$YARA && ./configure && make)
if [ $? -ne 0 ]; then
  echo "Yara install failed"
  exit 1
fi

# libpcap
if [ ! -f "libpcap-$PCAP.tar.gz" ]; then
  wget http://www.tcpdump.org/release/libpcap-$PCAP.tar.gz
fi
(tar zxf libpcap-$PCAP.tar.gz && cd libpcap-$PCAP && ./configure && make)
if [ $? -ne 0 ]; then
  echo "Libpcap install failed"
  exit 1
fi

# libnids
if [ ! -f "libnids-$NIDS.tar.gz" ]; then
  wget http://downloads.sourceforge.net/project/libnids/libnids/$NIDS/libnids-$NIDS.tar.gz
fi
tar zxf libnids-$NIDS.tar.gz
( cd libnids-$NIDS && ./configure --disable-libnet --with-libpcap=../libpcap-$PCAP && make)
if [ $? -ne 0 ]; then
  echo "Libnids install failed"
  exit 1
fi

# Now build moloch
cd moloch
echo "##### updating code from git #####"
git pull
echo "##### Building capture #####"
CONFIGURE_ARGS="--prefix=$TDIR --with-libpcap=$BUILDDIR/libpcap-$PCAP --with-libnids=$BUILDDIR/libnids-$NIDS --with-yara=$BUILDDIR/yara-$YARA"
echo $CONFIGURE_ARGS
./configure $CONFIGURE_ARGS && make
if [ $? -ne 0 ]; then
  echo "moloch build failed"
  exit 1
fi

