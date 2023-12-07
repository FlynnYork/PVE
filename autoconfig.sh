#!/bin/bash
###参考
#[虚拟机相关] (2023.9.5)SHELL脚本：一键给PVE增加温度,cpu功耗频率,硬盘等信息
#https://www.right.com.cn/forum/thread-6754687-1-1.html
#pvetools
#https://github.com/ivanhao/pvetools/blob/master/pvetools.sh
###
echo -e "============================================="
echo -e "============适配PVE8.1, Debian 12============"
echo -e ""=============================================""
echo -e "============PVE增加温度，cpu功耗频率，硬盘等信息，去除订阅提示============"
(curl -Lf -o /tmp/temp.sh https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh || curl -Lf -o /tmp/temp.sh https://ghproxy.com/https://raw.githubusercontent.com/a904055262/PVE-manager-status/main/showtempcpufreq.sh) && chmod +x /tmp/temp.sh && /tmp/temp.sh remod
####
####
####
echo -e "============修改镜像源============"
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
	echo -e 'do not need change sources.list'
	
fi

#修改pve 5.x更新源地址为非订阅更新源，不使用企业订阅更新源。
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/pve/ bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-sub.list
#修改ceph镜像更新源
echo "deb http://mirrors.ustc.edu.cn/proxmox/debian/ceph-reef bookworm no-subscription" > /etc/apt/sources.list.d/ceph.list
apt update
####
####
####
echo -e "============安装网络工具包 vim wpasupplicant============"
apt install -y vim net-tools wpasupplicant
####
####
####
echo -e "============开启硬件直通支持/etc/default/grub============"
if [ `grep "intel_iommu=on" /etc/default/grub|wc -l` = 0 ];then
	iommu="intel_iommu=on iommu=pt"
	sed -i.bak "s|quiet|quiet $iommu|" /etc/default/grub
	#update-grub
	echo -e '/etc/default/grub has been changed'
else
	echo -e 'do not need change /etc/default/grub'	
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
	echo -e 'do not need change /etc/modules'
fi
####
####
####
echo -e "============屏蔽Intel核显卡驱动============"
if [ `grep '^blacklist i915$' /etc/modprobe.d/pve-blacklist.conf|wc -l` = 0 ];then
	cp /etc/modprobe.d/pve-blacklist.conf /etc/modprobe.d/pve-blacklist.conf.bak
	cat >>/etc/modprobe.d/pve-blacklist.conf<<EOF
blacklist i915
blacklist snd_hda_intel
options vfio_iommu_type1 allow_unsafe_interrupts=1
EOF

else
	echo -e 'do not need change pve-blacklist.conf'
	
fi
update-grub && update-initramfs -u -k all


echo -e "============安装完成，请重启============"


















