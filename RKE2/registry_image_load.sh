#!/bin/bash

set -e

mkdir -p temp_dir
cd temp_dir

REGISTRY_HOSTNAME=${1:-"127.0.0.1:5443"}
CERT_MANAGER_VERSION="v1.0.4"
RKE2_VERSION=${2:-"v1.19.7+rke2r1"}
RANCHER_VERSION="v2.5.5"

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
goharbor/chartmuseum-photon:v2.2.1
goharbor/harbor-core:v2.2.1
goharbor/harbor-db:v2.2.1
goharbor/harbor-jobservice:v2.2.1
goharbor/notary-server-photon:v2.2.1
goharbor/notary-signer-photon:v2.2.1
goharbor/harbor-portal:v2.2.1
goharbor/redis-photon:v2.2.1
goharbor/registry-photon:v2.2.1
goharbor/harbor-registryctl:v2.2.1
goharbor/trivy-adapter-photon:v2.2.1
docker.io/bitnami/chartmuseum:0.13.1-debian-10-r16
docker.io/bitnami/harbor-core:2.2.0-debian-10-r29
docker.io/bitnami/harbor-jobservice:2.2.0-debian-10-r32
docker.io/bitnami/nginx:1.19.8-debian-10-r19
docker.io/bitnami/harbor-notary-server:2.2.0-debian-10-r28
docker.io/bitnami/harbor-notary-signer:2.2.0-debian-10-r28
docker.io/bitnami/harbor-portal:2.2.1-debian-10-r0
docker.io/bitnami/postgresql:11.11.0-debian-10-r50
docker.io/bitnami/redis:6.0.12-debian-10-r3
docker.io/bitnami/harbor-registry:2.2.1-debian-10-r0
docker.io/bitnami/harbor-registryctl:2.2.0-debian-10-r31
docker.io/bitnami/harbor-adapter-trivy:2.2.0-debian-10-r30
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