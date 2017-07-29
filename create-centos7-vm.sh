name=$1
host=$2
passw=$3

HELP_INFO="Usage: $0 <vm-name> <vm host> <password>"

if [ -z $name ] || [ -z $host ] || [ -z $passw ]; then echo ${HELP_INFO} ; exit 1; fi

# openssl passwd -1 "password here" --> taken from https://thornelabs.net/2014/02/03/hash-roots-password-in-rhel-and-centos-kickstart-profiles.html
root_pass=$(openssl passwd -1 "${passw}")

cat <<EOT > /tmp/${name}.ks
# Kickstat file manually created by Neil Watson.
cmdline
install
text

#
# KS server TODO
#
url --url=http://ftp.linux.ncsu.edu/pub/CentOS/7/os/x86_64/
repo --name "CentOS 7" --baseurl=http://ftp.linux.ncsu.edu/pub/CentOS/7/os/x86_64/ --cost=100

#
# Language support TODO
#
lang en_US.UTF-8
keyboard us
firstboot --disable
poweroff

#
# Network settings TODO
#
network --device=eth0 --bootproto=dhcp  --hostname=${name}.${host}
# Not shown, but configure ipv6 in the %post section.

#
# Security TODO
#
rootpw --iscrypted ${root_pass}
user --name=jmeyer --password=${root_pass} --iscrypted

firewall --disabled
selinux --disabled
authconfig --enableshadow --enablemd5
#timezone America/Toronto
timezone --utc US/Eastern

#bootloader --location=mbr --append="console=tty0 console=ttyS0,115200 rd_NO_PLYMOUTH"
bootloader --location=mbr --append="rhgb quiet"
# Extra console bits probably not neeeded any more.
#bootloader --location=mbr --append="rhgb quiet console=tty0 console=ttyS0,115200n8"

#
# Users TODO
#
user --name=jj --password=${root_pass} --iscrypted


zerombr
clearpart --initlabel --all
# Do not configure the X Window System
skipx
part /boot --fstype ext4 --size=300 --ondisk=vda
part swap --size=200
part / --fstype ext4 --size=1 --grow

#
# Packages TODO
#
%packages --nobase
@core
wget
vim
unzip
acpid
logrotate
ntp
ntpdate
openssh-clients
rng-tools
rsync
screen
tmpwatch
wget
%end
%post
yum -y update
#curl -v -j -k -L -H "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/7u71-b14/jdk-7u71-linux-x64.rpm >>jdk-7u71-linux-x64.rpm
#rpm -ivh jdk-7u71-linux-x64.rpm
echo 'vm.swappiness  =  0'  >>  /etc/sysctl.conf || true
echo 'net.ipv4.tcp_retries2 = 2' >> /etc/sysctl.conf || true
echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf || true
echo 'net.core.somaxconn = 4096' >> /etc/sysctl.conf || true
echo 'echo never > /sys/kernel/mm/redhat_transparent_hugepage/enabled' >> /etc/rc.local || true
echo 'echo never > /sys/kernel/mm/redhat_transparent_hugepage/defrag' >> /etc/rc.local || true
echo "* soft nofile 32768" >> /etc/security/limits.conf || true
echo "* hard nofile 65536" >> /etc/security/limits.conf || true
echo "root soft nofile 32768" >> /etc/security/limits.conf || true
echo "root hard nofile 65536" >> /etc/security/limits.conf || true
echo "*  memlock unlimited" >>/etc/security/limits.conf || true
echo "*  core unlimited" >>/etc/security/limits.conf || true
echo "*  noproc unlimited" >>/etc/security/limits.conf || true
echo "*  nice -10" >>/etc/security/limits.conf || true
echo "*  renice -10" >>/etc/security/limits.conf || true
#echo "ttyS0" >> /etc/securetty || true
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux && cat /etc/sysconfig/selinux
systemctl enable ntpd || true
systemctl start ntpd || true

echo 'NETWORKING=yes' > /etc/sysconfig/network
echo 'HOSTNAME=${name}.${host}' >> /etc/sysconfig/network

hostname ${name}.${host}

#chvt 3

#
# SSH TODO
#

if [ "${name}" == 'node000' ] ;
then

cat <<IDRSAEOT > /root/enable-ssh.sh
ssh-keygen

hosts=(
node001
node002
node003
node004
node005
node006
node007
node008
node009
node010
)

for node in "\${hosts[@]}"
do
        ssh root@\${node} mkdir -p /root/.ssh
        cat /root/.ssh/id_rsa.pub | ssh root@\${node} 'cat >> /root/.ssh/authorized_keys'

        ssh root@\${node} chmod 700 /root/.ssh
        ssh root@\${node} chmod 600 /root/.ssh/authorized_keys
done

cat /root/.ssh/id_rsa.pub  >> /root/.ssh/authorized_keys

IDRSAEOT

chmod +x /root/enable-ssh.sh

fi

%end
EOT

/usr/bin/qemu-img create -f qcow2 -o preallocation=metadata /home/data/vm/images/$name.qcow2 46G
virt-install --connect=qemu:///system \
    --network=bridge:br0 \
    --initrd-inject=/tmp/${name}.ks \
    --extra-args="ks=file:/${name}.ks console=tty0 console=ttyS0,115200" \
    --name=${name} \
    --disk path=/home/data/vm/images/${name}.qcow2,format=qcow2 \
    --ram 4096 \
    --vcpus=1 \
    --hvm \
    --location=http://ftp.linux.ncsu.edu/pub/CentOS/7/os/x86_64/ \
    --nographics

