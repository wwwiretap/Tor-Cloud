# launch instance of canonical AMI Ubuntu 10.04 LTS (Lucid Lynx)
# we will use this image to build our Tor Cloud EBS instance
# Install ec2-api-tools first! https://help.ubuntu.com/community/EC2StartersGuide
# apt-get install ec2-api-tools
# Define static variables for the build machine:

iid=
zone=us-east-1b
region=us-east-1
host=

relaytype="$1";

if [ -n "$relaytype" ]; then
        echo "Starting ..."
else
        echo "You must define bridge type first."
	exit
fi

# create and attached ebs volume to be used for snapshot
# volume size set to 4GB v.s 8GB (ubuntu ec2 default size)
# this should help save some EBS storage charges
ec2-create-volume --size 4 --availability-zone ${zone}
# fetch volume ID
vol=$(ec2-create-volume --size 4 --availability-zone ${zone} | awk {'print $2'})

# attache volume to build machine
ec2-attach-volume --instance ${iid} --device /dev/sdh ${vol}

# This is where the magic happens:
# 
# TODO: veridy checksum of: lucid-server-uec-i386.tar.gz
# ssh to build machine and run a bunch of commands:
# 	1. download http://uec-images.ubuntu.com/server/lucid/current/lucid-server-cloudimg-i386.tar.gz
#	2. extract & mount archive
#	3. add ioerror.sh and rc.local to the image
#	4. rsync image content to the 4GB EBS volume which is already attached
#	5. unmount 

# download the current lucid image
sudo chown ubuntu:ubuntu /mnt
cd /mnt
wget http://uec-images.ubuntu.com/server/lucid/current/lucid-server-cloudimg-i386.tar.gz -O /mnt/lucid-server-cloudimg-i386.tar.gz


# verify checksums
# fetch the signing key to the build machine (just once):  gpg --keyserver keyserver.ubuntu.com --recv-key 0x7DB87C81
wget http://uec-images.ubuntu.com/server/lucid/current/SHA256SUMS -O /mnt/SHA256SUMS
wget http://uec-images.ubuntu.com/server/lucid/current/SHA256SUMS.gpg -O /mnt/SHA256SUMS.gpg



#run gpg check
gpg --verify /mnt/SHA256SUMS.gpg /mnt/SHA256SUMS &> /mnt/verify.txt
checkpgp=$(cat /mnt/verify.txt  | grep Good | awk {'print $2'})


if [ "$checkpgp" = "Good" ]
then
	echo 'Verified.'
	tar -Sxvzf /mnt/lucid-server-cloudimg-i386.tar.gz
	mkdir /mnt/src /mnt/target
	sudo mount -o loop,rw /mnt/lucid-server-cloudimg-i386.img /mnt/src
	wget https://github.com/inf0/Tor-Cloud/raw/master/ec2-prep.sh -O /mnt/src/etc/ec2-pre.sh
	
	case "$relaytype" in
	'bridge')
	cat << EOF > /mnt/src/etc/rc.local
	#!/bin/sh -e
	/etc/ec2-prep.sh bridge
	exit 0
	EOF
	;;
	'privatebridge')
	cat << EOF > /mnt/src/etc/rc.local
	#!/bin/sh -e
	/etc/tor-installer.sh privatebridge
	exit 0
	EOF
	;;
	'middlerelay')
	cat << EOF > /mnt/src/etc/rc.local
	#!/bin/sh -e
	/etc/ec2-prep.sh middlerelay
	exit 0
	EOF
	;;
	esac

	chmod +x /mnt/src/etc/ec2-prep.sh
        chmod +x /mnt/src/etc/rc.local
	sudo mkfs.ext4 -F -L uec-rootfs /dev/sdh
	sudo mount /dev/sdh /mnt/target
	sudo rsync -aXHAS /mnt/src/ /mnt/target 
	sudo umount /mnt/target
	sudo umount /mnt/src

	#create snapshot of 4GB EBS volume we made above
	snap=$(ec2-create-snapshot ${vol} | awk {' print $2 '})
	#sleep for 15 seconds to complete the snapshot
	sleep 15
	#print results
	ec2-describe-snapshots ${snap}
else
	echo 'GPG verification failed.'
fi

# create snapshot of 4GB EBS volume we made above
snap=$(ec2-create-snapshot ${vol} | awk {' print $2 '})
# wait 10 seconds to compplte snapshot
sleep 10
# display results
ec2-describe-snapshots ${snap}

## Here we complete the process by regiestering our Image with Amazon!

# set the desired region
rel=lucid

# fetch the proper aki ID for our image
qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )
echo ${aki}

NOW=$(date +"%m-%d-%Y")
# Finally register the snapshot
ec2-register --snapshot ${snap} --architecture=i386 --kernel=${aki} --name "Tor-Cloud-EC2-${rel}-${zone}-${NOW}" --description "Tor Cloud - Private Bridege - Ubuntu 10.04.3 LTS [Lucid Lynx] - [${region}]"

# cleanup
ec2-detach-volume ${vol}
sleep 30
ec2-delete-volume ${vol}
#rm -rf /mnt/*


