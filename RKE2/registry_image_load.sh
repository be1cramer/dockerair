#!/bin/bash

set -e

mkdir -p temp_dir
cd temp_dir

REGISTRY_HOSTNAME=${1:-"127.0.0.1:5443"}
CERT_MANAGER_VERSION="v1.0.4"
RKE2_VERSION=${2:-"v1.20.6+rke2r1"}
RANCHER_VERSION="v2.5.8"

yum update -y
yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-cli

download_images_from_list() {
for LISTIMAGE in $(cat $1); do
  echo "pulling $LISTIMAGE"

  # try pulling 5 times with a sleep, set pull error code
  for i in {1..5}; do 
    [ $i -gt 1 ] && sleep 20; 
    IMAGE_PULL_CMD=$(docker pull ${LISTIMAGE} 2>&1) && error=0 && break || error=$? && echo "error pulling ${LISTIMAGE} retrying $i"; 
  done

  # if all 3 pulls failed, exit, and show which image couldn't be pulled
  if [ ! $error -eq 0 ]; then
      echo "failed to pull image ${LISTIMAGE} with error: $IMAGE_PULL_CMD"
      echo "error code $error"
      exit $error;
  fi

  IMAGE=$(echo "$IMAGE_PULL_CMD" | tail -1)
  echo "pulled $IMAGE"

  IMAGE_REGEX='^([a-zA-Z0-9\.-]+)\/([\/0-9a-zA-Z-]+)\/([a-zA-Z0-9.-]+\:[a-zA-Z0-9\.-]+)$'
  if [[ $IMAGE =~ $IMAGE_REGEX ]]; then 
      IMAGE_REGISTRY=${BASH_REMATCH[1]};
      IMAGE_REPOSITORY=${BASH_REMATCH[2]};
      IMAGE_NAME=${BASH_REMATCH[3]};
      IMAGE_TAG=${IMAGE_NAME#*:}
      IMAGE_REPO=${IMAGE_NAME%:*}
  fi
  docker tag ${IMAGE} $REGISTRY_HOSTNAME/$IMAGE_REPOSITORY/$IMAGE_NAME
  docker push $REGISTRY_HOSTNAME/$IMAGE_REPOSITORY/$IMAGE_NAME
done
}

# Pull any extra images from this list
cat > additional-images.txt <<EOF
k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.2.0
quay.io/cephcsi/cephcsi:v3.3.1
k8s.gcr.io/sig-storage/csi-provisioner:v2.2.2
k8s.gcr.io/sig-storage/csi-resizer:v1.2.0
k8s.gcr.io/sig-storage/csi-attacher:v3.2.1
k8s.gcr.io/sig-storage/csi-snapshotter:v4.1.1
EOF
download_images_from_list additional-images.txt

#quay.io/jetstack/cert-manager-cainjector:$CERT_MANAGER_VERSION
#quay.io/jetstack/cert-manager-controller:$CERT_MANAGER_VERSION
#quay.io/jetstack/cert-manager-webhook:$CERT_MANAGER_VERSION
#quay.io/ansible/awx:18.0.0
#postgres:12
#redis:6.2.1
#quay.io/ansible/awx-operator:0.8.0
#quay.io/ansible/awx-ee:0.1.1
#quay.io/argoproj/argocd:v2.0.0
#ghcr.io/dexidp/dex:v2.27.0
#busybox:1.32.1
#netboxcommunity/netbox:v2.10.4
#netboxcommunity/netbox:v2.10.4
#docker.io/bitnami/postgresql:11.11.0-debian-10-r0
#docker.io/bitnami/redis:6.0.10-debian-10-r19
#us.gcr.io/k8s-artifacts-prod/ingress-nginx/controller:v0.34.1
#harbor.jcudev.corp/license-dashboard/api:0.0.1
#harbor.jcudev.corp/license-dashboard/dash:0.0.1
#docker.elastic.co/elasticsearch/elasticsearch:7.8.1
#harbor.jcudev.corp/license-dashboard/api:0.0.7
#harbor.jcudev.corp/license-dashboard/dash:0.0.2
# nginxdemos/hello
# monachus/rancher-demo
# zayashv/dbench
# busybox:1.32.1
# quay.io/jetstack/cert-manager-cainjector:$CERT_MANAGER_VERSION
# quay.io/jetstack/cert-manager-controller:$CERT_MANAGER_VERSION
# quay.io/jetstack/cert-manager-webhook:$CERT_MANAGER_VERSION
# coredns/coredns
# kubevip/kube-vip-cloud-provider:0.1
# plndr/kube-vip:v0.3.5
# postgres:12
# redis:6.2.1
# goharbor/harbor-core:v2.2.2
# goharbor/harbor-db:v2.2.2
# goharbor/harbor-jobservice:v2.2.2
# goharbor/harbor-portal:v2.2.2
# goharbor/redis-photon:v2.2.2
# goharbor/registry-photon:v2.2.2
# rancher/klipper-helm:v0.6.1-build20210616
# ceph/ceph:v15.2.13
# rook/ceph:v1.6.7
# goharbor/harbor-registryctl:v2.2.2
# k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.2.0
# quay.io/cephcsi/cephcsi:v3.3.1
# k8s.gcr.io/sig-storage/csi-provisioner:v2.2.2
# k8s.gcr.io/sig-storage/csi-resizer:v1.2.0
# k8s.gcr.io/sig-storage/csi-attacher:v3.2.1
# k8s.gcr.io/sig-storage/csi-snapshotter:v4.1.1


# Download Rancher images
#curl -LO https://github.com/rancher/rancher/releases/download/$RANCHER_VERSION/rancher-images.txt
#download_images_from_list rancher-images.txt

# Download RKE Images
#curl -LO https://github.com/rancher/rke2/releases/download/$RKE2_VERSION/rke2-images.linux-amd64.txt
#download_images_from_list rke2-images.linux-amd64.txt

cd ../
rm -rf temp_dir

# directly pull and tar some images
docker pull docker.io/library/registry:2
docker save docker.io/library/registry:2 -o registry.tar