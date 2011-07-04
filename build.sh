# launch instance of canonical AMI Ubuntu 10.04 LTS (Lucid Lynx)
# we will use this image to build our Tor Cloud EBS instance
iid=$(ec2-run-instances --region us-east-1 --instance-type t1.micro --key inf0 ami-2cc83145 | awk {'print $2'} | grep i-)
echo ${iid}
sleep 5
zone=$(ec2-describe-instances $iid | awk '-F\t' '$2 == iid { print $12 }' iid=${iid} )
echo ${zone}
sleep 20
host=$(ec2-describe-instances $iid | awk '-F\t' '$2 == iid { print $4 }' iid=${iid} )
echo ${host}

# create and attached ebs volume to be used for snapshot
ec2-create-volume --size 8 --availability-zone ${zone}
vol=$(ec2-create-volume --size 8 --availability-zone ${zone} | awk {'print $2'})
ec2-attach-volume --instance ${iid} --device /dev/sdh ${vol}


ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/inf0.pem ubuntu@${host} -q -v -t "sudo chown ubuntu:ubuntu /mnt && cd /mnt && sudo wget http://uec-images.ubuntu.com/releases/10.04/release/ubuntu-10.04-server-uec-i386.tar.gz -O ubuntu-10.04-server-uec-i386.tar.gz && sudo tar -Sxvzf /mnt/ubuntu-10.04-server-uec-i386.tar.gz && mkdir src target && sudo mount -o loop,ro /mnt/lucid-server-uec-i386.img /mnt/src && sudo wget https://github.com/inf0/Tor-Cloud/raw/master/ioerror.sh -O /etc/ioerror.sh && sudo wget https://github.com/inf0/Tor-Cloud/raw/master/rc.local -O /etc/rc.local && sudo mkfs.ext4 -F -L uec-rootfs /dev/sdh && sudo mount /dev/sdh /mnt/target && sudo rsync -aXHAS /mnt/src/ /mnt/target && sudo umount /mnt/target && sudo umount /mnt/src"

snap=$(ec2-create-snapshot ${vol} | awk {' print $2 '})
sleep 10
ec2-describe-snapshots ${snap}


rel=lucid
qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )
echo ${aki}
sleep 120 
ec2-register --snapshot ${snap} --architecture=i386 --kernel=${aki} --name "Tor-Cloud-EC2-${rel}-${zone}" --description "Amazon's Tor Cloud Instance-Ubuntu 10.04 - ${zone}"


#ec2-detach-volume ${vol}
#ec2-terminate-instances ${iid}
#ec2-delete-volume ${vol}

