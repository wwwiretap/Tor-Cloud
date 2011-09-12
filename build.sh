# launch instance of canonical AMI Ubuntu 10.04 LTS (Lucid Lynx)
# we will use this image to build our Tor Cloud EBS instance

export EC2_PRIVATE_KEY=/home/architect/pk.cert
export EC2_CERT=/home/architect/cert.pem



#REGION eu-west-1       ec2.eu-west-1.amazonaws.com
#REGION us-east-1       ec2.us-east-1.amazonaws.com
#REGION ap-northeast-1  ec2.ap-northeast-1.amazonaws.com
#REGION us-west-1       ec2.us-west-1.amazonaws.com
#REGION ap-southeast-1  ec2.ap-southeast-1.amazonaws.com

region=$2
arch=i386
relaytype=$1;

if [ -n "$relaytype" ]; then
        echo "Starting ..."
else
        echo "Try ./buil.sh bridge us-east-1 for US East region."
        echo "Note: only run 1 region per build."
        echo "Obtain a list of regions using the ec2-api-tools: ec2-describe-regions"
        exit
fi


# get Ubuntu's official AMI for the selected region, arch, instance type

echo ${region}
echo ${arch}

qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
curl --silent ${qurl} | grep ebs
ami=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $8 }' arch=$arch region=$region )

# we also need the associated kernel id
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )

echo ${ami}
echo ${aki}


iid=$(ec2-run-instances --region ${region} --instance-type t1.micro --key tor-cloud  ${ami} --group  tor-cloud-build| awk {'print $2'} | grep i-)
echo ${iid}
sleep 5
zone=$(ec2-describe-instances --region ${region} $iid | awk '-F\t' '$2 == iid { print $12 }' iid=${iid} )
echo ${zone}
sleep 20
host=$(ec2-describe-instances --region ${region} $iid | awk '-F\t' '$2 == iid { print $4 }' iid=${iid} )
echo ${host}

sleep 20

# create and attached ebs volume to be used for snapshot
vol=$(ec2-create-volume --size 4 --region ${region} --availability-zone ${zone} | awk {'print $2'})
ec2-attach-volume --instance ${iid} --region ${region} --device /dev/sdh ${vol}


ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -t "sudo chown ubuntu:ubuntu /mnt && cd /mnt && wget http://uec-images.ubuntu.com/releases/10.04/release/ubuntu-10.04-server-uec-i386.tar.gz -O ubuntu-10.04-server-uec-i386.tar.gz && tar -Sxvzf /mnt/ubuntu-10.04-server-uec-i386.tar.gz && mkdir src target && sudo mount -o loop,rw /mnt/lucid-server-uec-i386.img /mnt/src && sudo mkfs.ext4 -F -L uec-rootfs /dev/sdh && sudo mount /dev/sdh /mnt/target"

#ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -t "gpg --verify /mnt/SHA256SUMS.gpg /mnt/SHA256SUMS &> /mnt/verify.txt && cat /mnt/verify.txt | grep Good | awk {'print $2'})"


#breaks over ssh
#ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -t "sudo cat << EOF > /mnt/src/etc/rc.local
#!/bin/sh -e
#/etc/ec2-prep.sh bridge
#exit 0
#EOF"

sh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -v -t "sudo wget https://raw.github.com/inf0/Tor-Cloud/master/rc.local -O /mnt/src/etc/rc.local"



ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -v -t "sudo wget https://raw.github.com/inf0/Tor-Cloud/master/ec2-prep.sh -O /mnt/src/etc/ec2-prep.sh"

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -v -t "sudo chmod +x /mnt/src/etc/ec2-prep.sh && chmod +x /mnt/src/etc/ec2-prep.sh"

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -v -t "sudo rsync -aXHAS /mnt/src/ /mnt/target"

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no  -i ~/keys/tor-cloud.pem ubuntu@${host} -q -v -t "sudo umount /mnt/target && sudo umount /mnt/src"


snap=$(ec2-create-snapshot --region ${region} ${vol} | awk {' print $2 '})
sleep 80
ec2-describe-snapshots --region ${region} ${snap}
rel=lucid
qurl=http://uec-images.ubuntu.com/query/lucid/server/released.current.txt
aki=$(curl --silent "${qurl}" | awk '-F\t' '$5 == "ebs" && $6 == arch && $7 == region { print $9 }' arch=$arch region=$region )
echo ${aki}


NOW=$(date +"%m-%d-%Y")
RANDOM=$(echo `</dev/urandom tr -dc A-Za-z0-9 | head -c8`)
ec2-register --snapshot ${snap} --architecture=i386 --kernel=${aki} --name "Tor-Cloud-EC2-${rel}-${zone}-${NOW}-${RANDOM}" --description "Tor Cloud - Private Bridege - Ubuntu 10.04.3 LTS [Lucid Lynx] - [${region}]"


ec2-detach-volume ${vol}
sleep 20
ec2-terminate-instances ${iid}
sleep 20
ec2-delete-volume ${vol}

