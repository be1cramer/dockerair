## Quick notes for running Kube-VIP as a daemonset in RKE2 w/ BGP config

mkdir -p /var/lib/rancher/rke2/server/manifests/
curl -s https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml

ctr -a /run/k3s/containerd/containerd.sock image pull docker.io/plndr/kube-vip:v0.3.5

export VIP=192.168.133.33
export INTERFACE=lo

alias kube-vip="ctr -a /run/k3s/containerd/containerd.sock run --rm --net-host docker.io/plndr/kube-vip:v0.3.5 vip /kube-vip"

kube-vip manifest daemonset \
    --interface $INTERFACE \
    --address $VIP \
    --controlplane \
    --services \
    --inCluster \
    --taint \
    --bgp \
    --bgppeers 192.168.133.34:65000::false,192.168.133.35:65000::false,192.168.133.36:6500::false | tee /var/lib/rancher/rke2/server/manifests/kube-vip.yaml


## Deploy the Kube-VIP Cloud Provider Load Balancer

kubectl apply -f https://raw.githubusercontent.com/kube-vip/kube-vip-cloud-provider/main/manifest/kube-vip-cloud-controller.yaml

kubectl create configmap --namespace kube-system kubevip --from-literal range-global=192.168.133.50-192.168.133.60