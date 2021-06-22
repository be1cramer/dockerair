Pre-RKE2 Env
1. disable firewalld
2. netmanager [rke2-canal.conf] 
3. search domain /etc/resolv.conf
4. install iptables-services
5. add iptable rules for cross-node comms
5. tarball rke2 (https://rfed-public.s3-us-gov-east-1.amazonaws.com/rke-government-deps-offline-bundle-el8.tar.gz)
curl -LO https://rfed-public.s3-us-gov-east-1.amazonaws.com/rke-government-deps-offline-bundle-el7.tar.gz
6. make install_server.sh executable, and execute
7. server: should point to fqdn of loadbalancer ( ie. https://kube.jcudev.corp:94345 ) in /etc/rancher/rke2/config.yaml
8. setenforce 0
9. redeploy rke2-nginx-lb
10. place tar of 'bootstrap' images in /var/lib/rancher/rke2/agent/images
11. crictl load/push images  ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image push --skip-verify -u 'admin:P@55w0rd!1' core.harbor.asteroids.corp/library/keepalived:latest
12. ctr -a /run/k3s/containerd/containerd.sock -n k8s.io image tag docker.io/mddamato/keepalived:latest core.harbor.asteroids.corp/library/keepalived:latest

cat > /etc/NetworkManager/conf.d/rke2-canal.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF

systemctl reload NetworkManager
reboot

Recovering clean RKE2 env
1. Install RKE2
2. poweroff vms
3. snapshot vms


cat > /etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 9345 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 6443 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 10250 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 2379 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 2380 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p udp -m state --state NEW -m udp --dport 8470 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 30000:32767 -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF


cat >> ~/.bashrc <<EOF
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin:/usr/local/bin
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
alias ku=kubectl
EOF
source ~/.bashrc

cat > /var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-daemonset.yml <<EOF
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rke2-ingress-nginx
  namespace: kube-system
spec:
  valuesContent: |-
    controller:
      containerPort:
        http: 8080
        https: 8443
      extraArgs:
        http-port: "8080"
        https-port: "8443"
      kind: DaemonSet
EOF

## KeepaliveD
Set vars
```shell
# network interface taking part in the negotiation of the virtual IP, e.g. eth0.
export INTERFACE=ens192
# should be the same for all keepalived cluster hosts while unique amongst all clusters in the same subnet. Many distros pre-configure its value to 51.
export ROUTER_ID=51
# should be higher on the master than on the backups. Hence 101 and 100 respectively will suffice.
export MASTER_PRIORITY=101
export BACKUP_PRIORITY=100
# should be the same for all keepalived cluster hosts, e.g. 42
export AUTH_PASS="authpass"
# is the virtual IP address negotiated between the keepalived cluster hosts.
export APISERVER_VIP="192.168.133.30"
# haproxy listen ports
export APISERVER_DEST_PORT=6443
```


cat > /etc/rancher/rke2/config.yaml <<EOF
selinux: true
tls-san:
- bcec-app2-s001.jcudev.corp
server: https://bcec-app2-s001.jcudev.corp:9345
token: K1090e7f63c63fa721ced1c447d1eee0d502a2bd341c1085956a21ecac3d21798d3::server:fd22638315374a321ec86ec4c51e0125
EOF