#!/bin/bash

# Usage: deploy.sh <host> <ostype> [puppet host/IP]

host=$1
ostype=$2
puppet=$3

rsync -av --exclude='/*/' --include=/$ostype/ ./ $host:/tmp/puppet/

exec ssh $host python /tmp/puppet/bootstrap.py $puppet

### deploy.sh ends here
