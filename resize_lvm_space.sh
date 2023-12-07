#!/bin/bash
#You should first see how much space you have in all your storage volumes
lvdisplay
lsblk
# Remove pve-data logical volume.
lvremove /dev/pve/data -y

# Create it again with a new size.
#lvcreate -L 10G -n data pve -T

# Give pve-root all the other size.
lvresize -l +100%FREE /dev/pve/root

# Resize pve-root file system
resize2fs /dev/mapper/pve-root
lsblk
