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