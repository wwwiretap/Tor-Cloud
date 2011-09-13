
Installation:

	1) Install ec2-api-tools on your laptop or build machine
	2) Generate and save your private keys:
		export EC2_PRIVATE_KEY=~/keys/pk.cert
		export EC2_CERT=~./keys/cert.pem
	3) Test your ec2-api-tools:
		root@inf0:~/Tor-Cloud# ec2-describe-regions 
		REGION  eu-west-1       ec2.eu-west-1.amazonaws.com
		REGION  us-east-1       ec2.us-east-1.amazonaws.com
		REGION  ap-northeast-1  ec2.ap-northeast-1.amazonaws.com
		REGION  us-west-1       ec2.us-west-1.amazonaws.com
		REGION  ap-southeast-1  ec2.ap-southeast-1.amazonaws.com

	4) Generate private keys for each region:
		for example: ec2-add-keypair --region us-east-1 tor-cloud-east-1
		and save the key in: ~/keys/tor-cloud-east-1.pem, don't forget to run chmod 600 ~/keys/*

		Your folder should look like this:
		root@inf0:~/Tor-Cloud# ls /home/architect/keys/ -lh
		-rw------- 1 root root 1.7K 2011-09-12 19:11 tor-cloud-ap-northeast-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:13 tor-cloud-ap-southeast-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:14 tor-cloud-eu-west-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:09 tor-cloud-us-east-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:09 tor-cloud-us-west-1.pem

	5) Create a Security Group called "tor-cloud-build" and allow SSH inbound traffic.

	6) You are now ready to build Bridge AMIs:
		For example, to build in "ap-southeast-1" region run:
		./build.sh bridge ap-southeast-1 /home/architect/keys/tor-cloud-ap-southeast-1.pem tor-cloud-ap-southeast-1

	TIP: You can run the build command for all the regions at the same time. Use screen or & to send the process to background!

	
		

		

		
