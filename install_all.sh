#!/bin/bash

echo "Installing all the things for webserver"

sudo yum install nano python-devel postgresql postgresql-libs python-pip python-virtualenv git-core java-1.8.0-openjdk redis python-redis gcc postgresql-devel mlocate gd-devel python34-devel uwsgi pcre pcre-devel lsof nginx

# Redis will be used later, no harm in starting it now.
# Also has the affect of caching the sudo password for later actions
echo "Starting redis"
sudo service redis start


SOLR_VERSION="7.2.1"
echo "Using Solr version" $SOLR_VERSION

if [ ! -f ./solr-$SOLR_VERSION.tgz ]; then
    echo "Solr .tgz not found, dowloading it"
    wget http://apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz
fi

# 
SOLR_VERSION="7.2.1"
echo "Using Solr version" $SOLR_VERSION



if [ ! -f ./solr-$SOLR_VERSION.tgz ]; then

    echo "Solr .tgz not found, dowloading it"

    wget http://apache.org/dist/lucene/solr/$SOLR_VERSION/solr-$SOLR_VERSION.tgz

fi



echo "Extracting Solr and installing"

tar xzf solr-$SOLR_VERSION.tgz solr-$SOLR_VERSION/bin/install_solr_service.sh --strip-components=2

sudo bash ./install_solr_service.sh solr-$SOLR_VERSION.tgz



echo "Copying solr configs to var directory"

sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/solrconfig.xml /var/solr/data/ckan

sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/managed-schema /var/solr/data/ckan/schema.xml

sudo cp -a /opt/solr-$SOLR_VERSION/example/files/conf/. /var/solr/data/ckan/



echo "Making the solr config directory and rearranging files"

sudo mkdir -p /var/solr/data/ckan/conf



sudo cp /var/solr/data/ckan/solrconfig.xml /var/solr/data/ckan/conf/

sudo cp /var/solr/data/ckan/schema.xml /var/solr/data/ckan/conf/



sudo chown -R solr:solr /var/solr/data/ckan



