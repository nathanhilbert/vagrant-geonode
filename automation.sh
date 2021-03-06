#! /bin/bash
# This script is designed to install GeoNode with the MapLoom extension that has
# been forked by the Univsity of Alaska Fairbanks group Scenarios Network for 
# Alaska and Arctic Planning (SNAP). By running this script on an Ubuntu 14.04
# system will result in a working GeoNode instance on the localhost port 8000. This
# is useful for development inside of a Vagrant instance that can provision the
# development host using this script. 

# User running this script. Must be a user with sudo to root.
USER=`whoami`

# Where should the source code be installed. Important for development environment as we want to use our
# preferred IDEs to edit code.
INSTALL_DIR='/home/vagrant'

GEONODEURL=$1

# Prevent apt-get steps from displaying interactive prompts
export DEBIAN_FRONTEND=noninteractive


# Delete old INSTALL_DIR if present
# if [ -d $INSTALL_DIR ]; then
#   echo "Removing old geonode installation for fresh provisioning."
#   rm -rf $INSTALL_DIR
# fi

# Node.js setup
sudo sh -c 'curl -sL https://deb.nodesource.com/setup | bash -'

# Make sure apt-get is updated and install all necessary pacakges
sudo apt-get update
sudo apt-get install -y            \
    ant                            \
    apache2                        \
    build-essential                \
    gdal-bin                       \
    gettext                        \
    git                            \
    libapache2-mod-wsgi            \
    libgdal1h                      \
    libgdal-dev                    \
    libgeos-dev                    \
    libjpeg-dev                    \
    libpng-dev                     \
    libpq-dev                      \
    libproj-dev                    \
    libxml2-dev                    \
    libxslt1-dev                   \
    libpq-dev                      \
    maven2                         \
    nodejs                         \
    openjdk-7-jre                  \
    patch                          \
    postgresql                     \
    postgis*                       \
    postgresql-contrib             \
    python                         \
    python-dev                     \
    python-gdal                    \
    python-httplib2                \
    python-imaging                 \
    python-lxml                    \
    python-nose                    \
    python-pastescript             \
    python-pip                     \
    python-psycopg2                \
    python-pyproj                  \
    python-shapely                 \
    python-software-properties     \
    python-support                 \
    python-urlgrabber              \
    python-virtualenv              \
    tomcat7                        \
    unzip                          \
    vim                            \
    zip                            \
    zlib1g-dev                      \
    supervisor 

sudo pip install virtualenvwrapper
sudo npm install -y -g bower
sudo npm install -y -g grunt-cli

# Ensure that the INSTALL_DIR is created and owned by the user running the script
sudo mkdir -p $INSTALL_DIR
sudo chown $USER $INSTALL_DIR

#install geogig and setup
if [ ! -d "/opt/geogig" ]; then
  cd ~
  wget "http://iweb.dl.sourceforge.net/project/geogig/geogig-1.0-beta1/geogig-cli-app-1.0-beta1.zip"
  sudo unzip geogig-cli-app-1.0-beta1.zip -d /opt/geogig
  /opt/geogig/geogig/bin/geogig config --global user.name "vagrant"
  /opt/geogig/geogig/bin/geogig config --global user.email "vagrant@localhost"
fi

cd $INSTALL_DIR

if [ ! -d "geonode" ]; then
  git clone https://github.com/geonode/geonode.git
fi

if [ -d "geonode" ]; then
  cd geonode
  git pull origin master
  cd $INSTALL_DIR
fi


# Create geonode user and databases in PSQL
sudo -u postgres psql -c "CREATE USER geonode WITH PASSWORD 'geonode'"
sudo -u postgres psql -c "CREATE DATABASE geonode"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE geonode to geonode"
sudo -u postgres createdb -O geonode geonode_data
sudo -u postgres psql -d geonode_data -c 'CREATE EXTENSION postgis;'
sudo -u postgres psql -d geonode_data -c 'GRANT ALL ON geometry_columns TO PUBLIC;'
sudo -u postgres psql -d geonode_data -c 'GRANT ALL ON spatial_ref_sys TO PUBLIC;'

# Replace a line in the pg_hba.conf file for Postgres
sudo sh -c "sed -e 's/local   all             all                                     peer/local   all             all                                     md5/' < /etc/postgresql/9.3/main/pg_hba.conf > /etc/postgresql/9.3/main/pg_hba.conf.tmp"
sudo mv /etc/postgresql/9.3/main/pg_hba.conf.tmp /etc/postgresql/9.3/main/pg_hba.conf
sudo service postgresql restart

# Add the modified local_settings.py file in GeoNode
cp $INSTALL_DIR/../local_settings.py $INSTALL_DIR/geonode/geonode/local_settings.py

# Set alias for VI to VIM
echo "alias vi='vim'" >> ~/.bashrc

# Set virtual environment variables in BASHRC for user running this script
echo "export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python" >> ~/.bashrc
echo "export WORKON_HOME=~/.venvs" >> ~/.bashrc
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc
echo "export PIP_DOWNLOAD_CACHE=$HOME/.pip-downloads" >> ~/.bashrc
echo "export INSTALL_DIR=$INSTALL_DIR" >> ~/.bashrc
echo "export INSTALL_DIR=$INSTALL_DIR" >> ~/.bashrc
echo "export PATH=/opt/geogig/geogig/bin:$PATH" >> ~/.bashrc

# Sourcing these from the BASHRC was not working in the script. Explicitly,
# setting these from the BASHRC for immediate usage.
export VIRTUALENVWRAPPER_PYTHON=/usr/bin/python
export WORKON_HOME=$HOME/.venvs
source `which virtualenvwrapper.sh`
export PIP_DOWNLOAD_CACHE=$HOME/.pip-downloads

# Make a virtual environment called geonode and work within the virtual environment
mkvirtualenv geonode
workon geonode

# Install the GeoNode Python package
pip install -e geonode

# Download and untar the GDAL 1.10.0 Python package
pip install --download=. --no-use-wheel GDAL==1.10.0
tar -zxvf GDAL-1.10.0.tar.gz

# Edit the gdal_config variable within the setup.cfg of GDAL to point to the correct
# gdal-config location.
sed -e 's/gdal_config = ..\/..\/apps\/gdal-config/gdal_config = \/usr\/bin\/gdal-config/' < GDAL-1.10.0/setup.cfg > GDAL-1.10.0/setup2.cfg
mv GDAL-1.10.0/setup2.cfg GDAL-1.10.0/setup.cfg

# Export the include directory of GDAL to C and C++ include pathes
export CPLUS_INCLUDE_PATH=/usr/include/gdal
export C_INCLUDE_PATH=/usr/include/gdal

# Build the GDAL extensions 
cd GDAL-1.10.0
python setup.py build_ext --gdal-config=/usr/local/bin/gdal-config
cd ..

# Install GDAL 1.10.0 Python package
pip install -e GDAL-1.10.0
rm GDAL-1.10.0.tar.gz

# Increase JVM heap size for GeoServer when launched with Paver to boost
# GeoServer performance, especially with raster overlays.
sed -e "s/-Xmx512m/-Xmx4096m/" < geonode/pavement.py > geonode/pavement2.py
mv geonode/pavement2.py geonode/pavement.py


# Run paver setup and paver sync to get the paver start / stop commands for the 
# GeoNode and GeoServer tools.
cd geonode

paver setup_geoserver 
paver sync

# Turn of Tomcat since it is unnecessary for running GeoNode / GeoServer
sudo service tomcat7 stop
sudo update-rc.d tomcat7 disable

# Clone and install the django-maploom Python package
cd ..
if [ ! -d "django-maploom" ]; then
  git clone https://github.com/ROGUE-JCTD/django-maploom.git
  pip install -e django-maploom
fi

# Chown the .npm directory to the user currently running this script
sudo chown -R $USER ~/.npm/

# # Clone and make the MapLoom JS file from our local fork of the MapLoom repository
# git clone https://github.com/ua-snap/MapLoom.git
# cd MapLoom
# npm install && bower install && grunt
# cp -f bin/assets/MapLoom-1.2.0.js ../django-maploom/maploom/static/maploom/assets/MapLoom-1.2.js
# cd ..

# # Clone and install the SNAP Arctic Portal Git Repository
# git clone https://github.com/ua-snap/snap-arctic-portal.git
# cd snap-arctic-portal
# git checkout snapmapapp
# cd ..
# pip install -e snap-arctic-portal

# Add maploom and snapmapapp as GeoNode apps to settings.py
sed -e "s/) + GEONODE_APPS/'maploom',\n'geonode.contrib.geogig',\n) + GEONODE_APPS/" < geonode/geonode/settings.py > geonode/geonode/settings2.py
mv geonode/geonode/settings2.py geonode/geonode/settings.py

sed "s/geonode.vag/$GEONODEURL/g" /install/local_settings.py > $INSTALL_DIR/geonode/geonode/local_settings.py



# Add the maploom_urls to the list of urlpatterns in urls.py
# Also, make the snapmapapp_urls first sequentially in the urlpatterns list
echo "from maploom.geonode.urls import urlpatterns as maploom_urls

# After the section where urlpatterns is declared
urlpatterns += maploom_urls" >> geonode/geonode/urls.py

sudo cp /install/hosts /etc/hosts

# Configure PostGIS as the GeoNode backend
cd geonode
pip install psycopg2
python manage.py syncdb --noinput
python manage.py createsuperuser --username=admin --email=ad@m.in --noinput
python manage.py collectstatic --noinput


cp /install/web.xml $INSTALL_DIR/geonode/geoserver/geoserver/WEB-INF/web.xml
#cp /install/geoserver/config.xml /install/portal/geonode/geoserver/data/security/auth/geonodeAuthProvider/config.xml
sed "s/geonode.vag/$GEONODEURL/g" /install/config.xml > $INSTALL_DIR/geonode/geoserver/geoserver/data/security/auth/geonodeAuthProvider/config.xml


sudo cp -R /install/supervisor-app.conf /etc/supervisor/conf.d/supervisor-app.conf
sudo service supervisor start



sudo a2enmod proxy
sudo a2enmod proxy_http
sudo sed "s/geonode.vag/$GEONODEURL/g" /install/geonode.conf > /tmp/geonode.conf
sudo mv /tmp/geonode.conf /etc/apache2/sites-available/geonode.conf 
#sudo cp /install/apache/geonode.conf /etc/apache2/sites-available/geonode.conf
sudo a2ensite geonode
sudo a2dissite 000-default
sudo service apache2 restart


echo
echo "A new admin user account has been created but requires a password to be used on the website."
echo "Please do the following manual steps: "
echo "1. vagrant ssh "
echo "2. workon geonode "
echo "3. cd $INSTALL_DIR/geonode "
echo "4. python manage.py changepassword admin "
echo
echo "Build of GeoNode finished."
