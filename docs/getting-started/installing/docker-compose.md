---
title: Docker Compose
---

# Running Kontena using Docker Compose

- [Prerequisities](docker-compose#prerequisities)
- [Installing Kontena Master](docker-compose#installing-kontena-master)
- [Installing Kontena Nodes](docker-compose#installing-kontena-nodes)

## Prerequisities

- Kontena Account
- Docker Engine (<= 1.10 ) & Docker Compose

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master using Docker Compose can be done with following steps:

**Step 1:** create `docker-compose.yml` file with following contents:

```
version: '2'
services:
  haproxy:
    image: kontena/haproxy:latest
    container_name: kontena-master-haproxy
    environment:
      - SSL_CERT=**None**
      - BACKEND_PORT=9292
    ports:
      - 80:80
      - 443:443    
  master:
    image: kontena/server:latest
    container_name: kontena-master
    environment:
      - RACK_ENV=production
      - MONGODB_URI=mongodb://mongodb:27017/kontena
      - VAULT_KEY=somerandomverylongstringthathasatleastsixtyfourchars
      - VAULT_IV=somerandomverylongstringthathasatleastsixtyfourchars
    depends_on:
      - mongodb
  mongodb:
    image: mongo:3.0
    container_name: kontena-master-mongodb
    command: mongod --smallfiles
    volumes:
      - kontena-master-mongodb:/data/db    
volumes:
  kontena-master-mongodb:
```

**Note!** `VAULT_KEY` & `VAULT_IV` should be random strings. They can be generated from bash:

```
$ cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
```

**Note!** If you want to use a SSL certificate you can use the following command to obtain the correct value for `SSL_CERT`:
```
$ awk 1 ORS='\\n' /path/to/cert_file
```

If you don't have a SSL certificate you can generate a self-signed certificate and use that:
```
$ openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout privateKey.key -out certificate.crt
cat certificate.crt privateKey.key > cert.pem
```

**Step 2:** Run command `docker-compose up -d`

After Kontena Master is running you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name <name_for_the_master> http://<master-ip>/
```
* Use `https://` if you have the SSL certificate
* You can give any name to Master. The name is used locally on the CLI to identify the Master.

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> my-grid
```

Or switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

> Recommended minimum initial-size is 3. This means minimum number of nodes in a grid is 3.

Now you can start provision nodes to your host machines.

**Step 1:** copy following `docker-compose.yml` file to each host:

```
agent:
  container_name: kontena-agent
  image: kontena/agent:latest
  net: host
  environment:
    - KONTENA_URI=wss://<master_ip>/
    - KONTENA_TOKEN=<grid_token>
    - KONTENA_PEER_INTERFACE=eth1
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
```

- `KONTENA_URI` is uri to Kontena Master (use ws:// for non-tls connection)
- `KONTENA_TOKEN` is grid token, can be acquired from master using `kontena grid show my-grid` command
- `KONTENA_PEER_INTERFACE` is network interface that is used to connect the other nodes in the grid.

**Step 2:** Run command `docker-compose up -d`

To allow Kontena agent to pull from Kontena's built-in private image registry you must add `--insecure-registry="10.81.0.0/19"` to Docker daemon options on the host machine.

**Note!** While Kontena works ok even with just single Kontena Node, it is recommended to have at least 3 Kontena Nodes provisioned in a Grid.

After creating nodes, you can verify that they have joined Grid:

```
$ kontena node list
```
