# Running a load balancer for RKE2 api-server and nginx ingress controller using Keepalived and HAProxy in static pods

## Prerequisites
This assumes you have a 6 node cluster, 3 masters and 3 agents, with all Rancher/RKE2 prerequisites completed

## Clone repo
Clone this repo, or copy the files needed manually
```
yum install -y git
git clone https://gist.github.com/5b696d202befde53c333761e23dca616.git
cd 5b696d202befde53c333761e23dca616/
```


## RKE2 Config
Install RKE2 as usual except don't start it. Ensure the configuration option for your RKE2 server nodes in `/etc/rancher/rke2/config.yaml` contains:
```yaml
node-taint: "CriticalAddonsOnly=true:NoExecute"
```
The node-taint will ensure the nginx pods are on agent nodes instead of the server nodes, It will also ensure workload pods are not capable of being scheduled on the server nodes. If you have more than 3 agent nodes (like in this example) you might want to also apply nodeSelectors or taints to the nginx deployment and agent nodes to ensure your nginx nodes are pinned to the correct hosts or to ensure the agent nodes are dedicated to ingress workloads. If  If RKE2 is already running, then stop it with `systemctl stop rke2-server` until you have all the remaining steps completed below.

## Nginx config
On one of your server nodes, ensure nginx is configured to listen on 8443 instead of 443 so we can load balance 443 on HAProxy instead. We do this by dropping a manifest file in `/var/lib/rancher/rke2/server/manifests` which RKE2 will apply at the next restart.
```
mkdir -p /var/lib/rancher/rke2/server/manifests/
cp rke2-ingress-nginx-config.yaml /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml
```

You also might need to scale your nginx deployment to 3 replicas
```
kubectl scale deploy rke2-ingress-nginx-controller -n kube-system --replicas 3
kubectl scale deploy rke2-ingress-nginx-default-backend -n kube-system --replicas 3
```

> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/rke2-ingress-nginx.yaml -o /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml

## HAProxy
Apply this configuration to the 3 agent nodes that will run the ingress controllers
```shell

# haproxy listen port
export APISERVER_DEST_PORT=6443
export INGRESS_DEST_PORT=443
# backend listen port
export APISERVER_SRC_PORT=6443
export INGRESS_SRC_PORT=8443

# API-Server host info
export HOST1_ID=rhel-8-0
export HOST1_ADDRESS=192.168.4.136
export HOST2_ID=rhel-8-1
export HOST2_ADDRESS=192.168.4.137
export HOST3_ID=rhel-8-2
export HOST3_ADDRESS=192.168.4.138

# Ingress host info
export INGRESS_HOST1_ID=rhel-8-3
export INGRESS_HOST1_ADDRESS=192.168.4.143
export INGRESS_HOST2_ID=rhel-8-4
export INGRESS_HOST2_ADDRESS=192.168.4.144
export INGRESS_HOST3_ID=rhel-8-5
export INGRESS_HOST3_ADDRESS=192.168.4.145

mkdir -p /var/lib/rancher/rke2/haproxy
/bin/cp haproxy.cfg /var/lib/rancher/rke2/haproxy/haproxy.cfg

mkdir -p /var/lib/rancher/rke2/agent/pod-manifests
/bin/cp haproxy.yaml /var/lib/rancher/rke2/agent/pod-manifests/haproxy.yaml

# substitute environment vars in the config file
originalfile="/var/lib/rancher/rke2/haproxy/haproxy.cfg" && tmpfile=$(mktemp) && /bin/cp --attributes-only --preserve $originalfile $tmpfile && cat $originalfile | envsubst | tee $tmpfile && /bin/cp $tmpfile $originalfile && rm -rf $tmpfile
echo "" >> /var/lib/rancher/rke2/haproxy/haproxy.cfg
```

> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/haproxy.cfg -o /var/lib/rancher/rke2/haproxy/haproxy.cfg
> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/haproxy.yaml -o /var/lib/rancher/rke2/agent/pod-manifests/haproxy.yaml


## KeepaliveD
Set vars
```shell
# network interface taking part in the negotiation of the virtual IP, e.g. eth0.
export INTERFACE=ens18
# should be the same for all keepalived cluster hosts while unique amongst all clusters in the same subnet. Many distros pre-configure its value to 51.
export ROUTER_ID=51
# should be higher on the master than on the backups. Hence 101 and 100 respectively will suffice.
export MASTER_PRIORITY=101
export BACKUP_PRIORITY=100
# should be the same for all keepalived cluster hosts, e.g. 42
export AUTH_PASS="auth_pass"
# is the virtual IP address negotiated between the keepalived cluster hosts.
export APISERVER_VIP="192.168.4.244"
# haproxy listen ports
export APISERVER_DEST_PORT=6443
```


### Master config
Set up master configs using state=master for the first agent
```shell
mkdir -p /var/lib/rancher/rke2/keepalived
cp keepalived_master.conf /var/lib/rancher/rke2/keepalived/keepalived.conf
```

> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/keepalived_master.conf -o /var/lib/rancher/rke2/keepalived/keepalived.conf

### Backups
Set up backup configs using state=backup for the next 2 agents
```
mkdir -p /var/lib/rancher/rke2/keepalived
cp keepalived_backup.conf /var/lib/rancher/rke2/keepalived/keepalived.conf
```

> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/keepalived_backup.conf -o /var/lib/rancher/rke2/keepalived/keepalived.conf

### All keepalived hosts

```shell
cp keepalived.yaml /var/lib/rancher/rke2/agent/pod-manifests/keepalived.yaml
cp check_apiserver.sh /var/lib/rancher/rke2/keepalived/check_apiserver.sh

# substitute environment vars in the config file
originalfile="/var/lib/rancher/rke2/keepalived/keepalived.conf" && tmpfile=$(mktemp) && /bin/cp --attributes-only --preserve $originalfile $tmpfile && cat $originalfile | envsubst | tee $tmpfile && /bin/cp $tmpfile $originalfile && rm -rf $tmpfile
```

> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/keepalived.yaml -o /var/lib/rancher/rke2/agent/pod-manifests/keepalived.yaml
> curl -L https://gist.githubusercontent.com/mddamato/5b696d202befde53c333761e23dca616/raw/check_apiserver.sh -o /var/lib/rancher/rke2/keepalived/check_apiserver.sh



## Build image
docker build -t 

## Start RKE2
```
systemctl start rke2-server
systemctl enable rke2-server
journalctl -u rke2-server -f
```

