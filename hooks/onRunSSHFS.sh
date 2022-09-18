


#for 8.x
if [ -z "$VM_SSHFS_PKG" ]; then
  mount_psshfs host:work /Users/runner/work
else
  exit 1
fi
