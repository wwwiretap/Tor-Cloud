# Copyright (c) 2011 Expression Technologies <info@expressiontech.org>
# Copyright (c) 2011 SiNA Rabbani <sina@expressiontech.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
# USA

# Tor CLoud Servers - http://expressiontech.org/torcloud
# Bundle and publish instance of canonical AMI Ubuntu 10.04 LTS (Lucid Lynx),
# modified to run as a Tor bridge relay, private relay or middle realy on Amazon EC2

# Define your Amazon credentials for ec2-api-tools to function
export EC2_PRIVATE_KEY=/home/architect/pk.cert
export EC2_CERT=/home/architect/cert.pem


relaytype=$1;
region=$2;
sshkey=$3;
keypair=$4
arch=i386

if [ -n "$relaytype" ]; then
        echo "Starting ..."
else
        echo "./build.sh bridge ap-southeast-1 /home/architect/keys/tor-cloud-ap-southeast-1.pem tor-cloud-ap-southeast-1"
	echo "(./build.sh relay-type region ssh-key ssh-keyname)"
        echo "get the list of regions using the ec2-api-tools: ec2-describe-regions"
        exit
fi


# get the associated AMI (amazon image) and AKI (amazon kernel) values for 
# the defined region & architecture. We only work with EBS instance types, as they are 
# elastic and easy to snapshot

echo ${region}
echo ${arch}

qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
curl --silent ${qurl} | grep ebs
ami=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $8 }' arch=$arch region=$region )
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )

echo ${ami}
echo ${aki}


iid=$(ec2-run-instances --region ${region} --instance-type t1.micro --key ${keypair}  ${ami} --group  tor-cloud-build| awk {'print $2'} | grep i-)
echo ${iid}
echo "sleeping for 45 seconds..."
sleep 45
zone=$(ec2-describe-instances --region ${region} $iid | awk '-F\t' '$2 == iid { print $12 }' iid=${iid} )
echo "sleeping for 20 seconds..."
echo ${zone}
echo "sleeping for 20 seconds..."
sleep 20
host=$(ec2-describe-instances --region ${region} $iid | awk '-F\t' '$2 == iid { print $4 }' iid=${iid} )
echo ${host}
echo "sleeping for 20 seconds..."
sleep 20

# create and attached ebs volume to be used for snapshot
vol=$(ec2-create-volume --size 4 --region ${region} --availability-zone ${zone} | awk {'print $2'})

sleep 20

ec2-attach-volume --instance ${iid} --region ${region} --device /dev/sdh ${vol}

sleep 20

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ${sshkey} ubuntu@${host} -q -t "sudo chown ubuntu:ubuntu /mnt && cd /mnt && wget http://uec-images.ubuntu.com/releases/10.04/release/ubuntu-10.04-server-uec-i386.tar.gz -O ubuntu-10.04-server-uec-i386.tar.gz && tar -Sxvzf /mnt/ubuntu-10.04-server-uec-i386.tar.gz && sudo mkdir src target && sudo mount -o loop,rw /mnt/lucid-server-uec-i386.img /mnt/src && sudo mkfs.ext4 -F -L uec-rootfs /dev/sdh && sudo mount /dev/sdh /mnt/target"

# TODO: fix GPG verification, exit on failed verification
#ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -t "gpg --verify /mnt/SHA256SUMS.gpg /mnt/SHA256SUMS &> /mnt/verify.txt && cat /mnt/verify.txt | grep Good | awk {'print $2'})"

# this is our startup file that loads tor-prep.sh on first boot
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i  ${sshkey}  ubuntu@${host} -q -v -t "sudo wget https://raw.github.com/inf0/Tor-Cloud/master/rc.local -O /mnt/src/etc/rc.local"

# this script is responsible for installation and configuration of the Tor application
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i  ${sshkey}  ubuntu@${host} -q -v -t "sudo wget https://raw.github.com/inf0/Tor-Cloud/master/ec2-prep.sh -O /mnt/src/etc/ec2-prep.sh"

# fix permissions
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i  ${sshkey}  ubuntu@${host} -q -v -t "sudo chmod +x /mnt/src/etc/ec2-prep.sh && sudo chmod +x /mnt/src/etc/ec2-prep.sh"

# rsync the retrieved Ubuntu image to mounted Volume
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i  ${sshkey}  ubuntu@${host} -q -v -t "sudo rsync -aXHAS /mnt/src/ /mnt/target"

# unmount volumes
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i  ${sshkey}  ubuntu@${host} -q -v -t "sudo umount /mnt/target && sudo umount /mnt/src"

# create a snapshot from Volume
snap=$(ec2-create-snapshot --region ${region} ${vol} | grep ${vol}  | awk {' print $2 '})

echo "ec2-describe-snapshots --region ${region}"
ec2-describe-snapshots --region ${region} 

# smarter sleep 

hold=$(ec2-describe-snapshots --region ${region} | grep ${snap}  | awk {'print $4}')
echo $hold

while [ "$hold" != "completed" ]
do
hold=$(ec2-describe-snapshots --region ${region} | grep ${snap}  | awk {'print $4}') && sleep 20
echo $hold
done


# create NOW and RANDOM variables to be used in the description field of the image
NOW=$(date +"%m-%d-%Y")
RANDOM=$(echo `</dev/urandom tr -dc A-Za-z0-9 | head -c8`)

ec2-register --region ${region} --snapshot ${snap} --architecture=i386 --kernel=${aki} --name "Tor-Cloud-EC2-${rel}-${region}-${NOW}-${RANDOM}" --description "Tor Cloud Server - [bridge] - Ubuntu 10.04.3 LTS [Lucid Lynx] - [${region}] by: expressiontech.org/torcloud"

# Finally register and publish the image
echo "ec2-register --region ${region}  --snapshot ${snap} --architecture=i386 --kernel=${aki} --name \"Tor-Cloud-EC2-${rel}-${region}-${NOW}-${RANDOM}\" --description \"Tor Cloud Server - [bridge] - Ubuntu 10.04.3 LTS [Lucid Lynx] - [${region}] by: expressiontech.org/torcloud\""

# cleanup
echo "ec2-detach-volume --region ${region}  ${vol}"
echo "ec2-terminate-instances --region ${region}  ${iid}"

