#!/bin/bash
cd /
git clone https://github.com/archeplay-automate/archeplay.git
snap download microk8s --channel=1.20/stable
snap download core
mkdir /archeplay/mountcp
sudo mount -t squashfs -o rw /archeplay/microk8s_2074.snap /archeplay/mountcp
cp -R /archeplay/mountcp/. /archeplay/package/microk8s
snap ack /archeplay/core_10908.assert
snap install /archeplay/core_10908.snap
umount /archeplay/mountcp/
rm -rf /archeplay/mountcp
rm /archeplay/core_10908.assert
rm /archeplay/core_10908.snap
mv /archeplay/microk8s_2074.snap /archeplay/package
mv /archeplay/microk8s_2074.assert /archeplay/package
apt-get update
apt install awscli -y
curl -fsSL https://get.docker.com -o /archeplay/package/get-docker.sh
sh /archeplay/package/get-docker.sh
usermod -aG docker ubuntu
mkdir /home/ubuntu/.kube
touch /home/ubuntu/.kube/config
docker network create archeplaynetwork --subnet 172.20.0.0/16 --gateway 172.20.0.1
sudo addgroup --system --gid 150 app
sudo adduser --system --ingroup app --uid 150 app
sudo usermod -a -G sudo app
sudo usermod -a -G admin app
sudo chown -R  app:app /archeplay/