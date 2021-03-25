# -*- mode: ruby -*-
# vi: set ft=ruby :

# To make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

# Helper to manipulate an IP addresses
require 'ipaddr'

# Configuration
NUM_SERVERS = ENV['K3S_NUM_SERVERS'] || 1
NUM_WORKERS = ENV['K3S_NUM_WORKERS'] || 2

# Constants
k3s_first_server_node_ip = '10.3.3.10'
k3s_first_worker_node_ip = '10.3.3.20'
k3s_token = %x[ openssl rand -hex 32 ]

def setup_node(vm)
  vm.box = "generic/alpine313"
  vm.provider :libvirt do |lv|
    lv.default_prefix = ""
    lv.memory = 2048
    lv.storage_pool_name = "disks"
  end
  vm.provision "shell", inline: <<-SHELL
    # Disable swap
    sed -ri '/\\sswap\\s/s/^#?/#/' /etc/fstab
    swapoff -a
  SHELL
end

Vagrant.configure("2") do |config|
  server_node_ip_address = IPAddr.new k3s_first_server_node_ip
  (1..NUM_SERVERS).each do |i|
    vm_name = "k3s-master-#{'%02d' % i}"
    config.vm.define vm_name do |s|
      setup_node(s.vm)
      node_ip = server_node_ip_address.to_s; server_node_ip_address = server_node_ip_address.succ
      s.vm.hostname = "#{vm_name}.cluster.local"
      s.vm.network "public_network", :dev => "br0", :mode => "bridge", :type => "bridge"
      s.vm.network "private_network", ip: node_ip
      s.vm.provision "shell", inline: <<-SHELL
        # Install k3s
        sed -i 's/v[[:digit:]]\\..*\\//edge\\//g' /etc/apk/repositories
        apk add --no-cache k3s

        # Set k3s options
        export K3S_EXEC=server
        export K3S_OPTS=--node-ip=#{node_ip}
        export K3S_TOKEN=#{k3s_token}
        env | awk '/^K3S_/{print "export " $0}' | tee -a /etc/conf.d/k3s >/dev/null

        # Enable and start k3s service
        rc-update add k3s
        service k3s start
      SHELL
    end
  end

  worker_node_ip_address = IPAddr.new k3s_first_worker_node_ip
  (1..NUM_WORKERS).each do |i|
    vm_name = "k3s-worker-#{'%02d' % i}"
    config.vm.define vm_name do |s|
      setup_node(s.vm)
      node_ip = worker_node_ip_address.to_s; worker_node_ip_address = worker_node_ip_address.succ
      s.vm.hostname = "#{vm_name}.cluster.local"
      s.vm.network "private_network", ip: node_ip
      s.vm.provision "shell", inline: <<-SHELL
        # Install k3s
        sed -i 's/v[[:digit:]]\\..*\\//edge\\//g' /etc/apk/repositories
        apk add --no-cache k3s

        # Set k3s options
        export K3S_EXEC=agent
        export K3S_OPTS=--node-ip=#{node_ip}
        export K3S_TOKEN=#{k3s_token}
        export K3S_URL=https://#{k3s_first_server_node_ip}:6443/
        env | awk '/^K3S_/{print "export " $0}' | tee -a /etc/conf.d/k3s >/dev/null

        # Enable and start k3s service
        rc-update add k3s
        service k3s start
      SHELL
    end
  end
end
