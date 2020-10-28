#!/usr/bin/env bash
set -evx

which task &>/dev/null || { echo "command task is not found" >&2; exit 254; }

[ $# -ne 2 ] && { echo "$0 <user>@<ip> <name>" >&2; exit 255; }

ip=${1#*@}
user=${1%@*}
name=$2

scp -r $user@$ip:/var/lib/taskd/userinfo ~/.task

cp ~/.task/userinfo/ca.cert.pem ~/.task
task config taskd.ca          -- ~/.task/ca.cert.pem

cp ~/.task/userinfo/$name.{key,cert}.pem ~/.task
task config taskd.certificate -- ~/.task/$name.cert.pem
task config taskd.key         -- ~/.task/$name.key.pem

task config taskd.server      -- $ip:53589
task config taskd.credentials -- $(grep "$name" ~/.task/userinfo/org_user_id | tr -d "\n")

exit 0
