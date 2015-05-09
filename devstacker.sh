#!/bin/bash

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 OPENSTACK_VERSION DEVSTACK_PASSWORD"
  echo "Example: $0 juno ajbk4389iuKjknab1"
  exit 1
fi

OPENSTACK_VERSION=$1
DEVSTACK_PASSWORD=$2

set -euo pipefail

IMAGE=`nova image-list | grep "Ubuntu 14.04 LTS (Trusty Tahr) (PVHVM)" | awk '{print $2}'`
echo "Image ID: $IMAGE"

FLAVOR=performance1-8
echo "Flavor ID: $FLAVOR"

SERVER_NAME=devstack-$OPENSTACK_VERSION
echo "Server Booting"
ID=`nova boot --poll --flavor $FLAVOR --image $IMAGE --key-name devstacker $SERVER_NAME | grep id | head -1 | awk '{print $4}'`
echo "Server Name: $SERVER_NAME"
echo "Server ID: $ID"

# Wait for ssh to start
sleep 10

IP=`nova show $ID | grep accessIPv4 | awk '{print $4}'`
echo "Server IP: $IP"

PRIVATE_KEY="$HOME/.ssh/id_rsa.devstacker"
USER="root"
OPTIONS="-i $PRIVATE_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o PasswordAuthentication=no"
SSH="ssh $OPTIONS $USER@$IP"

$SSH apt-get -y update
$SSH apt-get -y install git vim fail2ban unattended-upgrades
scp $OPTIONS 20auto-upgrades $USER@$IP:/etc/apt/apt.conf.d/

$SSH git clone https://github.com/openstack-dev/devstack.git -b stable/$OPENSTACK_VERSION devstack/
$SSH "devstack/tools/create-stack-user.sh"
$SSH mkdir /opt/stack/.ssh
$SSH cp /root/.ssh/authorized_keys /opt/stack/.ssh/
$SSH chown -R stack:stack /opt/stack/.ssh

USER="stack"
SSH="ssh $OPTIONS $USER@$IP"

$SSH git clone https://github.com/openstack-dev/devstack.git -b stable/$OPENSTACK_VERSION devstack/
cat local.conf.template | sed "s/OPENSTACK_VERSION/$OPENSTACK_VERSION/" | sed "s/DEVSTACK_PASSWORD/$DEVSTACK_PASSWORD/" > local.conf
scp $OPTIONS local.conf $USER@$IP:devstack/

$SSH "cd devstack && ./stack.sh"
