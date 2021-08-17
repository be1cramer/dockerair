#!/bin/bash

set -e

yum install -y openssl yum-utils

yumdownloader --downloaddir $(pwd) tar

curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash


#curl -LO https://github.com/derailed/k9s/releases/download/v0.24.2/k9s_Linux_x86_64.tar.gz

#curl -LO https://get.helm.sh/helm-v3.5.0-linux-amd64.tar.gz

#curl -LO https://github.com/jetstack/cert-manager/releases/download/v1.0.4/cert-manager.crds.yaml

#curl -LO https://gist.githubusercontent.com/mddamato/fe8ca3337b8ceae93d8f6ca02d9c02b6/raw/registry_manifest.yaml
#curl -LO https://gist.githubusercontent.com/mddamato/fe8ca3337b8ceae93d8f6ca02d9c02b6/raw/registry_self_signed_certs.sh

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
#helm repo add bitnami https://charts.bitnami.com/bitnami
#helm repo add bootc https://charts.boo.tc
helm repo add harbor https://helm.goharbor.io
helm repo update

helm fetch rancher-latest/rancher --version=2.5.8
helm fetch jetstack/cert-manager --version v1.0.4
#helm fetch bootc/netbox --version=3.0.0
#helm fetch bitnami/postgresql-ha --version 6.9.0
#helm fetch bitnami/redis-cluster --version 5.0.0
helm fetch harbor/harbor --version 1.6.1
#helm fetch bitnami/harbor --version 9.8.3