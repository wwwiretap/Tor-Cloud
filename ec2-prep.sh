#!/bin/bash
# ec2-prep by: Jacob Appelbaum
# git://git.torproject.org/ioerror/tor-cloud.git
# This is the code to run on an Ubuntu machine to prep it as a relay, bridge or
# private bridge
#
USER="`whoami`";
DISTRO="`lsb_release -c|cut -f2`";
SOURCES="/etc/apt/sources.list";
CONFIG="$1";
CONFIG_FILE="/etc/tor/torrc";
RESERVATION="`curl -m 5 http://169.254.169.254/latest/meta-data/reservation-id | sed 's/-//'`";

if [ "$USER" != "root" ]; then
echo "root required; re-run with sudo";
  exit 1;
fi

case "$CONFIG" in
   "bridge" ) echo "selecting $CONFIG config...";;
   "privatebridge" ) echo "selecting $CONFIG config...";;
   "middlerelay" ) echo "selecting $CONFIG config...";;
   * )
echo "You did not select a proper configuration: $CONFIG";
echo "Please try the following examples: ";
echo "$0 bridge";
echo "$0 privatebridge";
echo "$0 middlerelay";
exit 2;
    ;;
esac

echo "Adding Tor's repo for $DISTRO...";
cat << EOF >> $SOURCES
deb http://deb.torproject.org/torproject.org $DISTRO main
deb http://deb.torproject.org/torproject.org experimental-$DISTRO main
EOF

echo "Installing Tor's gpg key...";
gpg --keyserver keys.gnupg.net --recv 886DDD89
gpg --export A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89 | apt-key add -

echo "Installing Tor...";
aptitude safe-upgrade -y
apt-get -y install tor tor-geoipdb

echo "Configuring Tor...";
cp /etc/tor/torrc /etc/tor/torrc.bkp

if [ $CONFIG == "bridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
BridgeRelay 1
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

if [ $CONFIG == "private-bridge" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
BridgeRelay 1
PublishServerDescriptor 0
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

if [ $CONFIG == "middle-relay" ]; then
echo "Configuring Tor as a $CONFIG";
cat << EOF > $CONFIG_FILE
# Auto generated public Tor $CONFIG config file
Nickname ec2$CONFIG$RESERVATION
SocksPort 0
ORPort 443
DirPort 80
AccountingStart week 1 10:00
AccountingMax 10 GB
Exitpolicy reject *:*
EOF
fi

# XXX TODO
# Generally, we'll want to rm /var/lib/tor/* and remove all state from the system
echo "Restarting Tor...";
/etc/init.d/tor restart
sudo update-rc.d tor enable
echo "echo 'Tor Cloud Starting...'" > /etc/ec2-prep.sh

sudo reboot