#!/usr/bin/env bash

set -e

OVA_LINK="https://github.com/vmactions/netbsd-builder/releases/download/v0.0.1/netbsd-9.2.ova.zip"

CONF_LINK="https://raw.githubusercontent.com/vmactions/netbsd-builder/main/conf/netbsd-9.2.conf"

if [ !-e "netbsd-9.2.conf" ]; then
  wget "$CONF_LINK"
fi

. netbsd-9.2.conf


##########################################################


export VM_OS_NAME

$vmsh="$VM_VBOX"



osname="$VM_OS_NAME"
ostype="$VM_OS_TYPE"
sshport=$VM_SSH_PORT

ova="$VM_OVA_NAME.ova"
ovazip="$ova.zip"

ovafile="$ova"



getOSName() {
  echo "$osname"
}



importVM() {
  _idfile='~/.ssh/mac.id_rsa'

  $vmsh addSSHHost $osname $sshport $_idfile
  
  $vmsh setup
  
  if [ ! -e "$ovazip" ]; then
    wget "$ovazip"
  fi
  
  if [ ! -e "$ovafile" ]; then
    7za e -y $ovazip  -o .
  fi
  
  $vmsh addSSHAuthorizedKeys id_rsa.pub

  cat mac.id_rsa >/Users/runner/.ssh/mac.id_rsa
  chmod 600 /Users/runner/.ssh/mac.id_rsa

  $vmsh importVM "$ovafile"


}

































