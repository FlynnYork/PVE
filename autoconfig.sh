#!/bin/bash
###参考
#[虚拟机相关] (2023.9.5)SHELL脚本：一键给PVE增加温度,cpu功耗频率,硬盘等信息
#https://www.right.com.cn/forum/thread-6754687-1-1.html
#pvetools
#https://github.com/ivanhao/pvetools/blob/master/pvetools.sh
###
echo "========="
echo "适配PVE8.1, Debian 12"
echo "========="

echo "修改镜像源"
#备份源
cp /etc/apt/sources.list /etc/apt/sources.list.bak && cp /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak && cp /etc/apt/sources.list.d/ceph.list /etc/apt/sources.list.d/ceph.list.bak
#去除企业源
rm -rf /etc/apt/sources.list.d/pve-enterprise.list
#修改为ustc.edu.cn源
if [ `grep 'ustc.edu.cn' /etc/apt/sources.list|wc -l` = 0 ];then
	cat > /etc/apt/sources.list <<EOF
#默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
#deb-src https://mirrors.ustc.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
#deb-src https://mirrors.ustc.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
#deb-src https://mirrors.ustc.edu.cn/debian/ bookworm-backports main contrib non-free non-free-firmware
deb https://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
#deb-src https://mirrors.ustc.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
EOF
else
	echo 'do not need change sources.list'
	
fi

#修改pve 5.x更新源地址为非订阅更新源，不使用企业订阅更新源。
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve/ bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
#修改ceph镜像更新源
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list
apt update
####
####
####
echo "安装网络工具包 vim wpasupplicant"
apt install -y vim net-tools wpasupplicant
####
####
####
echo "PVE增加温度，cpu功耗频率，硬盘等信息，去除订阅提示"
(curl -Lf -o /tmp/temp.sh https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh || curl -Lf -o /tmp/temp.sh https://ghproxy.com/https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh) && chmod +x /tmp/temp.sh && /tmp/temp.sh remod
####
####
####
echo "开启硬件直通支持/etc/default/grub"
if [ `grep "intel_iommu=on" /etc/default/grub|wc -l` = 0 ];then
	iommu="intel_iommu=on iommu=pt"
	sed -i.bak "s|quiet|quiet $iommu|" /etc/default/grub
	#update-grub
	echo '/etc/default/grub has been changed'
else
	echo 'do not need change /etc/default/grub'	
fi
if [ `grep "vfio" /etc/modules|wc -l` = 0 ];then
	cp /etc/modules /etc/modules.bak
	cat <<EOF >> /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
EOF
else
	echo 'do not need change /etc/modules'
fi
####
####
####
echo "屏蔽Intel核显卡驱动"
if [ `grep '^blacklist i915$' /etc/modprobe.d/pve-blacklist.conf|wc -l` = 0 ];then
	cp /etc/modprobe.d/pve-blacklist.conf /etc/modprobe.d/pve-blacklist.conf.bak
	cat >>/etc/modprobe.d/pve-blacklist.conf<<EOF
blacklist i915
blacklist snd_hda_intel
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF

else
	echo 'do not need change pve-blacklist.conf'
	
fi
echo "上传核显直通rom"
wget -O /usr/share/kvm/4-14.rom https://cdn.jsdelivr.net/gh/FlynnYork/PVE@main/res/4-14.rom
echo "上传windows11虚拟机配置"
#wget -O /etc/pve/qemu-server/100.conf https://cdn.jsdelivr.net/gh/FlynnYork/PVE@main/res/100.conf
cat >/etc/pve/qemu-server/100.conf<<EOF
args: -set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on
vga: none
name: Windows11Pro
bios: ovmf
sockets: 1
cores: 4
cpu: host
ostype: win11
machine: pc-i440fx-8.1
memory: 4096
hostpci0: 0000:00:02.0,legacy-igd=1,romfile=4-14.rom
hostpci1: 0000:00:1f.3
hostpci2: 0000:04:00.0
hostpci3: 0000:00:17.0
usb0: host=0bda:b85b
usb1: host=0f39:1048
usb2: host=046d:c068
usb3: host=03f0:ae07
usb4: host=1e3d:8246
ide2: none,media=cdrom
sata0: /dev/disk/by-id/nvme-Seagate_ZP1000GV30012_71V01700,size=976762584K
boot: order=ide2;sata0
net0: e1000=BC:24:11:24:B2:BB,bridge=vmbr0,firewall=1
numa: 0
scsihw: virtio-scsi-single
meta: creation-qemu=8.1.2,ctime=1701934486
smbios1: uuid=48a47df0-7641-4c73-ac44-e51f20e5dc5c
vmgenid: f00f8de2-1ef5-4567-b06a-65c587b37cdd
EOF

echo "配置开机自启动"
qm set 100 --onboot 1

update-grub && update-initramfs -u -k all


echo "安装完成，请重启"
