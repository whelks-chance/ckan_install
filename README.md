# Install guide for CKAN and Django on CentOS7


Most easily, CKAN is installed on Ubuntu 14.04 or 12.04 from the repos, as described [here](http://docs.ckan.org/en/latest/maintaining/installing/install-from-package.html).

Unfortunately this comes with a few issues, such as it being very outdated now, and the packages are very old. Writing this in early 2018, the Ubuntu default process installs Solr v1.0, first released in 2010. This is not ideal.

Further, the Virtual Machines I have been provisioned with were CentOS 7, and so many of the instructions found online were inappropriate. This post is an effort to correct that.

## Setup procedure

* [Initial setup](#initial_setup)
* [Installing PostgreSQL](#postgresdb)
* [Installing required packages](#required_packages)
* [Installing Solr v7.1.0](#install_solr)
* [Installing CKAN](#install_ckan)
* [Installing Django](#install_django)
* [Setting up Nginx](#install_nginx)
    - Static files
    - Django
    - CKAN
    - Solr
* [Setting up UWSGI](#install_uwsgi)
* [Setting up services](#service_setup)
* [DataPusher](#install_datapusher)
* [Lets Encrypt](#install_https)
* [Firewall](#firewall)


## <a name="initial_setup">Initial Setup</a>


```
sudo yum update
sudo yum install git
```

Grab these scripts

```
git clone https://github.com/whelks-chance/ckan_install.git
chmod +x ckan_install/install_all.sh

```


## <a name="postgresdb">Installing PostgreSQL</a>


This is on a separate VM, so appropriate ports etc will be configured.
Lots of directions learnt from [here](http://www.postgresonline.com/journal/archives/362-An-almost-idiots-guide-to-install-PostgreSQL-9.5,-PostGIS-2.2-and-pgRouting-2.1.0-with-Yum.html) and [here](http://www.kelvinwong.ca/tag/pg_hba-conf/).

```
sudo rpm -ivh http://yum.postgresql.org/9.5/redhat/rhel-7-x86_64/pgdg-centos95-9.5-3.noarch.rpm

sudo yum install postgresql95-server postgis24_95 nano
```

If we want to change some defaults

```
sudo nano /etc/sysconfig/pgsql/postgresql-9.5 

source /etc/sysconfig/pgsql/postgresql-9.5
```

Start it up

```
sudo -u postgres /usr/pgsql-9.5/bin/initdb -D /var/lib/pgsql/9.5/data

sudo service postgresql-9.5 start 

sudo service postgresql-9.5 status 
```

Allow access through the firewall from the IP address of the web-server VM.

```
sudo firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="XXX.XXX.XXX.XXX" port port=5432 protocol="tcp" accept' 
```


Add the ports/ port ranges/ IP addresses

Add line to pg_hba.conf to allow access to ckan host IP address

```
nano /var/lib/pgsql/9.5/data/pg_hba.conf

host    all         all         XXX.XXX.XXX.XXX/32          trust
```

Allow PostgreSQL to listen

Change line to : listen_addresses = '*'

```
nano /var/lib/pgsql/9.5/data/postgresql.conf
```

Setup the database user and tables
```
sudo -u postgres createuser -S -D -R -P ckan_default

sudo -u postgres createdb -O ckan_default ckan_default -E utf-8
```

## <a name="required_packages">Installing required packages</a>


Using yum rather than apt-get, several packages change name from Ubuntu to CentOS7

Using the list from [here](http://docs.ckan.org/en/latest/maintaining/installing/install-from-source.html#install-the-required-packages)

| Package | Description |
| ---------------|----------------|
| Python | The Python programming language, v2.7 |
| PostgreSQL | The PostgreSQL database system, v9.2 or newer |
| libpq | The C programmer’s interface to PostgreSQL |
| pip | A tool for installing and managing Python packages |
| virtualenv | The virtual Python environment builder |
| Git | A distributed version control system |
| Apache Solr | A search platform |
| Jetty | An HTTP server (used for Solr). |
| OpenJDK JDK | The Java Development Kit (used by Jetty) |
| Redis | An in-memory data structure store |
| Nginx | A webserver |


This should be all of them...

```
sudo yum install python-devel postgresql postgresql-libs python-pip python-virtualenv git-core java-1.8.0-openjdk redis python-redis gcc postgresql-devel mlocate gd-devel python34-devel uwsgi pcre pcre-devel lsof nginx
```


Start redis now

```
service redis start 
```


## <a name="install_solr">Installing Solr</a>


The default Solr from ubuntu is 1.0, from 2010. Latest is 7.1.0. This is annoying. 

For solr 7.x the setup is awkward: 

The default location for solr cores is "/var/solr/data/ckan/"

```
sudo cp /opt/solr-7.1.0/example/files/conf/solrconfig.xml /var/solr/data/ckan

sudo cp /opt/solr-7.1.0/example/files/conf/managed-schema /var/solr/data/ckan/schema.xml

cp -a /opt/solr-7.1.0/example/files/conf/. /var/solr/data/ckan/

mkdir -p /var/solr/data/ckan/conf

cp /var/solr/data/ckan/solrconfig.xml /var/solr/data/ckan/conf/

cp /var/solr/data/ckan/schema.xml /var/solr/data/ckan/conf/

chown -R solr:solr /var/solr/data/ckan
```

**The install script should copy the schema.xml and solrconfig files into place, but for reference, this is what the changes are doing.**

The new schema format is missing bits, and needs bits removed, and solrconfig needs to be told to use the previous mechanisms: https://stackoverflow.com/a/43713143

Solrconfig needs:

```
<schemaFactory class="ClassicIndexSchemaFactory"/>
```

and remove the AddSchemaFieldsUpdateProcessorFactory section from the updateRequestProcessorChain config in your solrconfig.xml

As described in: https://stackoverflow.com/a/31721587/2943238


From schema.xml, remove: ( <! -- or comment out. --> Examples here need the space removed between <! and -- )


```
defaultSearchField>text /defaultSearchField>

solrQueryParser defaultOperator="AND"/>
```

As described in: https://github.com/ckan/ckan/issues/3829

Schema needs stuff from :https://github.com/nextcloud/nextant/issues/208

```
<! -- Some description to find it later -->

<fieldType name="pints" class="solr.TrieIntField" docValues="true" multiValued="true"/>

<fieldType name="plongs" class="solr.TrieLongField" docValues="true" multiValued="true"/>

<fieldtype name="pfloats" class="solr.TrieFloatField" docValues="true" multiValued="true"/>

<fieldType name="pdoubles" class="solr.TrieDoubleField" docValues="true" multiValued="true"/>

<fieldType name="pdates" class="solr.DatePointField" docValues="true" multiValued="true"/>
```

And

```
<! -- Some description to find it later --> 

<dynamicField name="*_pdts" type="pdates" indexed="true" stored="true"/>
```

## <a name="install_ckan">Installing CKAN</a>


[These instructions here explain most of it.](http://docs.ckan.org/en/latest/maintaining/installing/install-from-package.html)

**production.ini has lots of additions, including passwords.**

Ckan .ini file, change the site.root to /ckan/ so that nginx can forward the resource files correctly.

*TODO: CORS without just doing allow all. Figure out whitelists.*
*http://docs.ckan.org/en/latest/maintaining/configuration.html#ckan-cors-origin-allow-all*
*ckan.cors.origin_allow_all = true*

### CKAN Plugins

```
pip install ckanext-geoview 
```

Map projections are tricky, so we need to add proj4j

As per https://github.com/ckan/ckanext-geoview/issues/40#issuecomment-215532213 Need new /proj4.js file to fix "No projection definition for code EPSG:27700" 

https://github.com/ckan/ckanext-geoview/blob/master/ckanext/geoview/public/resource.config 

in file:

```
nano ./ckan/lib/default/lib/python2.7/site-packages/ckanext/geoview/public/resource.config
```

add the line to the *geojson =* section (to tell it where to look for definitions):

```
js/vendor/proj4js/proj4_defs.js
```

then, add the definition itself in the new file

```
nano ./ckan/lib/default/lib/python2.7/site-packages/ckanext/geoview/public/js/vendor/proj4js/proj4_defs.js 
```

add the single line:

```
proj4.defs([['EPSG:4326',    '+title=WGS 84 (long/lat) +proj=longlat +ellps=WGS84 +datum=WGS84 +units=degrees'],  ['EPSG:4269',    '+title=NAD83 (long/lat) +proj=longlat +a=6378137.0 +b=6356752.31414036 +ellps=GRS80 +datum=NAD83 +units=degrees'], ["EPSG:27700","+proj=tmerc +lat_0=49 +lon_0=-2 +k=0.9996012717 +x_0=400000 +y_0=-100000 +ellps=airy +towgs84=446.448,-125.157,542.06,0.15,0.247,0.842,-20.489 +units=m +no_defs"]]); 
```

Adding plugins to production.ini:

```
ckan.plugins = datastore datapusher stats text_view image_view recline_view recline_map_view resource_proxy geojson_view 
```

### Initialising the DB

```
paster --plugin=ckan db init -c /etc/ckan/default/production.ini 

paster –plugin=ckan sysadmin add <<username>> email=<<an email address>> name=<<username>> -c /etc/ckan/default/<<development.ini or production.ini>>
```

### Re-initialising the DB

```
source ~/ckan/lib/default/bin/activate 

paster --plugin=ckan db clean -c /etc/ckan/default/production.ini 
```

Then initialise and add the sysadmin user back, as shown above.

## <a name="install_django">Installing Django</a>


Move code for django to /usr/share/www or similar, outside user home directory 

### Virtualenv

## <a name="install_nginx">Installing Nginx</a>


### Static files

### Django

### CKAN

*This is only needed if CKAN isn't running as the / root location.*

```
location /ckan { 
    rewrite /ckan/(.+) /$1 break; 
    include uwsgi_params; 
    uwsgi_param SCRIPT_NAME ''; 
    uwsgi_pass 127.0.0.1:5000; 
}
```

### Solr

There shouldn't be a need for this to be public facing. Tunnel over ssh instead.

https://www.revsys.com/writings/quicktips/ssh-tunnel.html 

Once solr is running, tunnel to the server to use the browser to add the core using the GUI.

```
ssh -f user@remote.domain.com -L 2000:remote.domain.com:25 –N
```

Then change the local browsers proxy settings to forward 127.0.0.1 to port 2000, or whatever custom port above. 

## <a name="install_uwsgi">Installing Uwsgi</a>


Also a total pain. Use "sudo journalctl –xe" and the nginx logs to try to get them to play nice.

To run from ckan venv folder (useful for testing if routing is working): 

```
~/ckan/lib/default/bin/uwsgi --socket :5000 --wsgi-file ./ckan.wsgi --virtualenv ~/ckan/lib/default --workers 4 --enable-threads -b 32768 --master --logto ./logs.txt
```

### ckan.wsgi

**ckan.wsgi file explaination**

## <a name="service_setup">Setting up Services</a>

Making /etc/systemd/system/*.service files



**ckan.service file explaination**

## <a name="install_datapusher">Installing Datapusher</a>

 
## <a name="install_https">Lets Encrypt - https</a>


https://certbot.eff.org/#centosrhel7-nginx
https://nixcp.com/install-lets-encrypt-ssl-centos-nginx/

```
sudo yum clean all && sudo yum update nginx
```

```
[username@remote-server ~]$ nginx -v
nginx version: nginx/1.12.2
```


```
$ yum -y install yum-utils
$ yum-config-manager --enable rhui-REGION-rhel-server-extras rhui-REGION-rhel-server-optional
$ sudo yum install certbot-nginx
```

For *nginx.conf*

```
location ^~ /.well-known/acme-challenge {
    alias /usr/share/nginx/html/.well-known/acme-challenge/;
}
```

```
listen 443 ssl http2;

ssl_certificate /etc/letsencrypt/live/domain-name.com/fullchain.pem;

ssl_certificate_key /etc/letsencrypt/live/domain-name.com/privkey.pem;

# SSL Configuration Start

ssl_stapling on;

ssl_stapling_verify on;

resolver 8.8.4.4 8.8.8.8 valid=300s;

resolver_timeout 10s;

ssl_session_cache shared:SSL:10m;

ssl_session_timeout 10m;

ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

ssl_prefer_server_ciphers On;

ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:ECDH+3DES:DH+3DES:RSA+AESGCM:RSA+AES:RSA+3DES:!aNULL:!MD5:!DSS;

# Closing SSL configuration

# Stuff required by certbot

location ~ /.well-known {
    allow all;
}
```


### Running certbot manually

*If auto config above fails*

```
sudo certbot certonly -a webroot --webroot-path=/usr/share/nginx/html/ -d domain.name.com
```

### HTTPS through firewall

Allow https through the firewall:

https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7

```
sudo firewall-cmd --zone=public --permanent --add-service=https
```

## <a name="firewall">Firewall</a>

To see what firewall services you can add, and which are already running

```
sudo firewall-cmd --get-services
sudo firewall-cmd --permanent --list-all

sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```