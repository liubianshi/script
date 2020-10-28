# 配置 taskwarrior service

## Server 端配置

```sh
apt upgrade
apt install sshd

grep -E 'export TASKDDATA' ~/.profile || {
    echo "export TASKDDATA=/var/lib/taskd" >> ~/.profile
}
source $HOME/.profile
[ -d /var/lib/taskd ] || sudo mkdir /var/lib/taskd

taskd init

sourcedir="/usr/share/taskd/pki"
ip=$(curl -s -o- cip.cc | awk -F': ' '/^IP/{print $2}')
cd "$sourcedir"
sed -Ei 's/^CN=.*$/CN='$ip'/' vars
./generate
sudo cp client.cert.pem $TASKDDATA
sudo cp client.key.pem  $TASKDDATA
sudo cp server.cert.pem $TASKDDATA
sudo cp server.key.pem  $TASKDDATA
sudo cp server.crl.pem  $TASKDDATA
sudo cp ca.cert.pem     $TASKDDATA

taskd config --force client.cert $TASKDDATA/client.cert.pem
taskd config --force client.key  $TASKDDATA/client.key.pem
taskd config --force server.cert $TASKDDATA/server.cert.pem
taskd config --force server.key  $TASKDDATA/server.key.pem
taskd config --force server.crl  $TASKDDATA/server.crl.pem
taskd config --force ca.cert     $TASKDDATA/ca.cert.pem

taskd config --force log /var/log/taskd.log
taskd config --force pid.file /var/lib/taskd.pid
taskd config --force server localhost:53589

touch /var/log/taskd.log
touch /var/lib/taskd.pid
[ -d "$TASKDDATA/orgs" ] || mkdir "$TASKDDATA/orgs"
sudo chown -R $(whoami):$(whoami) "$TASKDDATA" "/var/log/taskd.log" "/var/lib/taskd.pid"
sudo chown $(whoami):$(whoami) /etc/taskd/config

sudo sed -Ei 's/^User=.*$/User='$(whoami)'/'   /lib/systemd/system/taskd.service
sudo sed -Ei 's/^Group=.*$/Group='$(whoami)'/' /lib/systemd/system/taskd.service
sudo systemctl daemon-reload
sudo systemctl start  taskd.service
sudo systemctl enable taskd.service
sudo systemctl status taskd.service

mkdir -p "$TASKDDATA/userinfo"
cp "$sourcedir/ca.cert.pem" "$TASKDDATA/userinfo"
cre_user() {
    tempf=$(mktemp /tmp/taskd.XXXXXX)
    trap 'rm $tempf' 0 1 15

    taskd add org "$1" 2> $tempf
    add_org=$?
    [ $add_org -eq 0 ] || [ $add_org -eq 255 ] || {
        cat $tempf >&2
        return $add_org
    }

    taskd add user "$1" "$2" | tee $tempf
    sed -En '/^New/N;s/\n/ /p' $tempf | awk -F': ' '{print $2}' | awk '{printf "%s/%s/%s\n", $7, $4, $1}' >> "$TASKDDATA/userinfo/org_user_id"
    echo "======================================="

    cd $sourcedir
    name=${2// /_}
    ./generate.client $name
    cp $name.{cert,key}.pem "$TASKDDATA/userinfo"

    return 0
}

sourcedir=$sourcedir cre_user liubianshi legion
sourcedir=$sourcedir cre_user liubianshi notebook
sourcedir=$sourcedir cre_user liubianshi android
```

## Client

```sh
scp -r liubianshi_ali@118.190.162.170:/var/lib/taskd/userinfo ~/.task
client_conf() {
    name=$1
    task config taskd.certificate -- ~/.task/userinfo/$name.cert.pem
    task config taskd.key         -- ~/.task/userinfo/$name.key.pem
    task config taskd.ca          -- ~/.task/userinfo/ca.cert.pem
    task config taskd.server      -- 118.190.162.170:53589
    task config taskd.credentials -- $(grep "$name" org_user_id | tr -d "\n")
}
```

