Description
===========

You can use this project to deploy a FreeIPA multi-master cluster.

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
