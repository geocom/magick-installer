#!/bin/sh
set -e

use_sudo=${1:-1} # call this script with 0 to not use sudo
prefix="${2:-/usr/local}" # pass argument 2 of this script to change the installation prefix

password_on_sudo="`openssl rand -base64 96`"
password_salt_on_sudo="`openssl rand -hex 32'`"

function exit_trap() {
  rm -f $build_root/sudopwd >/dev/null 2>&1
  exit $1
}

# Obviously incompatible with pin entry, tokens, etc.
function save_sudo_password() {
  if [ -n "$sudo_pwd" ];
    echo 'Sudo password already saved.' >&2
    return
  fi

  read -rsp 'Password :' sudo_pwd

  # Make sure it basically works. 
  if ! echo $sudo_pwd | sudo -n -S id >/dev/null 2>&1 ; then
    echo 'Unable to sudo :(' >&2
    false
  fi
  
  # Save it.
  umask_save="`umask`"
  umask 077
  trap 'exit_trap $1' EXIT
  echo $sudo_pwd | openssl enc -aes-256-cbc \
                      -pass pass:$password_on_sudo \
                      -S $password_salt_on_sudo \
                      -a -out $build_root/sudopwd
  umask $umask_space
}

function unattended_sudo() {
  openssl enc -d -aes-256-cbc \
      -pass pass:$password_on_sudo \
      -S $password_salt_on_sudo \
      -a -in $build_root/sudopwd \
  | sudo -S -n "$@"
}

function _sudo() {
  if [[ $use_sudo -eq 1 ]]; then
    unattended_sudo "$@"
  else # dont call the program with sudo
    prog="$1" ; shift
    "$prog" "$@"
  fi
}

function download() {
  url=$1
  base=$(basename $1)

  if [[ ! -e $base ]]; then
    echo "curling $url"
    curl -O -L $url
  fi
}

mkdir magick-installer
cd magick-installer
build_root="`pwd`"

download http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.13.1.tar.gz
download http://nongnu.askapache.com/freetype/freetype-2.4.3.tar.gz
download http://sourceforge.net/projects/libpng/files/libpng15/older-releases/1.5.5/libpng-1.5.5.tar.gz
download http://www.imagemagick.org/download/delegates/jpegsrc.v8b.tar.gz
download http://download.osgeo.org/libtiff/tiff-3.9.4.tar.gz
download http://voxel.dl.sourceforge.net/project/wvware/libwmf/0.2.8.4/libwmf-0.2.8.4.tar.gz
download http://downloads.sourceforge.net/project/lcms/lcms/1.19/lcms-1.19.tar.gz
download http://sourceforge.net/projects/ghostscript/files/GPL%20Ghostscript/9.04/ghostscript-9.04.tar.gz
download http://voxel.dl.sourceforge.net/project/gs-fonts/gs-fonts/8.11%20%28base%2035%2C%20GPL%29/ghostscript-fonts-std-8.11.tar.gz
download ftp://ftp.sunet.se/pub/multimedia/graphics/ImageMagick/ImageMagick-6.6.7-0.tar.gz


tar xzvf libiconv-1.13.1.tar.gz
cd libiconv-1.13.1
cd libcharset
./configure --prefix="$prefix"
make
_sudo make install
cd ../..

tar xzvf freetype-2.4.3.tar.gz
cd freetype-2.4.3
./configure --prefix="$prefix"
make clean
make
_sudo make install
cd ..

tar xzvf libpng-1.5.5.tar.gz
cd libpng-1.5.5
./configure --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar xzvf jpegsrc.v8b.tar.gz
cd jpeg-8b
ln -s -f `which glibtool` ./libtool
export MACOSX_DEPLOYMENT_TARGET=10.7
./configure --enable-shared --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar xzvf tiff-3.9.4.tar.gz
cd tiff-3.9.4
./configure --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar xzvf libwmf-0.2.8.4.tar.gz
cd libwmf-0.2.8.4
./configure --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar xzvf lcms-1.19.tar.gz
cd lcms-1.19
./configure --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar zxvf ghostscript-9.04.tar.gz
cd ghostscript-9.04
./configure  --prefix="$prefix"
make clean
make
_sudo make install
cd ..


tar zxvf ghostscript-fonts-std-8.11.tar.gz
_sudo mkdir -p /usr/local/share/ghostscript/fonts
_sudo mv -f fonts/* /usr/local/share/ghostscript/fonts


tar xzvf ImageMagick-6.6.7-0.tar.gz
cd ImageMagick-6.6.7-0
export CPPFLAGS=-I"$prefix/include"
export LDFLAGS=-L"$prefix/lib"
./configure --prefix="$prefix" \
            --disable-static \
            --without-fontconfig \
            --with-modules \
            --without-perl \
            --without-magick-plus-plus \
            --with-quantum-depth=8 \
            --with-gs-font-dir="$prefix/share/ghostscript/fonts" \
            --disable-openmp
make clean
make
_sudo make install
cd ..

cd ..
rm -Rf magick-installer

echo "ImageMagick successfully installed!"
