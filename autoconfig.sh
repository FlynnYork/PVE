#!/bin/bash
###参考
#pvevm-hooks PVE下KVM虚拟机直通钩子脚本
#https://gitee.com/hellozhing/pvevm-hooks
#[虚拟机相关] (2023.9.5)SHELL脚本：一键给PVE增加温度,cpu功耗频率,硬盘等信息
#https://www.right.com.cn/forum/thread-6754687-1-1.html
#pvetools
#https://github.com/ivanhao/pvetools/blob/master/pvetools.sh
###
echo "
##############################################
#一键脚本适配PVE8.1, Debian 12, windows11安装#
##############################################"


echo "
############
#更换镜像源#
############"
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
	echo '无需修改sources.list'
	
fi

#修改pve 5.x更新源地址为非订阅更新源，不使用企业订阅更新源。
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve/ bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
#修改ceph镜像更新源
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list
apt update

echo "安装网络工具包"
apt install -y git zip vim net-tools 

#添加无线网卡支持
apt install -y wpasupplicant

#添加lm-sensors 和 linux-cpupower 功耗频率温度
apt install -y lm-sensors linux-cpupower

echo "
####################################################
#PVE增加温度，cpu功耗频率，硬盘等信息，去除订阅提示#
####################################################"
(curl -Lf -o /tmp/temp.sh https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh || curl -Lf -o /tmp/temp.sh https://ghproxy.com/https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh) && chmod +x /tmp/temp.sh && /tmp/temp.sh remod

echo "开启硬件直通支持"
if [ `grep "intel_iommu=on" /etc/default/grub|wc -l` = 0 ];then
	iommu="intel_iommu=on iommu=pt"
	sed -i.bak "s|quiet|quiet $iommu|" /etc/default/grub
	#update-grub
else
	echo '无需修改/etc/default/grub'	
fi

#修改/etc/modules，添加以下内容（非必需，虚拟机直通时会自动加载相关模块）
#if [ `grep "vfio" /etc/modules|wc -l` = 0 ];then
#	cp /etc/modules /etc/modules.bak
#	cat <<EOF >> /etc/modules
#vfio
#vfio_iommu_type1
#vfio_pci
#vfio_virqfd
#EOF
#else
#	echo '无需修改/etc/modules'
#fi

echo "屏蔽Intel核显卡驱动（脚本使用pvevm-hooks不启用blacklist黑名单）"
if [ `grep 'i915$' /etc/modprobe.d/pve-blacklist.conf|wc -l` = 0 ];then
	cp /etc/modprobe.d/pve-blacklist.conf /etc/modprobe.d/pve-blacklist.conf.bak
	cat >>/etc/modprobe.d/pve-blacklist.conf<<EOF
#blacklist i915
#blacklist snd_hda_intel
#如果由于硬件不支持中断重新映射而导致传递失败，则可以考虑allow_unsafe_interrupts在虚拟机受信任时启用该选项。此选项默认是不启动的。
#options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF

else
	echo '无需修改pve-blacklist.conf'
	
fi

echo "上传核显直通rom"
wget -O /usr/share/kvm/4-14.rom https://cdn.jsdelivr.net/gh/FlynnYork/PVE@main/res/4-14.rom

echo "
###################
#创建windows虚拟机#
###################"
#wget -O /etc/pve/qemu-server/100.conf https://cdn.jsdelivr.net/gh/FlynnYork/PVE@main/res/100.conf

cat >/etc/pve/qemu-server/100.conf<<EOF
args: -set device.hostpci0.addr=02.0 -set device.hostpci0.x-igd-gms=0x2 -set device.hostpci0.x-igd-opregion=on
bios: ovmf
boot: order=ide2;sata0
cores: 4
cpu: host
hostpci0: 0000:00:02.0,legacy-igd=1,romfile=4-14.rom
hostpci1: 0000:00:1f.3
hostpci2: 0000:04:00.0
ide2: none,media=cdrom
machine: pc-i440fx-8.1
memory: 4096
meta: creation-qemu=8.1.2,ctime=1701934486
name: Windows11
net0: e1000=BC:24:11:24:B2:BB,bridge=vmbr0,firewall=1
net1: virtio=BC:24:11:D8:A8:5C,bridge=vmbr0,firewall=1
numa: 0
onboot: 1
ostype: win11
sata0: /dev/disk/by-id/nvme-Seagate_ZP1000GV30012_71V01700,size=976762584K
scsihw: virtio-scsi-single
smbios1: uuid=48a47df0-7641-4c73-ac44-e51f20e5dc5c
sockets: 1
usb0: host=0bda:b85b
usb1: host=0f39:1048
usb2: host=046d:c068
usb3: host=03f0:ae07
usb4: host=1e3d:8246
usb5: host=17ef:3838
vga: none
vmgenid: f00f8de2-1ef5-4567-b06a-65c587b37cdd
EOF

echo "
#############################
#配置pvevm-hooks直通钩子脚本#
#############################"
#克隆本仓库至/root目录
git clone https://gitee.com/hellozhing/pvevm-hooks.git
#添加可执行权限
cd pvevm-hooks && chmod a+x *.sh *.pl
#复制perl脚本至snippets目录
mkdir /var/lib/vz/snippets
cp hooks-igpupt.pl /var/lib/vz/snippets/hooks-igpupt.pl
#将钩子脚本应用至虚拟机
qm set 100 --hookscript local:snippets/hooks-igpupt.pl
echo "pvevm-hook已配置完"
#添加OVMF(UEFI)主板的EFI磁盘，未添加报警告WARN: no efidisk configured! Using temporary efivars disk.可不管
qm set 100 -efidisk0 local:100,format=qcow2,efitype=4m,pre-enrolled-keys=1
echo "已添加EFI Disk"
#更新grub和pve-blacklist
update-grub && update-initramfs -u -k all

echo "
################
#创建群晖虚拟机#
################"
cat >/etc/pve/qemu-server/101.conf<<EOF
#挂载img镜像为虚拟U盘引导
args: -device 'qemu-xhci,addr=0x18' -drive 'id=synoboot,file=/var/lib/vz/template/iso/rr_4GB.img,if=none,format=raw' -device 'usb-storage,id=synoboot,drive=synoboot,bootindex=1'
boot: order=ide2;net0
cores: 4
cpu: host
ide2: none,media=cdrom
memory: 2048
meta: creation-qemu=8.1.2,ctime=1702061642
name: SA6400
net0: virtio=BC:24:11:CE:F6:8D,bridge=vmbr0,firewall=1
numa: 0
ostype: l26
scsihw: virtio-scsi-single
smbios1: uuid=8a8cecf1-48a6-4574-9657-88694c60d4ba
sockets: 1
vmgenid: b0dd6244-a6ca-4896-99af-d0eb07798e87
EOF

echo "安装完成，请重启"













