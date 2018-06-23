#!/bin/bash

install_postgres(){

    echo $1
    echo -e "We will install PostgreSQL locally now"
    sudo yum install -y postgresql-server postgresql-devel postgis
#    sudo -u postgres psql -l
    sudo service postgresql initdb
    sudo service postgresql restart

    echo -e "Adding PostgreSQL user"
    sudo -u postgres createuser -S -D -R -P ckan_default
    sudo -u postgres createdb -O ckan_default ckan_default -E utf-8 --template=template0

    if [ $1 ] &&[ $1 == 'exit' ]
    then
        echo -e "Installed PostgreSQL only. Quitting..."
        exit 0
    fi
}


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
#   TODO replace this
   exit 1
fi

echo -e "\nShould we install PostgreSQL locally? Select No if PostgreSQL is already installed, either locally or on a different server."

echo -e "Selecting Only will install PostgreSQL only, and then quit. Use this if you want to run this script on the 'database' server, then run it again on the 'web' server."

select yn in Yes No Only Cancel; do
    case ${yn} in
        Yes )
            install_postgres
            break;;
        No )
            echo -e "\nNot installing PostgreSQL."
            echo -e "We will assume you already have it installed somewhere.\n"
            break;;
        Only )
            install_postgres exit
            exit 0;;
        Cancel )
            exit;;
    esac
done

echo -e "Set development.ini variables now?"

select yn in Yes No Cancel; do
case ${yn} in
        Yes )
            echo -e "Values required for CKAN development.ini file.\n"
            echo -e "Enter postgresql url (called sqlalchemy.url in development.ini)"
            echo -e "Format should be postgresql://ckan_default:PASSWORD@localhost/ckan_default"
            read -p ">>> " sqlalchemy_url

            if [[ -z $sqlalchemy_url ]]
            then
                echo 'No url given, using default'
                sqlalchemy_url='postgresql://ckan_default:___password_here___@localhost/ckan_default'
            fi

            #TODO do not echo passwords !!
            echo -e $sqlalchemy_url '\n'

            #sql_output=`pg_isready $sqlalchemy_url`
            #echo $sql_output
            #psql_code=$?
            #echo -e ${psql_code} "output from pg_isready test\n\n"
            #
            #sql_output=`psql -qtAX $sqlalchemy_url`
            #echo $sql_output
            #psql_code=$?
            #echo -e ${psql_code} "output from psql test\n\n"

            echo -e "Enter ckan.site_id"
            echo -e "Format - some_name_for_the_site"
            read -p ">>> " site_id
            echo -e ${site_id} '\n'

            echo -e "Enter ckan.site_url"
            echo -e "Format - http(s)://HOST_URL/ckan"
            read -p ">>> " site_url
            echo -e $site_url '\n'
            break;;
        No )
            echo -e "Basic install, config files will need to be edited manually\n"
            break;;
        Cancel )
            exit;;
    esac
done

echo -e "Install all required system packages now? We will update packages first."

select yn in Yes No Cancel; do
    case ${yn} in
        Yes )
            echo "Installing all the things for webserver"
            sudo yum --enablerepo=extras install epel-release
            sudo yum update
            sudo yum install nano python-devel postgresql postgresql-libs python-pip python-virtualenv git-core java-1.8.0-openjdk redis python-redis gcc postgresql-devel mlocate gd-devel python34-devel uwsgi pcre pcre-devel lsof nginx

            # Redis will be used later, no harm in starting it now.
            echo "Starting redis"
            sudo service redis restart
            break;;
        No )
            echo -e "Not installing packages."
            break;;
        Cancel )
            exit;;
    esac
done



echo -e "\nStarting Solr install\n"

# Originally attempted with Solr 7.1.0, assuming 7.x.x isn't too different.
# Now at 7.3.0...
# 7.3.1

SOLR_VERSION="7.3.1"
echo "This installer was last tested using Solr version" $SOLR_VERSION

echo "Please check the website http://lucene.apache.org/solr/guide/ to ensure this is still the latest version."
# http://apache.org/dist/lucene/solr/

echo -e "Should we use SOLR version" $SOLR_VERSION "?"
select yn in Yes No ; do
    case ${yn} in
        No )
            echo -e "Please give valid SOLR version to download.\n"
            read -p ">>> " USR_SOLR_VERSION

            if [[ -z $USR_SOLR_VERSION ]]
            then
                echo 'No version given, using default'
            else
                SOLR_VERSION=$USR_SOLR_VERSION
            fi
            break;;
        Yes )
            break;;
    esac
done

echo -e "\nShould we download and install SOLR" $SOLR_VERSION "?"
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
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
            break;;
    esac
done

echo -e "\nShould we try to (re)arrange SOLR config files and directories?"
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
            echo "Creating solr configs directory /var/solr/data/ckan"
            sudo mkdir -p /var/solr/data/ckan

            echo "Copying solr configs to var directory"
            sudo cp -a /opt/solr-$SOLR_VERSION/example/files/conf/. /var/solr/data/ckan/

#            sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/solrconfig.xml /var/solr/data/ckan/
#            sudo cp /opt/solr-$SOLR_VERSION/example/files/conf/managed-schema /var/solr/data/ckan/schema.xml

            sudo cp ./install_files/solrconfig.xml /var/solr/data/ckan/
            sudo cp ./install_files/schema.xml /var/solr/data/ckan/schema.xml

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
            sudo -u solr /opt/solr-$SOLR_VERSION/bin/solr create -c ckan -confdir /var/solr/data/ckan
            break;;
    esac
done


echo -e "\nShould we install CKAN 2.7.2 python virtual environment and packages? "
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
            echo "Beginning CKAN install"
            sudo mkdir -p /usr/lib/ckan/default
            sudo chown `whoami` /usr/lib/ckan/default

            echo "Creating Virtual Environment"
            virtualenv --no-site-packages /usr/lib/ckan/default
            source /usr/lib/ckan/default/bin/activate

            echo "Install tools and CKAN source code into virtualenv"
            pip install -U pip
            pip install setuptools==36.1
            pip install -U uwsgi
            pip install -e 'git+https://github.com/ckan/ckan.git@ckan-2.7.2#egg=ckan'
            pip install -r /usr/lib/ckan/default/src/ckan/requirements.txt
            deactivate
            source /usr/lib/ckan/default/bin/activate

            echo "Create a directory to contain the site’s config files"
            sudo mkdir -p /etc/ckan/default
            sudo chown -R `whoami` /etc/ckan/
            sudo chown -R `whoami` ~/ckan/etc

            paster make-config ckan /etc/ckan/default/development.ini

            sudo cp /etc/ckan/default/development.ini /etc/ckan/default/development.ini.old
            break;;
    esac
done

http://docs.ckan.org/en/latest/maintaining/datastore.html

echo -e "\nShould we install the DataPusher? "
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
            git clone https://github.com/ckan/datapusher

            cd datapusher/
            virtualenv datapusher
            source datapusher/bin/activate

            sudo yum install libxml2 libxml2-devel libxslt-devel openssl-devel

            pip install --update pip
            pip install -U setuptools
            pip install -r requirements.txt
            pip install -e .

            pip uninstall flask
            pip install flask==0.12


            echo -e "\nYou will need to add datapusher to the ckan settings file."
            echo -e "For more info, see http://docs.ckan.org/projects/datapusher/en/latest/development.html"
            echo -e "\nTo test, run:\npython datapusher/main.py deployment/datapusher_settings.py"
            break;;
    esac
done

echo -e "\nShould we add firewall-cmd http and https rules? "
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
            echo "Adding firewall-cmd http and https rules"
            sudo firewall-cmd --permanent --add-service=http
            sudo firewall-cmd --permanent --add-service=http
            sudo firewall-cmd --reload
            break;;
    esac
done

echo -e "\nShould we start nginx? "
select yn in Yes No ; do
    case ${yn} in
        No )
            break;;
        Yes )
            echo "Starting nginx"
            sudo service nginx restart
            break;;
    esac
done

#echo "Making /etc/systemd/system/*.service files"

echo -e "\nAutomated part complete, there's probably more to do though."
echo -e "Exiting...\n\n"
