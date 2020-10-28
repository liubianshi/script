#!/usr/bin/env bash
set -evx

if [ -z $1 ]; then
    ip=$1
else
    ip=$(curl -s -o- cip.cc | awk -F': ' '/^IP/{print $2}')
fi
TASKDDATA="/var/lib/taskd"
taskduser=$(stat -c %U $TASKDDATA)

SOURCEDIR="/usr/share/taskd/pki"
[ -d "$SOURCEDIR" ] || SOURCEDIR="/usr/share/doc/taskd/pki"
sudo cp -r "$SOURCEDIR" "$TASKDDATA/pki"
sudo chown -R $taskduser:$taskduser "$TASKDDATA"

sudo -u "$taskduser" /bin/bash <<INI
export TASKDDATA=$TASKDDATA
[ -f \$TASKDDATA/config ] && rm \$TASKDDATA/config
taskd init
cd \$TASKDDATA/pki
sed -Ei 's/^CN=.*$/CN='$ip'/' vars

./generate > /dev/null
taskd config --force client.cert \$TASKDDATA/pki/client.cert.pem
taskd config --force client.key  \$TASKDDATA/pki/client.key.pem
taskd config --force server.cert \$TASKDDATA/pki/server.cert.pem
taskd config --force server.key  \$TASKDDATA/pki/server.key.pem
taskd config --force server.crl  \$TASKDDATA/pki/server.crl.pem
taskd config --force ca.cert     \$TASKDDATA/pki/ca.cert.pem

taskd config --force log \$TASKDDATA/taskd.log
taskd config --force server '*:53589'
INI

sudo ufw allow 53589
sudo systemctl restart taskd.service
sudo systemctl enable  taskd.service
sudo systemctl status  taskd.service

sudo -u "$taskduser" /bin/bash <<'ADDCLIENTS'
export TASKDDATA="/var/lib/taskd"
mkdir -p "$TASKDDATA/userinfo" && cd $_
[ -f org_user_id ] && mv org_user_id org_user_id_bck

cre_user() {
    tempf=$(mktemp /tmp/taskd.XXXXXX)
    trap 'rm $tempf' 0 1 15

    taskd add org "$1" 2> $tempf
    add_org=$?
    [ $add_org -eq 0 ] || [ $add_org -eq 255 ] || { cat $tempf >&2; return $add_org; }

    taskd add user "$1" "$2" | tee $tempf
    sed -En '/^New/N;s/\n/ /p' $tempf | awk -F': ' '{print $2}' | awk '{printf "%s/%s/%s\n", $7, $4, $1}' >> "$TASKDDATA/userinfo/org_user_id"
    echo "======================================="

    cd "$TASKDDATA/pki"
    name=${2// /_}
    ./generate.client $name > /dev/null
    cp $name.{cert,key}.pem "$TASKDDATA/userinfo"

    return 0
}

cp $TASKDDATA/pki/ca.cert.pem $TASKDDATA/userinfo
cre_user liubianshi legion
cre_user liubianshi notebook
cre_user liubianshi android
ADDCLIENTS

sudo chmod -R +x $TASKDDATA/userinfo
exit 0
