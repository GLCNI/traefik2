#!/bin/bash

#######################################################
# ENTER VARIABLES to the .env file 
#######################################################
# Prompt user for values
read -p "Enter Domain Name: " DOMAINNAME
read -p "Enter Cloudflare Resolver (use 1.1.1.1 for Cloudflare DNS server): " CLOUDFLARE_RESOLVER
read -p "Enter your CloudFlare account Email: " CLOUDFLARE_EMAIL
TRAEFIK2DIR="$PWD"  # Get the current working directory
read -p "Enter your Global API Key: " CLOUDFLARE_API_KEY

# Write values to .env file
echo "DOMAINNAME=\"$DOMAINNAME\"" > .env
echo "CLOUDFLARE_RESOLVER=\"$CLOUDFLARE_RESOLVER\"" >> .env
echo "CLOUDFLARE_EMAIL=\"$CLOUDFLARE_EMAIL\"" >> .env
echo "TRAEFIK2DIR=\"$TRAEFIK2DIR\"" >> .env
echo "CLOUDFLARE_API_KEY=\"$CLOUDFLARE_API_KEY\"" >> .env

echo ".env file updated!"

#######################################################
# CREATE BASIC AUTH CREDENTIALS
#######################################################
# Setup Basic auth details
echo "this setup will use basic authentication for extra security"
echo "should you wish to disable, this can be disabled from /rules/ <node-service>.toml"
# Install apache2-utils
sudo apt install -y apache2-utils

# Prompt user for Basic Auth credentials
read -p "Enter Basic Auth Username: " BASIC_USER
    # Enter Password Loop
    while true; do
        read -s -p "Enter Basic Auth Password: " BASIC_PASS
        echo
        read -s -p "Confirm Basic Auth Password: " BASIC_PASS_CONFIRM
        echo

        # Check if passwords match
        if [ "$BASIC_PASS" == "$BASIC_PASS_CONFIRM" ]; then
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done

# Generate htpasswd string
HTPASSWD_OUTPUT=$(htpasswd -nb $BASIC_USER $BASIC_PASS)

# Update basic-auth.toml file
AUTH_FILE="./traefik/rules/basic-auth.toml"

# Replace the placeholder with the actual value
ESCAPED_HTPASSWD_OUTPUT=$(echo "$HTPASSWD_OUTPUT" | sed -e 's/[]\/$*.^[]/\\&/g')
sed -i "s|<enter-output-from-command-above-here>|$ESCAPED_HTPASSWD_OUTPUT|" $AUTH_FILE

echo "Basic Auth credentials updated in $AUTH_FILE!"

#######################################################
#CREATE acme.json
#######################################################

touch ./traefik/acme/acme.json
chmod 600 ./traefik/acme/acme.json

#######################################################
# CREATE RULES
#######################################################
# Create Rules
while true; do
    # Prompt user for service rule details
    read -p "Enter a Name for the service rule, eg: ethereum: " NODE_NAME
    echo "define the IP for internal docker networking, advised to use 192.168.50.101 then ...102, ...103, ect. for subsequent rules" 
    read -p "Enter the Service URL: " SERVICE_URL
    echo "define the http rpc port for the service, ex: 8545 is default for ethereum, advised to check the configuration for that service"
    read -p "Enter the Service Port: " SERVICE_PORT

    # Create a copy of the template
    TEMPLATE="./traefik/rules_examples/xhost-node-template.toml"
    NEW_RULE="./traefik/rules/xhost-$NODE_NAME.toml"
    cp $TEMPLATE $NEW_RULE

    # Replace placeholders with provided values
    sed -i "s|\$NODE_NAME|$NODE_NAME|g" $NEW_RULE
    sed -i "s|\$SERVICE_URL|$SERVICE_URL|g" $NEW_RULE
    sed -i "s|\$SERVICE_PORT|$SERVICE_PORT|g" $NEW_RULE
    sed -i "s|\$DOMAINNAME|$DOMAINNAME|g" $NEW_RULE

    echo "Rule created at $NEW_RULE!"

    # Ask user if they want to create another rule
    read -p "Would you like to create another rule? (yes/no): " CONTINUE
    if [[ "$CONTINUE" != "yes" ]]; then
        break
    fi
done
