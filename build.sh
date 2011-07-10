# launch instance of canonical AMI Ubuntu 10.04 LTS (Lucid Lynx)
# we will use this image to build our Tor Cloud EBS instance

# run build machine instance
iid=$(ec2-run-instances --region us-east-1 --instance-type t1.micro --key inf0 ami-2cc83145 | awk {'print $2'} | grep i-)
echo ${iid}
sleep 5
zone=$(ec2-describe-instances $iid | awk '-F\t' '$2 == iid { print $12 }' iid=${iid} )
echo ${zone}
# wait for amazon IP assignment
sleep 20

# Fetch the hostname of buildmachine
host=$(ec2-describe-instances $iid | awk '-F\t' '$2 == iid { print $4 }' iid=${iid} )
echo ${host}

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
# 	1. download http://uec-images.ubuntu.com/server/lucid/current/lucid-server-uec-i386.tar.gz
#	2. extract & mount archive
#	3. add ioerror.sh and rc.local to the image
#	4. rsync image content to the 4GB EBS volume which is already attached
#	5. unmount 
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/inf0.pem ubuntu@${host} -q -v -t "sudo chown ubuntu:ubuntu /mnt && cd /mnt && sudo wget http://uec-images.ubuntu.com/server/lucid/current/lucid-server-uec-i386.tar.gz -O lucid-server-uec-i386.tar.gz && sudo tar -Sxvzf /mnt/lucid-server-uec-i386.tar.gz && mkdir src target && sudo mount -o loop,rw /mnt/lucid-server-uec-i386.img /mnt/src && sudo wget https://github.com/inf0/Tor-Cloud/raw/master/ioerror.sh -O /mnt/src/etc/ioerror.sh && sudo wget https://github.com/inf0/Tor-Cloud/raw/master/rc.local -O /mnt/src/etc/rc.local && sudo chmod +x /mnt/src/etc/ioerror.sh && sudo chmod +x /mnt/src/etc/rc.local && sudo mkfs.ext4 -F -L uec-rootfs /dev/sdh && sudo mount /dev/sdh /mnt/target && sudo rsync -aXHAS /mnt/src/ /mnt/target && sudo umount /mnt/target && sudo umount /mnt/src"

# back to localmachine
# create snapshot of 4GB EBS volume we made above
snap=$(ec2-create-snapshot ${vol} | awk {' print $2 '})
# wait 10 seconds to compplte snapshot
sleep 10
# display results
ec2-describe-snapshots ${snap}

# set bundle specs
# define region
region=us-east-1
# define architecture
# i386 is required for micro instances
arch=i386
# define linux version
rel=lucid
# link to fetch the proper aki ID for our image
qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )
echo ${aki}
# TODO: make this smarter, for now sleep 120 seconds
# crate a loop to bundle image for all regions
sleep 120
# Finally register the snapshot
ec2-register --snapshot ${snap} --architecture=i386 --kernel=${aki} --name "Tor-Cloud-EC2-${rel}-${zone}" --description "Amazon's Tor Cloud Instance-Ubuntu 10.04 - ${zone}"

# cleanup
ec2-detach-volume ${vol}
sleep 30
ec2-terminate-instances ${iid}
sleep 30
ec2-delete-volume ${vol}

