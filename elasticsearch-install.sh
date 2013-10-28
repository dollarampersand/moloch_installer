#!/bin/bash

VERSION=$(wget -q -O - http://www.elasticsearch.org/download/|sed -n 's/^.*class="version">\([.0-9]*\)<.*$/\1/p')
URL=https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-${VERSION}.deb
DEB=elasticsearch-${VERSION}.deb

TDIR="/data/moloch"
if [ "$#" -gt 0 ]; then
    TDIR="$1"
fi

DATA_PATH=${TDIR}/data

if [ ! -f $DEB ]
then
	wget -O $DEB $URL || exit 1
fi
sudo dpkg -i $DEB

for plugin in mobz/elasticsearch-head lukas-vlcek/bigdesk
do
	sudo /usr/share/elasticsearch/bin/plugin -install $plugin
done

if [ -f templates/elasticsearch.yml.template ] 
then
	if [ ! -f /etc/elasticsearch/elasticsearch.yml.dist ]
	then
		sudo mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.dist
	fi
	sudo cp templates/elasticsearch.yml.template /etc/elasticsearch/elasticsearch.yml
	sudo sed -i "s,_TDIR_,${TDIR},g" /etc/elasticsearch/elasticsearch.yml

else
	echo "Moloch elasticsearch.yml missing, install manually"
fi

sudo tee -a /etc/default/elasticsearch > /dev/null << EOF
ES_HEAP_SIZE=512m
ES_JAVA_OPTS=-XX:+UseCompressedOops
ES_HOSTNAME=$(hostname -s)a
EOF

if [ ! -d $DATA_PATH ]
then
	sudo mkdir -p $DATA_PATH
	sudo chown elasticsearch:elasticsearch $DATA_PATH
fi

echo "Restarting elastic search with new configuration"
sudo service elasticsearch restart
