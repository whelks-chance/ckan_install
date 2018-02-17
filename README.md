# Install guide for CKAN and Django on CentOS7


Most easily, CKAN is installed on Ubuntu 14.04 or 12.04 from the repos, as described [here](http://docs.ckan.org/en/latest/maintaining/installing/install-from-package.html).

Unfortunately this comes with a few issues, such as it being very outdated now, and the packages are very old. Writing this in early 2018, the Ubuntu default process installs Solr v1.0, first released in 2010. This is not ideal.

Further, the Virtual Machines I have been provisioned with were CentOS 7, and so many of the instructions found online were inappropriate. This post is an effort to correct that.

## Setup procedure


[Installing PostgreSQL](#postgresdb)
[Installing required packages](#required_packages)
[Installing Solr v7.1.0](#solr)
[Installing CKAN]()
[Installing Django]()
[Setting up Nginx]()
[Setting up UWSGI]()
[Setting up services]()
[DataPusher]()


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

```
nano /var/lib/pgsql/9.5/data/pg_hba.conf
```

Allow PostgreSQL to listen

```
nano /var/lib/pgsql/9.5/data/postgresql.conf
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


## <a name="solr">Installing Solr</a>


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

## CKAN


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

## Django


Move code for django to /usr/share/www or similar, outside user home directory 

### Virtualenv


## Nginx


### Static files

### Django

### CKAN

### Solr

### Lets Encrypt

## Uwsgi


Also a total pain. Use "sudo journalctl –xe" and the nginx logs to try to get them to play nice.

To run from ckan venv folder (useful for testing if routing is working): 

```
~/ckan/lib/default/bin/uwsgi --socket :5000 --wsgi-file ./ckan.wsgi --virtualenv ~/ckan/lib/default --workers 4 --enable-threads -b 32768 --master --logto ./logs.txt
```

### ckan.wsgi

**ckan.wsgi file explaination**

## Setting up services


**ckan.service file explaination**

## Datapusher

