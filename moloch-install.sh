#!/bin/bash
TDIR=/data/moloch
RUN_AS=moloch
BUILDDIR=~/src

# Increase limits
if [ ! -f /etc/security/limits.d/moloch.conf ]; then
	sudo tee /etc/security/limits.d/moloch.conf > /dev/null <<EOF
* hard nofile 128000
* soft nofile 128000
root hard nofile 128000
root soft nofile 128000
EOF
fi

# check if moloch user exists, if not, create it
id -u $RUN_AS >/dev/null 2>&1 || sudo useradd -r $RUN_AS || exit $?

# Install area
echo "MOLOCH: Creating install area"
for d in logs raw etc bin db
do 
	sudo mkdir -p ${TDIR}/${d} || exit $?
done


./moloch-ubuntu-build.sh $TDIR || exit $?
./elasticsearch-install.sh $TDIR || exit $?

(cd ${BUILDDIR}/moloch; sudo make install)

if [ ! -f "${TDIR}/etc/ipv4-address-space.csv" ]; then
	wget -P /tmp https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.csv && \
	sudo mv /tmp/ipv4-address-space.csv ${TDIR}/etc/ 
fi

for p in ${TDIR}/viewer/public ${TDIR}/raw ${TDIR}/logs
do
	sudo chown ${RUN_AS}:${RUN_AS} $p || exit $?
done

sudo cp upstart/moloch-*.conf /etc/init/
sudo sed -i -e "s,_TDIR_,${TDIR},g" -e "s,_USER_,${RUN_AS},g" /etc/init/moloch-*.conf

./moloch-config.sh $TDIR || exit $?

echo "MOLOCH: Building database"
cd ${TDIR}/db
./db.pl localhost:9200 init || exit $?

# TODO need to start viewer first
echo "MOLOCH: Adding user admin/admin"
cd ${TDIR}/viewer
node addUser.js -c ../etc/config.ini admin "Admin" admin -admin || exit $?

cat << EOF

Moloch installation complete

To start moloch

  sudo service moloch-viewer start
  sudo service moloch-capture start

To start elasticsearch

  sudo service elasticsearch start

EOF
