# Deployment of Identity Management system

## Description

The goal of this project is to provide a way for deploying IDM system in a cloud.
The deployment should be easy, reliable, reproducabel and idempotent.
It should be possible to use this deployment for disaster recovery.

## Used tools

We use [FreeIPA](https://www.freeipa.org/page/Main_Page "The Open Source Identity Management Solution") as our IDM soulution.

This project deploys the IDM to the [Hetzner Cloud](https://www.hetzner.com/cloud), but it should be possible to use this project as inspiration for the development of a project deploying the IDM to another cloud.

We provision our servers using [Terraform](https://www.terraform.io/), and if it was decided to go with another cloud, it is possible to use an orchestration tool from that cloud such as [AWS CloudFormation](https://aws.amazon.com/cloudformation/) or [Openstack Heat](https://wiki.openstack.org/wiki/Heat) or any other prefered one.

FreeIPA server runs inside a container. We use [Podman](https://podman.io/) as a container engine. Podman is a daemonless container engine for developing, managing, and running OCI Containers on your Linux System.

We use [CentOS](https://centos.org/) 8 Linux distribution as a base operating system, but it should be possible to use any distribution that is able to run Podman, uses systemd, and if its kernel has the support for IPvlans and network namespaces.

[Pyroute2](https://pypi.org/project/pyroute2/ "Python netlink library") is used to create an ipvlan and network namespace for containers network.

After servers are provisioned [Ansible](https://www.ansible.com/) is used for the deployment and the configuration of IDM system.

## Preparation

### External dependencies

### Local configuration

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

