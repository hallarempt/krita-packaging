FROM centos:6.9

MAINTAINER "Boudewijn Rempt <boudewijnrempt@users.noreply.github.com>"

RUN yum -y install epel-release
RUN yum -y update 
RUN yum -y install \
    wget tar bzip2 git libtool which fuse fuse-devel libpng-devel \
    automake libtool mesa-libEGL cppunit-devel cmake3 glibc-headers lbstdc++-devel \
    gcc-c++ freetype-devel fontconfig-devel libxml2-devel libstdc++-devel \
    libXrender-devel patch xcb-util-keysyms-devel libXi-devel \
    mesa-libGL-devel libxcb libxcb-devel xcb-util xcb-util-devel \
    qt5-qtbase-devel qt5-qtimageformats qt5-qtmultimedia-devel qt5-qtsvg-devel \
    qt5-qttools-devel qt5-qtx11extras-devel qt5-qtscript-devel qt5-concurrent-devel
RUN yum -y install centos-release-scl-rh 
RUN yum -y install devtoolset-3-gcc devtoolset-3-gcc-c++ devtoolset-3-binutils 
RUN groupadd --gid 1000 builder && useradd --uid 1000 --gid 1000 --comment "" builder
RUN install -d -o 1000 -g 1000 /workspace /out
ADD build-appimage.sh /build-appimage.sh

USER 0

