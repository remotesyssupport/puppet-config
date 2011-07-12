#!/bin/sh

checkmodule -M -m -o $1.mod $1.te || exit 1
if [ -f $1.fc ]; then
    semodule_package -o $1.pp -m $1.mod -f $1.fc || exit 1
else
    semodule_package -o $1.pp -m $1.mod || exit 1
fi
semodule -i $1.pp || exit 1
rm -f $1.mod $1.pp

cat < /dev/null > /var/log/audit/audit.log 
