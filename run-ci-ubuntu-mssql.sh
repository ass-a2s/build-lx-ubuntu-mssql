#!/bin/bash

### LICENSE - (BSD 2-Clause) // ###
#
# Copyright (c) 2018, Daniel Plominski (ASS-Einrichtungssysteme GmbH)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or
# other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
### // LICENSE - (BSD 2-Clause) ###

### ### ### ASS // ### ### ###

#// get container ip address
GET_INTERFACE=$(netstat -rn | grep "0.0.0.0 " | grep "UG" | tr ' ' '\n' | tail -n 1)
GET_IPv4=$(ip addr show dev "$GET_INTERFACE" | grep "inet" | head -n 1 | awk '{print $2}')
GET_IPv6=$(ip addr show dev "$GET_INTERFACE" | grep "inet6" | head -n 1 | awk '{print $2}')

#// FUNCTION: spinner (Version 1.0)
spinner() {
   local pid=$1
   local delay=0.01
   local spinstr='|/-\'
   while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
         local temp=${spinstr#?}
         printf " [%c]  " "$spinstr"
         local spinstr=$temp${spinstr%"$temp"}
         sleep $delay
         printf "\b\b\b\b\b\b"
   done
   printf "    \b\b\b\b"
}

#// FUNCTION: run script as root (Version 1.0)
check_root_user() {
if [ "$(id -u)" != "0" ]; then
   echo "[ERROR] This script must be run as root" 1>&2
   exit 1
fi
}

#// FUNCTION: check state (Version 1.0)
check_hard() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;31mFAILED\033[0m\n")] '"$@"'"
   sleep 1
   exit 1
fi
}

#// FUNCTION: check state without exit (Version 1.0)
check_soft() {
if [ $? -eq 0 ]
then
   echo "[$(printf "\033[1;32m  OK  \033[0m\n")] '"$@"'"
else
   echo "[$(printf "\033[1;33mWARNING\033[0m\n")] '"$@"'"
   sleep 1
fi
}

#// FUNCTION: check state hidden (Version 1.0)
check_hidden_hard() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checkhard "$@"
   return 1
fi
}

#// FUNCTION: check state hidden without exit (Version 1.0)
check_hidden_soft() {
if [ $? -eq 0 ]
then
   return 0
else
   #/return 1
   checksoft "$@"
   return 1
fi
}

#// FUNCTION: set new ubuntu package sources
set_ubuntu_sources() {
sudo cat << "UBUNTUSOURCES" > ubuntu_xenial_sources
### ### ### ASS // ### ### ###

deb http://archive.ubuntu.com/ubuntu xenial main
deb-src http://archive.ubuntu.com/ubuntu xenial main
deb http://archive.ubuntu.com/ubuntu xenial-updates main
deb-src http://archive.ubuntu.com/ubuntu xenial-updates main
deb http://security.ubuntu.com/ubuntu xenial-security main
deb-src http://security.ubuntu.com/ubuntu xenial-security main

deb http://archive.ubuntu.com/ubuntu xenial universe
deb-src http://archive.ubuntu.com/ubuntu xenial universe
deb http://archive.ubuntu.com/ubuntu xenial-updates universe
deb-src http://archive.ubuntu.com/ubuntu xenial-updates universe
deb http://security.ubuntu.com/ubuntu xenial-security universe
deb-src http://security.ubuntu.com/ubuntu xenial-security universe

deb http://archive.ubuntu.com/ubuntu xenial multiverse
deb-src http://archive.ubuntu.com/ubuntu xenial multiverse
deb http://archive.ubuntu.com/ubuntu xenial-updates multiverse
deb-src http://archive.ubuntu.com/ubuntu xenial-updates multiverse
deb http://security.ubuntu.com/ubuntu xenial-security multiverse
deb-src http://security.ubuntu.com/ubuntu xenial-security multiverse

### ### ### // ASS ### ### ###
# EOF
UBUNTUSOURCES
   sudo cp -fv ubuntu_xenial_sources /etc/apt/sources.list
   sudo apt-get autoclean
   sudo apt-get clean
   sudo apt-get update
}

#// FUNCTION: package install
install_package() {
   sudo apt-get autoclean
   sudo apt-get clean
   sudo apt-get update
   sudo DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confold" install --yes --force-yes "$@"
}

#// FUNCTION: build nodirect_open module
build_nodirect_open() {
sudo cat << "NODIRECT" > nodirect_open.c
// nodirect_open.c by mic92
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
typedef int (*orig_open_f_type)(const char *pathname, int flags);
int open(const char *pathname, int flags, ...) {
   static orig_open_f_type orig_open;
   if (!orig_open) {
                   orig_open = (orig_open_f_type)dlsym(RTLD_NEXT, "open");
   }
   return orig_open(pathname, flags & ~O_DIRECT);
}
NODIRECT
   sudo cp -fv nodirect_open.c /nodirect_open.c
   sudo gcc -shared -fpic -o /nodirect_open.so /nodirect_open.c -ldl
   echo "/nodirect_open.so" > ld.so.preload
   sudo cp -fv ld.so.preload /etc/ld.so.preload
}

#// FUNCTION: install mssql
install_mssql() {
   wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
   sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/16.04/mssql-server-2017.list)"
   sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/16.04/prod.list)"
   sudo apt-get update
   sudo apt-get -y install mssql-server
   sudo ACCEPT_EULA=Y apt-get -y install mssql-tools unixodbc-dev
}

#// FUNCTION: install locales
install_locales() {
   sudo apt-get update
   sudo apt-get -y install locales
   sudo locale-gen en_US.UTF-8
   sudo update-locale LANG=en_US.UTF-8
}

#// FUNCTION: start service
start_service() {
   sudo systemctl start "$@"
   check_hard service start: "$@"
}

### RUN ###

set_ubuntu_sources
check_hard set_ubuntu_sources

install_package sudo less wget curl apt-transport-https
check_hard install: sudo less wget curl apt-transport-https

install_package gcc
check_hard install: gcc

build_nodirect_open
check_hard build: nodirect_open module

install_mssql
check_hard install: mssql

install_locales
check_hard install: locales

echo ""
echo "### ### ### ### ### ### ### ### ### ### ### ### ### ###"
echo "#                                                     #"
echo "  Container IPv4:      '$GET_IPv4'                     "
echo "  Container IPv6:      '$GET_IPv6'                     "
echo "#                                                     #"
echo "### ### ### ### ### ### ### ### ### ### ### ### ### ###"
echo ""

### ### ### // ASS ### ### ###
exit 0
# EOF
