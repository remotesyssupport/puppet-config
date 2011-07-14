#!/bin/sh

set -e

STAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$2/$STAMP"

cd "$2/$STAMP"

db2look -d $1 -e -a -o db2look.ddl > db2dump.log 2>&1
db2move $1 export >> db2dump.log 2>&1

cd ..

7za a ${1}_${STAMP}.7z "$STAMP" > /dev/null 2>&1 && rm -fr "$STAMP"
