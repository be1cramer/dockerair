## BM build
1. Install RHEL to NVME drive
2. Register
3. /etc/hosts with VIP entry
4. cat > /etc/NetworkManager/conf.d/rke2-canal.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:flannel*
EOF
systemctl reload NetworkManager
5. Swapoff -a
6. systemctl stop firewalld && systemctl disable firewalld
7. Sudo yum install iptables-services
8. cat > /etc/sysconfig/iptables << EOF
9. mkdir -p /etc/rancher/rke2
10. cat > /etc/rancher/rke2/config.yaml << EOF
selinux: true
write-kubeconfig-mode: "0640"
tls-san:
- bm1.tdc4
- bm2.tdc4
- bm3.tdc4
- vip.tdc4
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
13. Make install-server.sh executables
14. Execute install-server.sh
15. Set kubectl env vars
16. SCP rke2 config.yaml to additional RKE2 nodes
## Now add additional RKE2 nodes to clusters

