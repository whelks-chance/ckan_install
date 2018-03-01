#!/bin/bash

echo "Installing all the things for webserver"

sudo yum --enablerepo=extras install epel-release
sudo yum update

sudo yum install nano python-devel postgresql postgresql-libs python-pip python-virtualenv git-core java-1.8.0-openjdk redis python-redis gcc postgresql-devel mlocate gd-devel python34-devel uwsgi pcre pcre-devel lsof nginx

# Redis will be used later, no harm in starting it now.
# Also has the affect of caching the sudo password for later actions
echo "Starting redis"
sudo service redis start

echo "Starting Solr install"

# Originally attempted with Solr 7.1.0, assuming 7.x.x isn't too different.
SOLR_VERSION="7.2.1"
echo "Using Solr version" $SOLR_VERSION

if [ ! -f ./solr-$SOLR_VERSION.tgz ]; then
    #TODO check for mirrors?
    echo "Solr .tgz not found, dowloading it from apache.org"
    wget http://apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz
fi

if [ ! -f /etc/init.d/solr ]; then
    echo "Extracting Solr and installing"
    tar xzf solr-$SOLR_VERSION.tgz solr-$SOLR_VERSION/bin/install_solr_service.sh --strip-components=2
    sudo bash ./install_solr_service.sh solr-$SOLR_VERSION.tgz
else
    echo "File /etc/init.d/solr exists, so will not try to install solr again"
fi

echo "Creating solr configs directory /var/solr/data/ckan"
sudo mkdir -p /var/solr/data/ckan

echo "Copying solr configs to var directory"
sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/solrconfig.xml /var/solr/data/ckan/
sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/managed-schema /var/solr/data/ckan/schema.xml
sudo cp -a /opt/solr-$SOLR_VERSION/example/files/conf/. /var/solr/data/ckan/

echo "Making the solr config directory and rearranging files"
sudo mkdir -p /var/solr/data/ckan/conf
sudo cp /var/solr/data/ckan/solrconfig.xml /var/solr/data/ckan/conf/
sudo cp /var/solr/data/ckan/schema.xml /var/solr/data/ckan/conf/
sudo cp /var/solr/data/ckan/elevate.xml /var/solr/data/ckan/conf/

echo "Setting ownership of files."
sudo chown -R solr:solr /var/solr/data/ckan

echo "Restarting everything"
sudo service solr restart
sudo service solr status

echo "Adding ckan core to solr"
sudo -u solr /opt/solr-7.2.1/bin/solr create -c ckan -confdir /var/solr/data/ckan

echo "Beginning CKAN install"
sudo mkdir -p /usr/lib/ckan/default
sudo chown `whoami` /usr/lib/ckan/default

echo "Creating Virtual Environment"
virtualenv --no-site-packages /usr/lib/ckan/default
source /usr/lib/ckan/default/bin/activate

echo "Install tools and CKAN source code into virtualenv"
pip install setuptools==36.1
pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.7.2#egg=ckan'
pip install -r /usr/lib/ckan/default/src/ckan/requirements.txt
deactivate
source /usr/lib/ckan/default/bin/activate

echo "Create a directory to contain the site’s config files"
sudo mkdir -p /etc/ckan/default
sudo chown -R `whoami` /etc/ckan/
sudo chown -R `whoami` ~/ckan/etc

paster make-config ckan /etc/ckan/default/development.ini



