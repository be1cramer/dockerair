
# Online Side - with an internet connection

All of the below steps assume you're on a machine with docker installed and an active internet connection.

## Shortcut- run all the steps:

I am currently seeing some stability issues running this and i think it's a matter of rate limiting from quay and docker but i have not tried to stabilize it yet. I might need to just work in some retry logic. If it fails at some point in running this it's best to rerun the individual steps that failed and the remaining steps after that individually. Or run them individually in the substeps below.

Run all the online things:

> This can take more than an hour to complete, and needs about 60GiB of disk. End result is about 10GiB.

```shell
curl -sfL https://gist.githubusercontent.com/mddamato/fe8ca3337b8ceae93d8f6ca02d9c02b6/raw/do_all_the_online_things.sh | bash -
```
After this finishes copy everything from RKE_Dependencies into the offline host.

### Make directory for all your dependencies

All of the below steps assume this folder is created.

```shell
mkdir RKE_Dependencies
```

### Download RKE2 Images and RPMs

This follows a similar process from https://rancherfederal.com/blog/installing-rke-government-in-airgap-environments/

```shell
docker run --rm \
-v $(pwd)/RKE_Dependencies:/mnt \
-w /mnt centos:8 \
/bin/bash -c \
"curl -sfL https://gist.githubusercontent.com/mddamato/fe8ca3337b8ceae93d8f6ca02d9c02b6/raw/download_rke.sh | bash -"
```

### Make some self signed certificates for the registry

```shell
docker run -it --rm \
-v $(pwd)/RKE_Dependencies:/mnt \
-w /mnt centos:8 \
/bin/bash -c \
"yum install -y openssl && curl -sfL https://gist.githubusercontent.com/mddamato/fe8ca3337b8ceae93d8f6ca02d9c02b6/raw/registry_self_signed_certs.sh | bash -"
```
### Download any other dependencies we might need

Add to the `download_rancher.sh` script if any additional charts or binaries are needed.

```shell
docker run -it --rm \
-v $(pwd)/RKE_Dependencies:/mnt \
-w /mnt centos:8 \
/bin/bash -c \
"curl -sfL https://raw.githubusercontent.com/be1cramer/dockerair/main/RKE2/download_rancher.sh | bash -"
```

### Start a temporary registry so we can load the database with our image blobs

We will use this registry to build a database of image blobs that we can ship to the airgap and mount to a new registry.

```shell
docker run -t -d --rm \
--name temp_registry \
-v $(pwd)/RKE_Dependencies/registry_data/certs:/certs \
-v $(pwd)/RKE_Dependencies/registry_data/db:/var/lib/registry \
-e REGISTRY_HTTP_ADDR=0.0.0.0:5443 \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/server.key \
-p 5443:5443 \
registry:2
```

### Download and push all needed images to the registry

This process takes a long time and uses a lot of disk space. Add to the `registry_image_load.sh` script if any additional images are needed.

```shell
docker run --privileged -it --rm \
-v /var/run/docker.sock:/var/run/docker.sock \
-v $(pwd)/RKE_Dependencies:/mnt \
-w /mnt \
centos:8 \
/bin/bash -c \
"curl -sfL https://raw.githubusercontent.com/be1cramer/dockerair/main/RKE2/registry_image_load.sh | bash -"
```

### Stop the registry

```shell
docker stop temp_registry

docker run -t --rm \
-v $(pwd)/RKE_Dependencies:/mnt \
-w /mnt centos:8 \
/bin/bash -c \
"yum install -y pigz && cd registry_data; tar -cvf ../registry_data.tar . && cd .. && rm -rf registry_data/ && pigz registry_data.tar"
```

## Zip everything up, and send to airgap

```shell
scp RKE_Dependencies/* user@rke2-server.com:/home/user
```

> clean everything by removing RKE_Dependencies `rm -rf RKE_Dependencies`. You might also want to `docker prune` to clean up local copies of images.

## Prep for Offline side 27:20

Set DNS 'A records' for all rke servers in the Rancher Managment Server host cluster

  ie... rancher-node1.ntaphci.poc.  192.168.1.201
        rancher-node2.ntaphci.poc.  192.168.1.202
        rancher-node3.ntaphci.poc.  192.168.1.203
  
  and the DNS 'cname record' or alias
        rancher.ntaphci.poc.        192.168.1.201


# Offline side - no internet connection

These steps assume you're running on a RHEL/Centos 8 machine.

## disable firewalld
```shell
if [ "$(id -u)" -ne 0 ] ; then sudo -s; fi
systemctl stop firewalld && systemctl disable firewalld
```

## disable selinux
```shell
sed -i 's/=enforcing/=permissive/g' /etc/selinux/config
setenforce 0
```

## Set variables
```shell
cat >> ~/.bashrc <<EOF
export RANCHER_INGRESS_HOSTNAME="$(hostname)"
export FIRST_SERVER_NODE_HOSTNAME="$(hostname)"
export FIRST_SERVER_NODE_IP="$(hostname -i)"
export REGISTRY_IP="$(hostname -i)"
export REGISTRY_HOST="$(hostname)"
export REGISTRY_PORT="30500"
export INSECURE_REGISTRY_PORT="30501"
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin:/usr/local/bin
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
alias ku=kubectl
EOF
source ~/.bashrc
```

> These can be set in your bash profile so you don't need to re-enter them if you close your session

> The registry ports are hard coded in the registry_manifest.yaml

## create rke2 config file
```shell
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<EOF
selinux: true
write-kubeconfig-mode: "0640"
tls-san:
- centos-8-0.tomatodamato.com
- centos-8-1.tomatodamato.com
- centos-8-2.tomatodamato.com
EOF
```

## create registry config
```shell
cat > /etc/rancher/rke2/registries.yaml <<EOF
mirrors:
  "$REGISTRY_HOST:$REGISTRY_PORT":
    endpoint:
      - "https://$REGISTRY_HOST:$REGISTRY_PORT"
  docker.io:
    endpoint:
      - "https://$REGISTRY_HOST:$REGISTRY_PORT"
configs:
  "$REGISTRY_HOST:$REGISTRY_PORT":
    tls:
      cert_file: /var/lib/rancher/hostPaths/registry/certs/server.crt
      key_file: /var/lib/rancher/hostPaths/registry/certs/server.key
      ca_file: /var/lib/rancher/hostPaths/registry/certs/ca.pem
      insecure_skip_verify: true
EOF
```

## install rke2

```shell
rpm -i ./tar-1.30-5.el8.x86_64.rpm
tar xzvf rke-government-deps-*.tar.gz
rm -f rke-government-deps-*.tar.gz

mkdir -p /var/lib/rancher/rke2/agent/images/ && \
zcat rke2-images.linux-amd64.tar.gz > /var/lib/rancher/rke2/agent/images/rke2-images.linux-amd64.tar

cp registry.tar /var/lib/rancher/rke2/agent/images/

mkdir -p /var/lib/rancher/yum_repos
tar xzf rke_rpm_deps.tar.gz -C /var/lib/rancher/yum_repos
cat > /etc/yum.repos.d/rke_rpm_deps.repo <<EOF
[rke_rpm_deps]
name=rke_rpm_deps
baseurl=file:///var/lib/rancher/yum_repos/rke_rpm_deps
enabled=0
gpgcheck=0
EOF

yum install -y --disablerepo=* --enablerepo="rke_rpm_deps" rke2-server
```

## Start rke2-server
```shell
systemctl start rke2-server
systemctl enable rke2-server
```

## Watch the rke2-server journal logs if you like
```
journalctl -u rke2-server -f
```

## Wait for Ready status
```
watch kubectl get no
```


## Install registry

```shell
# load registry image into containerd locally
ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image import /var/lib/rancher/rke2/agent/images/registry.tar

# extract registry database
mkdir -p /var/lib/rancher/hostPaths/registry
tar xvzf registry_data.tar.gz -C /var/lib/rancher/hostPaths/registry

# make new registry certs
chmod +x registry_self_signed_certs.sh
bash -c "./registry_self_signed_certs.sh /var/lib/rancher/hostPaths/registry $REGISTRY_IP $REGISTRY_HOST"

# add to hosts file if hostname is not resolvable
echo "$REGISTRY_IP $REGISTRY_HOST" >> /etc/hosts

# create registry namespace
kubectl create ns registry

# make secret for certificates
kubectl create secret -n registry generic registry-certificates \
--from-file=cert=/var/lib/rancher/hostPaths/registry/certs/server.crt \
--from-file=key=/var/lib/rancher/hostPaths/registry/certs/server.key \
--from-file=ca=/var/lib/rancher/hostPaths/registry/certs/ca.pem

# launch registry
kubectl apply -f registry_manifest.yaml -n registry
kubectl wait --for=condition=available --timeout=600s deployment/registry -n registry
```

## Test registry connection

```shell
ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image tag docker.io/library/registry:2 $REGISTRY_HOST:$REGISTRY_PORT/library/registry:2
ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image push --skip-verify $REGISTRY_HOST:$REGISTRY_PORT/library/registry:2
curl -k https://$REGISTRY_HOST:$REGISTRY_PORT/v2/_catalog
```


## Install Rancher MCM

```shell
# create namespaces
kubectl create ns cert-manager
kubectl create ns cattle-system

# install cert-manager
kubectl apply -f cert-manager.crds.yaml
tar xvf helm-v3.5.0-linux-amd64.tar.gz
linux-amd64/helm upgrade --install cert-manager cert-manager-v1.0.4.tgz --namespace cert-manager --version v1.0.4 --set cainjector.image.repository="$REGISTRY_HOST:$REGISTRY_PORT/jetstack/cert-manager-cainjector" --set image.repository="$REGISTRY_HOST:$REGISTRY_PORT/jetstack/cert-manager-controller" --set webhook.image.repository="$REGISTRY_HOST:$REGISTRY_PORT/jetstack/cert-manager-webhook"
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager-cainjector -n cert-manager
kubectl wait --for=condition=available --timeout=600s deployment/cert-manager-webhook -n cert-manager

## install rancher
linux-amd64/helm upgrade \
--install rancher rancher-2.5.5.tgz \
--namespace cattle-system \
--set hostname=$RANCHER_INGRESS_HOSTNAME \
--set systemDefaultRegistry="$REGISTRY_HOST:$REGISTRY_PORT" \
--set useBundledSystemChart=true
kubectl wait --for=condition=available --timeout=600s deployment/rancher -n cattle-system
```


## Collect configuration for additional nodes

Collect things that need to be sent to all additional nodes

```shell
# make directory for items to send to all additional nodes
mkdir add_node_reqs

# copy the current config and add a few extra parameters
cp /etc/rancher/rke2/config.yaml add_node_reqs/config.yaml
echo "server: https://$FIRST_SERVER_NODE_IP:9345" >> add_node_reqs/config.yaml
echo "system-default-registry: $REGISTRY_HOST:$REGISTRY_PORT" >> add_node_reqs/config.yaml
echo "token: $(cat /var/lib/rancher/rke2/server/node-token)" >> add_node_reqs/config.yaml

# make a hosts config file if needed
touch add_node_reqs/hosts_config
echo "$REGISTRY_IP $REGISTRY_HOST" >> add_node_reqs/hosts_config

# copy current registry config
cp /etc/rancher/rke2/registries.yaml add_node_reqs
mkdir -p add_node_reqs/reg_certs
cp /var/lib/rancher/hostPaths/registry/certs/server.crt add_node_reqs/reg_certs
cp /var/lib/rancher/hostPaths/registry/certs/server.key add_node_reqs/reg_certs
cp /var/lib/rancher/hostPaths/registry/certs/ca.pem add_node_reqs/reg_certs

# copy in some RPM deps
cp rke_rpm_deps.tar.gz add_node_reqs/
cp tar-1.30-5.el8.x86_64.rpm add_node_reqs/
```

## copy files to additional nodes
```
scp -r add_node_reqs admin@centos-8-1.tomatodamato.com:/home/admin
```

## configure all additional nodes
ssh to new node
```shell
cd add_node_reqs

if [ "$(id -u)" -ne 0 ] ; then sudo -s; fi
systemctl stop firewalld && systemctl disable firewalld

sed -i 's/=enforcing/=permissive/g' /etc/selinux/config
setenforce 0

cat hosts_config  >> /etc/hosts

rpm -i tar-1.30-5.el8.x86_64.rpm

mkdir -p /etc/rancher/rke2
cp config.yaml /etc/rancher/rke2/config.yaml
cp registries.yaml /etc/rancher/rke2/registries.yaml

mkdir -p /var/lib/rancher/hostPaths/registry/certs
cp reg_certs/server.crt /var/lib/rancher/hostPaths/registry/certs/server.crt
cp reg_certs/server.key /var/lib/rancher/hostPaths/registry/certs/server.key
cp reg_certs/ca.pem /var/lib/rancher/hostPaths/registry/certs/ca.pem

cp /var/lib/rancher/hostPaths/registry/certs/ca.pem /etc/pki/ca-trust/source/anchors/registryca.crt
update-ca-trust

mkdir -p /var/lib/rancher/yum_repos
tar xzf rke_rpm_deps.tar.gz -C /var/lib/rancher/yum_repos
cat > /etc/yum.repos.d/rke_rpm_deps.repo <<EOF
[rke_rpm_deps]
name=rke_rpm_deps
baseurl=file:///var/lib/rancher/yum_repos/rke_rpm_deps
enabled=0
gpgcheck=0
EOF

yum install -y --disablerepo=* --enablerepo="rke_rpm_deps" rke2-server

systemctl start rke2-server
systemctl enable rke2-server
journalctl -u rke2-server -f
```