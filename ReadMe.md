# Traefik v2

## Initial Setup

### Step 1: Set Up Ports
Open in firewall to ensure external access:
```
sudo ufw allow 80   # Traefik http  
sudo ufw allow 443  # Traefik https
```

**port forward** from the Router to host machine, if running locally.

*With this setup, you only need to expose these ports externally. Any RPC ports are managed internally by Docker*

Should you need to change these ports edit in the docker-compose.yml  
```
--entryPoints.http.address=:<new-port>
--entryPoints.https.address=:<new-port>
```

### Step 2: Setup Cloudflare and doman

**Cloudflare:** is global web infrastructure, mainly DNS management, which translates human-readable domain names into IP addresses, for internet navigation.

Docker manages its internal DNS service for handling requests within the host machine between containers, but Cloudflare will be used for the external part for public facing services.

**1. Setup Cloudfalre Account**

Create account with Cloudflare [here:]([https://www.cloudflare.com/en-gb/](https://www.cloudflare.com/en-gb/))

**2. Register Domain**

On your dashboard go to ‘Add a site’ and create a domain name of your choice, then select which plan suits your needs.

this domain name will be used for variable `$DOMAINAME` later

**3. Create Domain Record**

Profile > DNS > Records > add record

-`Type= A`
-`Name= <YOUR DOMAIN NAME>`
-`Content= <Your Public IP of the Host machine (Traefik)>`
-`Proxy Status= DNS only`  
-`TTL= Auto`

**3. Create sub-domains Records for each service**

Domain profile > create sub-domains for number of services

-`Type= CNAME`
-`Name= <Any Name (advised to make relevant eg. ethereum)>`
-`Content=<YOUR DOMAIN NAME>`  
-`Proxy Status= DNS only`  
-`TTL= Auto`

### Step 3: Setup Docker Networking for Node Services

**Define Networks for Node Services**

In this setup, a docker network `net` will be created, this will be the external network for other docker containers to connect too. Note: Network can be named anything: net/proxy/sedge but must be the same across all connected containers 

See Docker Networks in use
```
docker network ls  
```

In `docker-compose.yml` for node services: change `network` accordingly and define the `ipv4_address` for the container/s you will connect to Traefik.

for example the first container/service should be `192.168.50.101` and subsequent services `...102, ....103, ....`

```
services:
  <service>:
    .
    .
    networks:
      net:
        ipv4_address: 192.168.50.101
```
if you have multiple services then make sure the network is the same example:
```
Services:
  <service>:
  .
  .
  networks:
    net:
      ipv4_address: 192.168.50.101  
  <service-2>:
  .
  .
  networks:
    net:
```
At the bottom of the docker-compose, for other docker containers that need to connect to this network
```
networks:
  net:
    external: true
```
**Define ports for node services.** Confirm `http rpc` ports are set correctly

Ensure ports are configured and exposed to the docker network. In docker-compose.yml
```
expose:
 - <port>_
```
This exposes the needed ports to the docker network internally. In this setup, you don’t need to expose ports to the host or externally, as it only needs to be exposed to Traefik which handles external requests.

---
# TRAEFIK

**Traefik:** is an open-source dynamic reverse proxy designed for modern microservices, it can be used to set up and maintain reverse proxies for routing and securing web traffic for services such as docker containers.

Note: this is a forked repo from Traefik’s open code base, with more limited and example configurations that can be easily edited. [Forked from]([https://github/CVjoint/traefik2](https://github/CVjoint/traefik2))

From this, I have edited the configurations to better fit for node-services such as Ethereum endpoint to sub-domain.

**Clone Repo**
```
mkdir docker && cd docker
git clone https://github.com/GLCNI/traefik2.git
```
## Setup Traefik

### Option 1: Interactive Script Setup

```
cd docker/traefic2
chmod a+x ./run_traefik_setup.sh  
./run_traefik_setup.sh
```
This script does the following:

- Define Variables 
- Create Basic Authentication credentials
- Create acme.json file for cloudflare certificates
- Create Rules for each node service to connect to Traefik

### Option 2: Setup Manual

**1. Write variables**

enter values in the `.env` for
```
DOMAINNAME=""           # Domain name setup via CloudFlare
CLOUDFLARE_RESOLVER=""  # 1.1.1.1 for Cloudflare DNS server
CLOUDFLARE_EMAIL=""     # your CloudFlare account Email
TRAEFIK2DIR=""          # enter the full path to the working directory where repo was cloned
CLOUDFLARE_API_KEY=""   # This is your Global API Key  
```

Global API key can be found on Cloudflar account: `profile > API tokens > Global API Key > View`

**2. Setup password for basic-auth**

Create a hashed password
```  
sudo apt install apache2-utils  
echo $(htpasswd -nb <USER> <password>)  
```

Add the output to the file `./traefik/rules/basic-auth.toml`

**Additional info:** Format for accessing node service url with basic auth: 
`https://<user>:<password>@<service-name>.<domain-name>`

To disable basic-auth, in any `xhost-<node-service>.toml` file in `/rules`, comment out the following line:
`middlewares = ["basic-auth"] `

**3. Create acme.json for credentials**

This is where cloudflare certificates will be stored
```
touch ./traefik/acme/acme.json  
chmod 600 ./traefik/acme/acme.json
```

**4. Create Rules for Node-Services**

The directory `/traefic/rules_examples/` contains example `toml` configuration files, copy to `/traefic/rules/` whichever files are relevant or create new rules from this template.

```
cp ./traefik/rules_examples/xhost-node-template.toml ./traefik/rules/xhost-<YOUR NODE NAME>.toml
```

Define IP for node service docker container:
`url = "http://<Assigned IP>:<http rpc port>"`
example:
`url = "http://192.168.50.101:8545"`

-----
Additional context: in node service (ethereum) `docker-compose.yml` example:

networks settings for the service: defined an IP for container as follows:
`ipv4_address: 192.168.50.101`

Relevant argument for `http rpc`, for `nethermind ethereum execution client`  :
`--http.port=8545`

Which means traefik will be looking for the internal docker ip `192.168.50.101` over port `8545` and forwarding requests to the URL `ethereum.<domain-name>`

-----

**5. Configure Traefik**

The configuration `docker-compose.yml` file is in the main directory `traefik2`

**Edit Version:** find the latest releases [here](https://github.com/traefik/traefik/releases)
```
traefik:
  container_name: traefik
  image: traefik:v2.10.4
```

**Networks:**
This setup will be using `net` name for the docker network and Traefic container will set the internal IP to 192.168.50.254

**Create Network**
```  
docker network create --gateway 192.168.50.1 --subnet 192.168.50.0/24 net  
```

**5. Start Traefik**

From working directory
```  
docker compose up -d  
```

**check logs**  

```  
docker logs -f traefik  
```

**Check certificates.**

Confirm that certificates are being created for services, this should be populated.
```  
cat ./traefik/acme/acme.json  
```

**Confirm RPC request**

Confirm that you can connect to RPC API via sub-domain url and that basic auth works.  example for Ethereum:
```  
curl -X POST -H "Content-type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' https://<basic-auth-user>:<password>@ethereum.<domain-name>  
```

---
## Setup Glances (optional)

**Glances:** is software to monitor containers and hardware

create directory
```
cd docker  
mkdir glances
```

copy the glances config from traefik
```
cp traefik2/traefik/ymlfiles/glances.yml glances/docker-compose.yml
```

**Create CNAME for glances on Cloudflare.**

Similarly to creating node services, create a name for a new service (this must match in rules file)

Add record > enter name=name for service  > enter target =domain name

**Enter domain name**
```
cd glances  
nano docker-compose.yml
```
replace $DOMAINNAME with your domain name setup with cloudflare

**Start glances**  
```
docker compose up -d
```

**View glances**

Open a web browser and enter: `https://glances.<your-domain-name>`
