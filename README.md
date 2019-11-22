# Deployment of Identity Management system

## Description

The goal of this project is to provide a way for deploying IDM system in a cloud.
The deployment should be easy, reliable, reproducible and idempotent.
It should be possible to use this deployment for disaster recovery.

## Used tools

We use [FreeIPA](https://www.freeipa.org/page/Main_Page "The Open Source Identity Management Solution") as our IDM solution.

This project deploys the IDM to the [Hetzner Cloud](https://www.hetzner.com/cloud), but it should be possible to use this project as inspiration for the development of a project deploying the IDM to another cloud.

We provision our servers using [Terraform](https://www.terraform.io/), and if it was decided to go with another cloud, it is possible to use an orchestration tool from that cloud such as [AWS CloudFormation](https://aws.amazon.com/cloudformation/) or [Openstack Heat](https://wiki.openstack.org/wiki/Heat) or any other preferred one.

FreeIPA server runs inside a container.
We use [Podman](https://podman.io/) as a container engine.
Podman is a daemonless container engine for developing, managing, and running OCI Containers on your Linux System.

We use [CentOS](https://centos.org/) 8 Linux distribution as a base operating system, but it should be possible to use any distribution that is able to run Podman, uses systemd, and if its kernel has the support for IPvlans and network namespaces.

[Pyroute2](https://pypi.org/project/pyroute2/ "Python netlink library") is used to create an ipvlan and network namespace for containers network.

After servers are provisioned [Ansible](https://www.ansible.com/) is used for the deployment and the configuration of IDM system.

## Preparation

### External dependencies

#### Terraform configuration

This project uses Terraform for infrastructure provisioning and uses Terraform remote backend for keeping the state of infrastructure for collaborative work.

To be able to use the remote backend we need to register (or have already registered) __*organizaton_name*__ organization at [Terraform Cloud](https://app.terraform.io/).
Also we need to create __*workspace_name*__ workspace for this deployment.
This workspace should have __Local__ Execution mode in its settings, so it will be used only to store the state of our deployment.
This requierements comes from the fact that there is a __local-exec__ provisioner in the projects Terraform code, that generates Ansible inventory file to be used in the next step.

#### Hetzner cloud configuration

It is assumed that there is an account Hetzner, so we are allowable to create new entities in Hetzner Cloud.
We should create a project that will include infrastructure for this project.

### Local configuration

#### Terraform

##### Terraform CLI installation

Use this [manual](https://learn.hashicorp.com/terraform/getting-started/install.html) to install Terraform CLI tool.

##### Terraform access configuration

In order to be able to access Terraform Cloud from Terraform CLI we need generate an access token in "User settings" at Terraform Cloud, and put it into the `~/.terraformrc` file:
```
credentials "app.terraform.io" {
  token = "xxxxxx.atlasv1.zzzzzzzzzzzzz"
}
```

##### Terraform backend initialisation:

In order to initialise Terraform backend there shoud be created `backend.hcl` file in the root directory of this project with the following content:
```
# backend.hcl
hostname = "app.terraform.io"
organization = "<organizaton_name>"
workspaces { name = "<workspace_name>" }
```
Replace words in `< >` with your __*organizaton_name*__ and __*workspace_name*__.

Although this file containes no sensitive information it is included into `.gitignore` file.

Run the following command for terraform initialisation:
```bash
terraform init -backend-config=backend.hcl
```

#### Hetzner

##### Hetzner CLI installation

Use this [manual](https://community.hetzner.com/tutorials/howto-hcloud-cli) for CLI installation and configuration.

#### Ansible

##### Ansible installation

Use this [manual](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) for Ansible installation.

## Basement

### Disclosure

The creation of some base entities lies outside of the code of this project for certain reasons.

### Mapping definiton

We need to define some values and map them to each other. For each node we need to define following values:
* `server` - short hostname that will be assigned to a single FreeIPA instance. Part of FQDN assigned to the Floating IP-address used by the FreeIPA instance.
* `host` - short hostname that will be assigned to a server running a single FreeIPA container.
* `location` - the name of a location of Data Center where the `host` is running.

Example values for a single node:
```
server: dc00
location: nbg1
host: etc00
```
To prevent an ocasional selection of an entity we define additional key-value map for all objects:
```
object: freeipa
```
The code containes some default mappings, but this can be easily changed by assigning different values to variables.
See [configuration](#configuration) chapter.

### Floating IP addresses and DNS records

#### Explanation

IDM systems deployed by this project containe DNS to manage their domain (subdomain) zone.
It is quite hard to automate the configuration process of a domain delegation, since there are so many variants.
At the same moment it is quite simple task for manual configuration, and this configuration is really static, so it can be done once before running this project.

Floating IP address will be assigned to an IPVlan interface in a network namespace that is going to be used by a container running FreeIPA.
So each FreeIPA instance will have its own static ip-address.
These static ip-address and network namespace won't be shared with a host VM.

#### Floating IP creation

1. Create Floating IP using `hcloud` utility (*example*):
   ```bash
   hcloud floating-ip create --description dc00 --home-location nbg1 --type ipv4
   hcloud floating-ip create --description dc01 --home-location fsn1 --type ipv4
   hcloud floating-ip create --description dc10 --home-location hel1 --type ipv4
   ```

2. Configure a domain delegation for your domain (subdomain) using created ip-addresses.

3. Set reverse DNS of Floating IP addresses (*example*):
   ```bash
   hcloud floating-ip set-rdns --hostname dc00.<domain> FLOATING_IP_ID
   ```
   Do this for each floating ip address created in the first step.

4. Add labels to Floating IP addresses (*example*):
   ```bash
   hcloud floating-ip add-label FLOATING_IP_ID object=freeipa
   hcloud floating-ip add-label FLOATING_IP_ID server=dc00
   hcloud floating-ip add-label FLOATING_IP_ID location=nbg1
   hcloud floating-ip add-label FLOATING_IP_ID host=etc00
   ```
   Repeat these commands for every floating ip address in this setup.

### Data volumes

#### Explanation

This setup relies on a persistence of IDM data in external volumes.
So we keep the process of volumes creation outside of the projects code to prevent accedentally data deletion.

That also allows us to easily recover in case of host failure.

#### Volumes creation

1. Create a volume using `hcloud` utility (*example*):
   ```bash
   hcloud volume create --location nbg1 --name dc00 --size 16
   hcloud volume create --location fsn1 --name dc01 --size 16
   hcloud volume create --location hel1 --name dc10 --size 16
   ```

2. Add labels to volumes (*example*):
   ```bash
   hcloud volume add-label VOLUME_ID host=etc00
   hcloud volume add-label VOLUME_ID object=freeipa
   ```
   Repeat this for every volume.

## Deployment

### Configuration

It is important to be sure that we went through all previous step and have `backend.hcl` file created and Terraform initialisated.

We need to define values for some variables:
* `hcloud_token` - __required__;
* `hetzner_dns` - optional, a list with ip-addresses of DNS. The default list defined in the code;
* `server` - optional, a mapping of server names to servers locations (data centers). The default mapping defined in the code. Be aware this mapping should be relevant for labels of volumes and floating ip addresses;
* `server_type` - optional, the default value defined in the code. Check Hetzner for all possible values;
* `ssh_key` - __required__. An ID of your public key previously uploaded to Hetzner cloud;
* `ssh_key_private` - __required__. A string with a path to the private ssh-key;
* `remote_user` - optional. The default user for OS images in Hetzner cloud is `root`;
* `server_image` - optional. A name of OS image, the default value defined in the code;
* `domain` - __required__. A name for domain zone that will be managed by IDM system;

There are several way to do that:

* Use environment variables:
   It is possible to create executalbe `vars.sh` file with the following content:
   ```bash
   #!/usr/bin/env bash
   export HCLOUD_TOKEN=...
   export TF_VAR_ssh_key=...
   export TF_VAR_ssh_key_private=...
   export TF_VAR_domain=...
   ```
* Create `terraform.auto.tfvars` file containning variable in Terraform format:
   ```
   server_type = "..."
   ssh_key_private = "/Users/username/.ssh/id_ed25519"
   remote_user = "..."
   server_image = "..."
   ssh_key = "..."
   domain = "..."
   hcloud_token = "..."
   ```

Both of these files are mentioned in `.gitignore` file.

### Resource provisioning

Required tools
--------------

* Terraform

* Ansible

Involved projects
-----------------

* FreeIPA - server is installed as a container.

* Podman - a runtime for container.

* pyroute2 - we run a python script before we start FreeIPA service, so we are sure that our network is configured properly.

Operating system
----------------

CentOS 8 (or compatipable) - this project uses ipvlan with network namespacing.
Be sure that your kernel supports this.

How-to deploy
-------------

Define all terraform variables by declaring environment variables or by definning them down in `*.auto.tfvars` file.

Run:
```
terraform apply
```
The last resource uses `local-exec` to create an inventory file for Ansible playbook.
This inventory will be needed to run the playbook to deploy FreeIPA cluster.
You also need to pass DS manager password and Admin password to this playbook.
You can do it by:

* passing them as `--extra-vars` parameter to `ansible-playbook` command, if you are sure that your CLI history is a safe place;

* creating a file with variables, protected by `ansible-vault`.
    ```yaml
    ---
    ds_password: "some_secret_password"
    admin_password: "some_secret_password"
    ...
    ```

The example of ansible command:
```bash
ansible-playbook -i inventory.yml --extra-vars "@varsafe.yml" --ask-vault-pass -vvv main.yml
```

