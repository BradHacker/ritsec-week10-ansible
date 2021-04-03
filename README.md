# RITSEC Week 10 Ansible Demo

## The Challenge

Name: `FINAL CHALLENGE`
Points: `1000`

Prompt

```
Write a Dockerfile/docker-compose file to setup Webmin web app

Create ansible script that will download docker package, install docker, copy over dockerfiles, build and run docker

Document your steps and please please please submit it. I will love to read them.

Link: https://www.digitalocean.com/community/tutorials/how-to-install-webmin-on-ubuntu-20-04
```

## Part 1 - Dockerfile

Writing a `Dockerfile` and `docker-compose.yml` file is relatively easy.

First, we start with the `Dockerfile`. This describes the steps that are required to set up the container any time it's built.

My [Dockerfile](./Dockerfile) is relatively simple. Let's walk through it step by step.

### Step 1 - Base Image

We need to tell docker what image we want to base our container off of. In this example, I'm using an Ubuntu 20.04 image, but this can be subsituted with whatever distro you'd like. We specify this with the `FROM` command

```docker
FROM ubuntu:20.04
```

### Step 2 - Install necessary packages

I noticed that the base ubuntu image is a little light on packages, so we need to install some prerequisites as well as the `webmin` package as the challenge specifies. We can run the `apt` command (or any command really) using the `RUN` command.

_Note: For simplicity, I merge my apt commands together to be more efficient. Docker will build an intermediate container for each step in the dockerfile, so to save on resources you can merge steps together that are able to be merged._

```docker
RUN apt update && \
  apt install -y wget gnupg gnupg1 gnupg2 && \
  echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list && \
  wget -q -O- http://www.webmin.com/jcameron-key.asc | apt-key add && \
  apt update && \
  DEBIAN_FRONTEND=noninteractive apt install -yq webmin
```

_Note: The `webmin` package has an interactive portion to the post-install script. So to avoid that, we need to specify `DEBIAN_FRONTEND=nointeractive` as well as `-yq` to apt so the container doesn't hang during the build process._

### Step 3 - Expose container ports to the outside

By default, nothing outside the docker container can access the container. So in order to allow us to connect to the admin portion of webmin, we need to open up port `10000`. We do this with the `EXPOSE` command.

```docker
EXPOSE 10000
```

And that's all for our `Dockerfile`!

## Part 2 - Docker-Compose

Docker compose is a way to easily manage multiple containers within a single project. For this example, we only have one container, however multiple more could be added and interconnected to the same `docker-compose.yml`.

My [docker-compose.yml](./docker-compose.yml) is very simple. Here are the 3 main parts to it.

### Version

Every `docker-compose.yml` starts off with a version. We specify this like so:

```yaml
version: "3"
```

### Services

Services are the containers we want to spin up with our project. Again, for this example, we only have one container named `webmin`. We need to specify where the `Dockerfile` is located for it, and we can just do this by specifying a `context` (usually the root of that containers source code). We also need to map this container's ports to our host machine's ports using the `ports` option. We also attach this container to a network with the `networks` option.

```yaml
services:
  webmin:
    build:
      context: .
    ports:
      - "10000:10000"
    networks:
      - default
```

### Networks

Networks are what interconnect our containers together. They can also be used with a `bridge` driver to connect them to the host. I just define a network named `default` here.

```yaml
networks:
  default:
    driver: bridge
```

## Part 3 - Ansible

This is my very first time writing ansible, so please forgive any mistakes or inefficiencies.

### Inventory

For our ansible projects, we can start out by making an inventory file (I use `ini` format here in [inventory.ini](./inventory/inventory.ini)). This is where we list the IP addresses/hostnames of the systems we want to interact with.

I used an Ubuntu 20.04 VM as my target host and I listed that as such:

```ini
[bradserv]
192.168.128.7
```

I then configured some default variables to use for the host as such:

```ini
[bradserv:vars]
ansible_connection=ssh
host_key_checking=False
become=yes
ansible_sudo_pass="closedstackftw"
```

### Playbook

Since we only have one host, we can specify the playbook ([week10.yml](./playbooks/week10.yml)) to run for all hosts:

```yaml
---
- hosts: all
  become: true
```

Then we have to list tasks for the hosts to run. Here are a bunk of tasks that install docker and python docker packages ansible wants us to have.

```yaml
tasks:
  - name: Docker GPG Key
    apt_key:
      url: https://download.docker.com/linux/ubuntu/gpg
      state: present

  - name: Docker APT Repo
    apt_repository:
      repo: deb https://download.docker.com/linux/ubuntu bionic stable
      state: present

  - name: Update and install Docker CE
    apt:
      name: docker-ce
      update_cache: yes
      state: latest

  - name: Install pip
    apt:
      name: python3-pip
      update_cache: yes
      state: present

  - name: Install docker compose python library
    pip:
      name: docker-compose
```

Then we have tasks that create us a `webmin` directory and copy over our two docker files:

```yaml
 - name: Create webmin directory
    file:
      path: ~/webmin
      state: directory

  - name: Copy dockerfile
    copy:
      src: ../Dockerfile
      dest: ~/webmin/Dockerfile

  - name: Copy docker-compose
    copy:
      src: ../docker-compose.yml
      dest: ~/webmin/docker-compose.yml
```

Lastly, we need to bring up the docker-compose containers, we can do this with an ansible community collection `community.docker.docker_compose`.

We can install this via the following command:

```
ansible-galaxy collection install community.docker
```

And then our task becomes:

```yaml
- name: Run docker compose
  community.docker.docker_compose:
    project_src: ~/webmin
    state: present
```

And that's it! Now we can run the ansible playbook via:

```
ansible-playbook -i inventory/inventory.ini playbooks/week10.yml
```

Then we just sit back and relax while our webmin instance gets deployed.
