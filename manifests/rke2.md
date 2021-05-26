Pre-RKE2 Env
1. disable firewalld
2. netmanager [rke2-canal.conf] 
3. search domain /etc/resolv.conf
4. install iptables-services
5. tarball rke2


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
# sample configuration for iptables service
# you can edit this manually or use system-config-firewall
# please do not ask us to add additional ports/services to this default configuration
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 9345 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 6443 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 10250 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 2379 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 2380 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p udp -m state --state NEW -m tcp --dport 8470 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp -m state --state NEW -m tcp --dport 30000:32767 -j ACCEPT
-A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
