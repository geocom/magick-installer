#!/bin/sh
#

#  magick_installer.sh    [ 0|1 [ /path/to/install/dir [ 0|1 ] ] ] 
#                            ^            ^               ^
#                            |            |               1 = build static, 0 = build shared (default)
#                            |            |
#                            |            change the installation path (default: /usr/local)
#                            |
#                            0 = dont ever use sudo, 1 = use sudo to install (default)
#

# ---- versions

         libiconv_version=1.13.1
         freetype_version=2.4.9
     libpng_major_version=15
           libpng_version=1.5.10
             jpeg_version=8d
          libtiff_version=4.0.1
           libwmf_version=0.2.8.4
             lcms_version=1.19
      ghostscript_version=9.05
ghostscript_fonts_version=8.11
      imagemagick_version=6.7.6-7



# ---- initial code

use_sudo="${1:-1}"
prefix="${2:-/usr/local}" 
static="${3:-0}" 
codec='-aes-256-cbc'

config_opts=''

set -e

password_on_sudo="`openssl rand -base64 96`"
password_salt_on_sudo="`openssl rand -hex 32`"



# ---- functions

function header() {
  echo "############################ ${@}"
}

function exit_trap() {
  rm -f "${build_root}/.sudopwd" >/dev/null 2>&1
  exit $1
}

# Obviously incompatible with pin entry, tokens, etc.
function save_sudo_password() {
  if [ -n "${sudo_pwd}" ]
  then
    echo 'Sudo password already saved.' >&2
    return
  fi

  read -rsp 'Password :' sudo_pwd

  # Make sure it basically works. 
  if ! echo "${sudo_pwd}" | sudo -n -S id >/dev/null 2>&1 
  then
    echo 'Unable to sudo :(' >&2
    false
  fi
  
  # Save it.
  umask_save="`umask`"
  umask 077
  trap 'exit_trap ${1}' EXIT
  echo "${sudo_pwd}" | openssl enc "${codec}"          \
                      -pass "pass:${password_on_sudo}" \
                      -S "${password_salt_on_sudo}"    \
                      -a -out "${build_root/.sudopwd}"
  umask "${umask_space}"
}

function unattended_sudo() {
  openssl enc -d "${codec}"            \
      -pass "pass:${password_on_sudo}" \
      -S "${password_salt_on_sudo}"    \
      -a -in "${build_root}/sudopwd"   \
  | sudo -S -n "${@}"
}

function _sudo() {
  if [[ "${use_sudo}" -eq 1 ]]
  then
    unattended_sudo "${@}"
  else # dont call the program with sudo
    prog="${1}" ; shift
    "${prog}" "${@}"
  fi
}

function _download() {
  url="${1}"
  base="$(basename ${1})"

  if [ ! -e "${base}" ]
  then
    echo "curling ${url}"
    curl -LO "${url}"
  fi
}

function extract() {
  tarball="${1}" 
  default_cd_dir="`echo ${tarball} | sed 's/\.tar\..*$//'`"
  cd_dir="${2:-${default_cd_dir}}" 

  header "${default_cd_dir}"
  test -d "${cd_dir}" || tar ${tar_opts}xf "${tarball}" 
  pushd "${cd_dir}" >/dev/null
}

function build() {
  ./configure --prefix="${prefix}" ${config_opts} ${@}
  make clean
  make
  _sudo make install
  popd >/dev/null
}

function extract_build() {
  extract "${1}" ; shift
  build "${@}"
}


# ---- main

build_root=/tmp/magick-installer
mkdir -p "${build_root}"
pushd "${build_root}" >/dev/null


# ---- downloads

_download http://ftp.gnu.org/pub/gnu/libiconv/libiconv-${libiconv_version}.tar.gz
_download http://nongnu.askapache.com/freetype/freetype-${freetype_version}.tar.gz
_download http://sourceforge.net/projects/libpng/files/libpng${libpng_major_version}/older-releases/${libpng_version}/libpng-${libpng_version}.tar.gz
_download http://www.imagemagick.org/download/delegates/jpegsrc.v${jpeg_version}.tar.gz
_download http://download.osgeo.org/libtiff/tiff-${libtiff_version}.tar.gz
_download http://voxel.dl.sourceforge.net/project/wvware/libwmf/${libwmf_version}/libwmf-${libwmf_version}.tar.gz
_download http://downloads.sourceforge.net/project/lcms/lcms/${lcms_version}/lcms-${lcms_version}.tar.gz
_download http://sourceforge.net/projects/ghostscript/files/GPL%20Ghostscript/${ghostscript_version}/ghostscript-${ghostscript_version}.tar.gz
_download http://voxel.dl.sourceforge.net/project/gs-fonts/gs-fonts/${ghostscript_fonts_version}%20%28base%2035%2C%20GPL%29/ghostscript-fonts-std-${ghostscript_fonts_version}.tar.gz
_download ftp://ftp.sunet.se/pub/multimedia/graphics/ImageMagick/ImageMagick-${imagemagick_version}.tar.gz


# ---- build and install

extract libiconv-${libiconv_version}.tar.gz libiconv-${libiconv_version}/libcharset
build

extract_build freetype-${freetype_version}.tar.gz

extract_build libpng-${libpng_version}.tar.gz 

extract jpegsrc.v${jpeg_version}.tar.gz jpeg-${jpeg_version}
glibtool="`which glibtool 2>/dev/null`"
test -x "${glibtool}"
ln -sf "${glibtool}" ./libtool
export MACOSX_DEPLOYMENT_TARGET=10.7
build

extract_build tiff-${libtiff_version}.tar.gz 

extract_build libwmf-${libwmf_version}.tar.gz 

extract_build lcms-${lcms_version}.tar.gz

extract_build ghostscript-${ghostscript_version}.tar.gz 

extract ghostscript-fonts-std-${ghostscript_fonts_version}.tar.gz fonts
_sudo mkdir -p "${prefix}/share/ghostscript/fonts"
_sudo mv -f * "${prefix}/share/ghostscript/fonts"
popd >/dev/null

export CPPFLAGS=-I"$prefix/include"
export LDFLAGS=-L"$prefix/lib"
extract_build ImageMagick-${imagemagick_version}.tar.gz                \
                                                                       \
                --disable-static                                       \
                --disable-opencl                                       \
                --without-fontconfig                                   \
                --with-modules                                         \
                --without-perl                                         \
                --without-magick-plus-plus                             \
                --with-quantum-depth=8                                 \
                --with-gs-font-dir="${prefix}/share/ghostscript/fonts" \
                --disable-openmp                                       \




# ---- escape build dir

popd >/dev/null
rm -Rf "${build_root}"



# ---- finished

echo "ImageMagick successfully installed!"
