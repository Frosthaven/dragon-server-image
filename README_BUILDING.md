# 🐲 dragon-server

[Back to README](README.md)

## Install Requirements
*Note to Windows users: Ansible does not have a Windows binary. It is
recommended to install your tools AND any system level environmental variables
in WSL.*

Follow the installation guide for the following tools:

- [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

## Building the Image

### Digital Ocean Snapshot
*Requires `DIGITALOCEAN_TOKEN` environmental variable to be set.*

```shell
packer init ./digitalocean;
packer build ./digitalocean;
```

### Amazon Web Services AMI

*Requires AWS credentials. Set the following environment variables:*
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- `AWS_REGION` (optional) - Target region, defaults to `us-east-1`

```shell
packer init ./aws;
packer build ./aws;
```

The build uses the latest Ubuntu 24.04 LTS AMI from Canonical as the base image.
Once built, you can copy the AMI to other regions via the AWS Console or CLI.

