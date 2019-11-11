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
