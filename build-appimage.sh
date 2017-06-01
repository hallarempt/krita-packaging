#!/bin/bash

set -e

log() {
    tput setaf 2
    tput bold
    echo "#### $* ####"
    tput sgr0
}

OLD_CWD="$(pwd)"

export TERM=xterm-256color
export LC_ALL=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export SUDO_UID=${SUDO_UID:-1000}
export SUDO_GID=${SUDO_GID:-1000}

export APP=krita
export BRANCH=${BRANCH:-master}
export ARCH=${ARCH:-x86_64}
export REPO_URL=${REPO_URL:-git://anongit.kde.org/krita}
# parsed automatically unless they are already set
export VERSION
export COMMIT

WORKSPACE=$(readlink -f workspace)
export WORKSPACE
export APPDIR=$WORKSPACE/$APP.AppDir
export DOWNLOADS=$WORKSPACE/downloads
export BUILD=$WORKSPACE/build
export DEPS_BUILD=$WORKSPACE/depsbuild
export CHECKOUT=$WORKSPACE/checkout

notset="(parsed later from source code)"
log "VERSION: ${VERSION:-$notset} -- BRANCH: $BRANCH"


log "preparing environment"
mkdir -p "$APPDIR" "$DOWNLOADS" "$BUILD" "$CHECKOUT" "$DEPS_BUILD"

# Newer compiler than what comes with CentOS 6
. /opt/rh/devtoolset-3/enable


# Workaround for: On CentOS 6, .pc files in /usr/lib/pkgconfig are not recognized
# However, this is where .pc files get installed when bulding libraries... (FIXME)
# I found this by comparing the output of librevenge's "make install" command
# between Ubuntu and CentOS 6
ln -sf /usr/share/pkgconfig /usr/lib/pkgconfig

# if the library path doesn't point to our usr/lib, linking will be broken and we won't find all deps either
export LD_LIBRARY_PATH=/usr/lib64/:/usr/lib:$APPDIR/usr/lib:$APPDIR/usr/lib64


cd "$CHECKOUT"
log "cloning Krita repository"
git clone   --depth 1 "$REPO_URL" -n .

git checkout "${COMMIT:-$BRANCH}"

if [ "$VERSION" == "" ]; then
    VERSION="$(src/engine/version.h | grep VERSION_MAJOR | head -n1 | awk '{print $3}')"
    VERSION="$VERSION.$(grep VERSION_MINOR src/engine/version.h | head -n1 | awk '{print $3}')"
    VERSION="$VERSION.$(grep VERSION_PATCH src/engine/version.h | head -n1 | awk '{print $3}')"
fi

export VERSION

# fall back to HEAD when no commit is given
COMMIT=${COMMIT:-$(git rev-parse HEAD)}

# shorten commit if necessary
COMMIT=$(git rev-parse --short "$COMMIT")

export COMMIT


log "building dependencies from 3rdparty"
cd "$DEPS_BUILD"
cmake3 "${CHECKOUT}/3rdparty" \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DINSTALL_ROOT=/usr \
    -DEXTERNALS_DOWNLOAD_DIR="$DOWNLOADS"

# ext_qt ext_png  
for target in ext_openexr ext_boost ext_eigen3 ext_exiv2 ext_fftw3 ext_lcms2 ext_lcms2 \
              ext_ocio ext_vc ext_tiff ext_jpeg ext_libraw \
              ext_kcrash ext_poppler ext_gsl
do
    cmake3 --build . --config RelWithDebInfo --target $target
done


log "building Krita"
cd "$BUILD"
cmake3 "$CHECKOUT" \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DDEFINE_NO_DEPRECATED=1 \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DPACKAGERS_BUILD=1 \
    -DBUILD_TESTING=FALSE \
    -DKDE4_BUILD_TESTS=FALSE \
    -DPYQT_SIP_DIR_OVERRIDE=/usr/share/sip/\
    -DHAVE_MEMORY_LEAK_TRACKER=FALSE
    
make DESTDIR="$APPDIR" -j4 install

log "modifying global variables for AppImage tools"
export PATH=$APPDIR/usr/bin:$PATH
export LD_LIBRARY_PATH=$APPDIR/usr/lib:$LD_LIBRARY_PATH
export XDG_DATA_DIRS=$APPDIR/usr/share:$XDG_DATA_DIRS
export PKG_CONFIG_PATH=$APPDIR/usr/lib/pkgconfig:$PKG_CONFIG_PATH


cd "$APPDIR"

# Stuff that cannot be found by copy_deps
# copy the Python 3 installation
#cp -r /usr/lib/python3.5 usr/lib/
# copy sip
#cp -r /usr/sip usr/


log "deleting blacklisted libraries"
for file in libcom_err.so.2 libcrypt.so.1 libdl.so.2 libexpat.so.1 libgcc_s.so.1 \
            libglib-2.0.so.0 libgpg-error.so.0 libgssapi_krb5.so.2 libgssapi.so.3 \
            libhcrypto.so.4 libheimbase.so.1 libheimntlm.so.0 libhx509.so.5 libICE.so.6 \
            libidn.so.11 libk5crypto.so.3 libkeyutils.so.1 libkrb5.so.26 libkrb5.so.3 \
            libkrb5support.so.0 libm.so.6 libp11-kit.so.0 libpcre.so.3 libpthread.so.0 \
            libresolv.so.2 libroken.so.18 librt.so.1 libsasl2.so.2 libSM.so.6 \
            libusb-1.0.so.0 libuuid.so.1 libwind.so.0 \
            'libfontconfig.so.*' 'libGL.so.*' 'libdrm.so.*' 'libX11.so.*' 'libstdc*' \
            libxcb.so.1  cmake3 pkgconfig ECM gettext pkgconfig
do
    find usr/ -type f -iname "$file" -delete
done

cd "$WORKSPACE"
log "generating appimage"

[ ! -e "${OLD_CWD}/out" ] && mkdir -p "${OLD_CWD}/out"

# non-FUSE, simple replacement for generate_type2_appimage
wget -c "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage" 
chmod a+x linuxdeployqt-continuous-x86_64.AppImage
./linuxdeployqt-continuous-x86_64.AppImage --appimage-extract

#GLIBC_NEEDED=$(glibc_needed)
#APPIMAGE_FILENAME=${APP}-${VERSION}-${BRANCH}-${COMMIT}-${ARCH}.glibc$GLIBC_NEEDED.AppImage
APPIMAGE_FILENAME="${APP}-${VERSION}-${BRANCH}-${COMMIT}-${ARCH}.AppImage"
APPIMAGE_PATH="${OLD_CWD}/out/${APPIMAGE_FILENAME}"

URL="zsync|https://download.kde.org/krita/unstable/appimage/krita-${BRANCH}-x86_64.AppImage.zsync"

# FIXME: Might need to run twice; see https://github.com/probonopd/linuxdeployqt/issues/25
for _ in $(seq 1 2)
do
    squashfs-root/AppRun "${APPDIR}/usr/share/applications/org.kde.krita.desktop" -bundle-non-qt-libs -verbose=2
done

# TODO: -s for signing, needs a GPG2 key installed
squashfs-root/AppRun/usr/bin/appimagetool "$APPDIR" -u "$URL"

rm -r squashfs-root


log "fixing AppImage permissions"
chown "$SUDO_UID":"$SUDO_GID" "${OLD_CWD}/out/*.AppImage"
