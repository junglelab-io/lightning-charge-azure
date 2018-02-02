#!/bin/bash

# It is running as root
export AZURE_DNS="$1"
export NBITCOIN_NETWORK="$2"
export LETSENCRYPT_EMAIL="$3"
export SUPPORTED_CRYPTO_CURRENCIES="$4"
export LIGHTNING_DOCKER_REPO="$5"
export LIGHTNING_DOCKER_REPO_BRANCH="$6"

export DOWNLOAD_ROOT="`pwd`"
export LIGHTNING_ENV_FILE="`pwd`/.env"

export LIGHTNING_HOST="$AZURE_DNS"
export LIGHTNING_DOCKER_COMPOSE="`pwd`/lightning-charge-azure/Production/docker-compose.$SUPPORTED_CRYPTO_CURRENCIES.yml"
export ACME_CA_URI="https://acme-staging.api.letsencrypt.org/directory"

echo "DNS NAME: $AZURE_DNS"

# Put the variable in /etc/environment for reboot
cp /etc/environment /etc/environment.bak
echo "AZURE_DNS=\"$AZURE_DNS\"" >> /etc/environment
echo "LIGHTNING_DOCKER_COMPOSE=\"$LIGHTNING_DOCKER_COMPOSE\"" >> /etc/environment
echo "DOWNLOAD_ROOT=\"$DOWNLOAD_ROOT\"" >> /etc/environment
echo "LIGHTNING_ENV_FILE=\"$LIGHTNING_ENV_FILE\"" >> /etc/environment


# Put the variable in /etc/profile.d when a user log interactively
touch "/etc/profile.d/lightning-env.sh"
echo "export AZURE_DNS=\"$AZURE_DNS\"" >> /etc/profile.d/lightning-env.sh
echo "export LIGHTNING_DOCKER_COMPOSE=\"$LIGHTNING_DOCKER_COMPOSE\"" >> /etc/profile.d/lightning-env.sh
echo "export DOWNLOAD_ROOT=\"$DOWNLOAD_ROOT\"" >> /etc/profile.d/lightning-env.sh
echo "export LIGHTNING_ENV_FILE=\"$LIGHTNING_ENV_FILE\"" >> /etc/profile.d/lightning-env.sh

# Install docker (https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#set-up-the-repository) and docker-compose 
apt-get update 2>error
apt-get install -y \
    git \
    curl \
    apt-transport-https \
    ca-certificates \
    software-properties-common \
    2>error

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update
apt-get install -y docker-ce

# Install docker-compose
curl -L https://github.com/docker/compose/releases/download/1.17.1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Clone lightning-charge-azure
git clone $LIGHTNING_DOCKER_REPO
cd lightning-charge-azure
git checkout $LIGHTNING_DOCKER_REPO_BRANCH
cd ..

cd "`dirname $LIGHTNING_ENV_FILE`"
docker-compose -f "$LIGHTNING_DOCKER_COMPOSE" up -d 

# Schedule for reboot

echo "
# File is saved under /etc/init/start_containers.conf
# After file is modified, update config with : $ initctl reload-configuration

description     \"Start containers (see http://askubuntu.com/a/22105 and http://askubuntu.com/questions/612928/how-to-run-docker-compose-at-bootup)\"

start on filesystem and started docker
stop on runlevel [!2345]

# if you want it to automatically restart if it crashes, leave the next line in
# respawn # might cause over charge

script
    . /etc/profile.d/lightning-env.sh
    cd \"`dirname \$LIGHTNING_ENV_FILE`\"
    docker-compose -f \"\$LIGHTNING_DOCKER_COMPOSE\" up -d
end script" > /etc/init/start_containers.conf

initctl reload-configuration

# Set .env file
touch $LIGHTNING_ENV_FILE
echo "LIGHTNING_HOST=$LIGHTNING_HOST" >> $LIGHTNING_ENV_FILE
echo "ACME_CA_URI=$ACME_CA_URI" >> $LIGHTNING_ENV_FILE
echo "NBITCOIN_NETWORK=$NBITCOIN_NETWORK" >> $LIGHTNING_ENV_FILE
echo "LETSENCRYPT_EMAIL=$LETSENCRYPT_EMAIL" >> $LIGHTNING_ENV_FILE

chmod +x changedomain.sh
chmod +x lightning-restart.sh
chmod +x lightning-update.sh
ln -s `pwd`/changedomain.sh /usr/bin/changedomain.sh
ln -s `pwd`/lightning-restart.sh /usr/bin/lightning-restart.sh
ln -s `pwd`/lightning-update.sh /usr/bin/lightning-update.sh