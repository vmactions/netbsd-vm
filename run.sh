#!/usr/bin/env bash

set -e

OVA_LINK="https://github.com/vmactions/netbsd-builder/releases/download/v0.0.1/netbsd-9.2.ova.zip"

CONF_LINK="https://raw.githubusercontent.com/vmactions/netbsd-builder/main/conf/netbsd-9.2.conf"


_script="$0"
_script_home="$(dirname "$_script")"


#everytime we cd to the script home
cd "$_script_home"


if [ ! -e "netbsd-9.2.conf" ]; then
  wget -q "$CONF_LINK"
fi

. netbsd-9.2.conf


##########################################################


export VM_OS_NAME

vmsh="$VM_VBOX"

if [ ! -e "$vmsh" ]; then
  wget "$VM_VBOX_LINK"
fi



osname="$VM_OS_NAME"
ostype="$VM_OS_TYPE"
sshport=$VM_SSH_PORT

ova="$VM_OVA_NAME.ova"
ovazip="$ova.zip"

ovafile="$ova"



importVM() {
  _idfile='~/.ssh/mac.id_rsa'

  bash $vmsh addSSHHost $osname $sshport $_idfile
  
  bash $vmsh setup
  
  if [ ! -e "$ovazip" ]; then
    wget "$OVA_LINK"
  fi
  
  if [ ! -e "$ovafile" ]; then
    7za e -y $ovazip  -o .
  fi
  
  bash $vmsh addSSHAuthorizedKeys id_rsa.pub

  cat mac.id_rsa >/Users/runner/.ssh/mac.id_rsa
  chmod 600 /Users/runner/.ssh/mac.id_rsa

  bash $vmsh importVM "$ovafile"


}










"$@"






















