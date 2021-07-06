#!/bin/bash
echo "ARCHEPLAY PRE-REQUISITES INSTALLATION BEGIN"
apt-get update
apt install awscli -y
if $? == 0
then
    echo "AWSCLI installed successfully"
else
    echo "AWSCLI installation failed"
fi

git clone https://github.com/archeplay-automate/archeplay.git /archeplay
if $? == 0
then
    echo "cloned archeplay successfully"
else
    echo "Archeplay directory failed to download"
fi
addgroup --system --gid 150 app
adduser --system --ingroup app --uid 150 app
usermod -a -G admin app

echo "microk8s start"
snap download microk8s --channel=1.20/stable --target-directory=/archeplay
snap ack /archeplay/microk8s_*.assert
snap install /archeplay/microk8s_*.snap --classic
if $? == 0
then
    echo "microk8s installed successfully"
else
    echo "microk8s installation failed"
fi
snap alias microk8s.kubectl kubectl
if [[ -d /home/ubuntu/.kube ]]
then
    echo "/home/ubuntu/.kube exists on your filesystem."
    if [[ -f "/home/ubuntu/.kube/config" ]]
    then
        echo "This file exists on your filesystem."
    else
        touch /home/ubuntu/.kube/config
        echo "kubeconfig created"
    fi
else
    mkdir /home/ubuntu/.kube
    if [[ -f "/home/ubuntu/.kube/config" ]]
    then
        echo "This file exists on your filesystem."
    else
        touch /home/ubuntu/.kube/config
        echo "kubeconfig created"
    fi
fi

chown -R  app:app /archeplay/

sed -i 's/first-found/interface=ens*/g' /var/snap/microk8s/current/args/cni-network/cni.yaml
echo "changed calico"
cp /snap/microk8s/current/actions/ingress.yaml /archeplay/package/
sed -i 's/hostPort: 443/hostPort: 9443/g' /archeplay/package/ingress.yaml
echo "chaged ingress host port 443"
sed -i 's/hostPort: 80/hostPort: 9000/g' /archeplay/package/ingress.yaml
echo "chaged ingress host port 80"
machineip=`curl -s ifconfig.me`
echo $machineip
grep -v 'advertise-address' /var/snap/microk8s/current/args/kube-apiserver >  /var/snap/microk8s/current/args/kube-apiserver.new
mv  /var/snap/microk8s/current/args/kube-apiserver.new /var/snap/microk8s/current/args/kube-apiserver
echo "--advertise-address=$machineip" >> /var/snap/microk8s/current/args/kube-apiserver
echo "updated kube-apiserver "

usermod -a -G microk8s ubuntu
microk8s status --wait-ready
sleep 5
echo "resetting microk8s"
microk8s reset
if $? == 0
then
    echo "microk8s reset successful"
else
    echo "microk8s reset failed"
fi
echo " enable addons "
microk8s enable dns storage registry

echo "enabling ingress"
kubectl apply -f /archeplay/package/ingress.yaml
if $? == 0
then
    echo "ingress enable successful"
else
    echo "ingress enable failed"
fi
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
