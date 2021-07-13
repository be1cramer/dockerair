1. Revert m1 and w1 to latest snapshots
2. Install rke2 on m1 w/ latest script
3. Install govc on m1 w/ latest script
4. Set kubectl and crictl env variables on m1

cat >> ~/.bashrc <<EOF
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
export PATH=$PATH:/var/lib/rancher/rke2/bin:/usr/local/bin
export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
alias ku=kubectl
EOF
source ~/.bashrc

5. Set govc environment variables

export GOVC_URL=as-vcsa-01.ntsdev.net
export GOVC_USERNAME=jcuadmin@vsphere.local
export GOVC_PASSWORD='!QAZxsw2'
export GOVC_INSECURE=true

6. Use govc to set disk UUID on m1 and w1
    
    a. govc vm.change -vm '/NTS AS LAB/vm/JCU/BCEC-VSP-CPIM1' -e="disk.enableUUID=1"
    b. govc vm.change -vm '/NTS AS LAB/vm/JCU/BCEC-VSP-CPIW1' -e="disk.enableUUID=1"

7. Set variables in rke2 config on m1
8. Start rke2-server on m1
9. Stop and disable firewalld on w1 and m1
10. Create new imported k8s cluster on Rancher server as 'vcpi'
11. Import m1 to Rancher cluster vcpi

12. RKE2 config flow
    vars. kubelete-arg:
    - cloud-provider=external
    cloud-provider-name: vsphere

    results. cattle-cluster-agent, rke2-coredns, rke2-metrics-server all cannot be scheduled on m1, due to taint intoleration: 'node.cloudprovider.kubernetes.io/uninitialized: true' 

    No Charts in Cluster Explorer Apps & Marketplace

    vars. kubelete-arg:
    - cloud-provider=vsphere
    cloud-provider-name: vsphere

    results. no node.cloudprovider.kubernetes.io/uninitialized: true taint on nodes
    Helm Charts are present in Cluster Explorer Apps & Marketplace

    No Charts in Cluster Explorer Apps & Marketplace
13. Set rke2 config on w1
14. Copy node token from m1 to w1 rke2 config
15. Start rke2 agent service on w1

        
        16.a. Remove taint cloud proviced uninitialized taint from m1
        16.b. Add controlplane label to m1

17. Restart rke2 service on m1 and w1
18. Test that ProviderID is set on all nodes in the cluster 

        a. kubectl get nodes -o json | jq '.items[]|[.metadata.name, .spec.providerID, .status.nodeInfo.systemUUID]'
        b. kubectl describe nodes | grep "ProviderID"






I. Install RKE2
    a. With cloud-provider=external/vsphere
II. Install Vsphere CPI/VCP
    a. via rancher-partner helm chart
III. Install Vsphere CSI