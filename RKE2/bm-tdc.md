## BM build
1. Install RHEL to NVME drive
2. Register
3. /etc/hosts with VIP entry
4. cat > /etc/NetworkManager/conf.d/rke2-canal.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF
systemctl reload NetworkManager
5. swapoff -a
6. systemctl stop firewalld && systemctl disable firewalld
7. sudo yum install iptables-services -y
8. cat > /etc/sysconfig/iptables << EOF
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
9. mkdir -p /etc/rancher/rke2
10. cat > /etc/rancher/rke2/config.yaml << EOF
selinux: true
write-kubeconfig-mode: "0640"
tls-san:
- bm1.tdc4
- bm2.tdc4
- bm3.tdc4
- vip.tdc4
server: https://vip.tdc4:9345
token: 
EOF
11.  cat > /etc/rancher/rke2/registries.yaml <<EOF
> mirrors:
>   "bm1.tdc4:30500"
>     endpoint:
>     - "https://bm1.tdc4:30500"
>   docker.io
>     endpoint:
>     - "https://bm1.tdc4:30500"
> configs:
>   "bm1.tdc:30500"
>     tls:
>      cert_file: /var/lib/rancher/hostPaths/registry/certs/server.crt
>       key_file: /var/lib/rancher/hostPaths/registry/certs/server.key
>       ca_file: /var/lib/rancher/hostPaths/registry/certs/ca.pem
>       insecure_skip_verify: true
> EOF
12. Curl rke2-offline depnd tar 
curl -LO https://rfed-public.s3-us-gov-east-1.amazonaws.com/rke-government-deps-offline-bundle-el8.tar.gz
tar xzvf rke-government-deps-*.tar.gz
13. Make install-server.sh executables
14. Execute install-server.sh
15. Set kubectl env vars
16. SCP rke2 config.yaml to additional RKE2 nodes
## Now add additional RKE2 nodes to clusters

