#!/bin/bash
echo "ARCHEPLAY PRE-REQUISITES INSTALLATION BEGIN"
apt-get update
apt install awscli -y

git clone https://github.com/archeplay-automate/archeplay.git /archeplay

addgroup --system --gid 150 app
adduser --system --ingroup app --uid 150 app
usermod -a -G app
usermod -a -G admin app

snap download microk8s --channel=1.20/stable --target-directory=/archeplay
sudo snap ack microk8s_*.assert
sudo snap install microk8s_*.snap

mkdir /home/ubuntu/.kube
touch /home/ubuntu/.kube/config

chown -R  app:app /archeplay/

sed -i 's/first-found/interface=ens*/g' /archeplay/package/microk8s/upgrade-scripts/000-switch-to-calico/resources/calico.yaml
echo "changed calico"
sed -i 's/hostPort: 443/hostPort: 9443/g' /archeplay/package/microk8s/actions/ingress.yaml
echo "chaged ingress host port 443"
sed -i 's/hostPort: 80/hostPort: 9000/g' /archeplay/package/microk8s/actions/ingress.yaml
echo "chaged ingress host port 80"
machineip=`curl -s ifconfig.me`
echo $machineip
grep -v 'advertise-address' /archeplay/package/microk8s/default-args/kube-apiserver >  /archeplay/package/microk8s/default-args/kube-apiserver.new
mv  /archeplay/package/microk8s/default-args/kube-apiserver.new /archeplay/package/microk8s/default-args/kube-apiserver
echo "--advertise-address=$machineip" >> /archeplay/package/microk8s/default-args/kube-apiserver
echo "updated kube-apiserver "
echo "microk8s start"
snap try /archeplay/package/microk8s --classic
echo "microk8s installation complete"
usermod -a -G microk8s ubuntu
echo "enabling microk8s"
snap start --enable microk8s
echo "microk8s enable complete"
microk8s status --wait-ready
sleep 5
echo " enable addons "
microk8s enable dns storage registry ingress
echo "microk8s enabling"
microk8s status --wait-ready
snap alias microk8s.kubectl kubectl
echo "updating kubeconfig"
microk8s config > /home/ubuntu/.kube/config
chown -f -R ubuntu:ubuntu /home/ubuntu/.kube
echo "microk8s status check"
microk8s status --wait-ready
sleep 10

curl -fsSL https://get.docker.com -o /archeplay/package/get-docker.sh
sh /archeplay/package/get-docker.sh
usermod -aG docker ubuntu

docker network create archeplaynetwork --subnet 172.20.0.0/16 --gateway 172.20.0.1

docker run -d --net archeplaynetwork --restart=always --name ap-frontend public.ecr.aws/archeplay-dev/ap-frontend:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-designapi -e archedatapath="/home/app/web/archeplay/data" --volume /archeplay/data:/home/app/web/archeplay/data public.ecr.aws/archeplay-dev/ap-designapi:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-liveapi \
-e archeplaydatapath="/archeplay/data" -e archedatapath="/home/app/web/archeplay/data" \
-e imagemetaurl="https://raw.githubusercontent.com/archeplay-automate/ap-data-public/main/prod_metadata.json" \
-e kubeconfigpath="/home/ubuntu/.kube/config" \
--volume /home/ubuntu/.kube/config:/home/app/web/kubeconfig \
--volume /archeplay/data:/home/app/web/archeplay/data \
public.ecr.aws/archeplay-dev/ap-liveapi:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-datastore --volume /archeplay/data:/home/app/web/archeplay/data --volume /archeplay/secret:/home/app/web/archeplay/secret -e archedatapath="/home/app/web/archeplay/data" -e NETRC="/home/app/web/archeplay/secret/.netrc" public.ecr.aws/archeplay-dev/ap-datastore:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-publishapi -e archedatapath="/home/app/web/archeplay/data" --volume /archeplay/data:/home/app/web/archeplay/data public.ecr.aws/archeplay-dev/ap-publishapi:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-auth public.ecr.aws/archeplay-dev/ap-auth:2.2.0
docker run -d --net archeplaynetwork --restart=always --name ap-apigw -p 80:80 public.ecr.aws/archeplay-dev/ap-apigw:2.2.0
sleep 5

echo "ARCHEPLAY PRE-REQUISITES INSTALLED"