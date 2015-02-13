# kvm_scripts
Bash scripts for VMs management 

# These scripts are used to setup an Openstack infrastructure


## 0. Big steps:
### 0.1) Prepare Openstack Servers (Baremetals or VMs)
###	0.2) Configure network interfaces on each server
###	0.3) Install Openstack software

## 1) Prepare Openstack Servers:
	Here we use 3 VMs as servers for Openstack Controller + Compute + Network. I put up a script for this here:
	git clone https://github.com/thuydang/kvm_scripts my_openstack_dev_dir

###	1.1) Use create_image.sh to create a VM and setup Fedora 20 on it: 
	- edit create_image.sh with proper image-name for the VM.
	- install Fedora 20 when prompted.

###	1.2) The installed image will be located in folder images.
	copy it to 3 new images: image-name-{controller, compute, network}.qcow2

##	2) Configure network intefaces on the 3 server as follow:
	Network diagram here!

###	2.1) There are 3 network interfaces on each Server. 3 Sample network files for each server are in: scripts/ifcfg-ensx. Edit them for each server according to the diagram above.

###	2.2 Configure /etc/hostname and /etc/hosts so the servers can resolve each other.

##	3) ssh / vnc to each server and install the respective Openstack software:
For each server:
### 3.1) Disable firewall, selinux, etc..
TBD

### 3.2) Install puppet
yum install -y puppet

Install puppet modules for Openstack Juno:
  puppet module install puppetlabs-openstack --version 5.0.2

Replace openstack module with the customized one for our servers:
	cd /etc/puppet/modules/
  rm -rf openstack
	git clone https://github.com/thuydang/puppetlabs-openstack/tree/td_up_5.0.2 openstack

### 3.3) Follow this to install Openstack
	https://github.com/thuydang/puppetlabs-openstack/blob/td_up_5.0.2/README.td
