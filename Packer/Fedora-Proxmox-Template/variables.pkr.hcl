proxmox_api_url = "https://<Proxmox IP or Domain Name>:8006/api2/json"  # Your Proxmox API Endpoint

node = "<Proxmox Node Name>"
vm_id = "999" #This will be the ID of the VM template that gets created
vm_name = "fedora-server-baseline" #This will be the name of the VM template that gets created
template_description = "Fedora Server 42 Beta Image" #This will be a description of the VM template that gets created and can be useful to highligh any key features

# VM template compute parameters
disk_size= "20G"
cores = 2
memory = 2048

# User that will be used by Packer to initially connect to and configure the VM, depending on the configuration this use will need sudo/root capability
ssh_username ="root"
