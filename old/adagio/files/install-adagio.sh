#!/bin/sh

ADAGIO=/usr/adagio
JBOSS=/usr/jboss/server/default

for jarfile in $ADAGIO/*.jar; do
    if echo $jarfile | grep -q Adagio_Lib; then
	if [ $jarfile -nt $JBOSS/deploy/Adagio_Lib.jar ]; then
	    ctl stop jboss
	    sleep 300
	    rm -fr $JBOSS/deploy/Adagio_Lib.jar
	    unzip $jarfile -d $JBOSS/deploy/Adagio_Lib.jar
	    ctl start jboss
	fi

    elif echo $jarfile | egrep -q '(log4j|j2ee)'; then
	echo skipping $jarfile

    elif [ ! -f $JBOSS/lib/`basename $jarfile` ]; then
	cp -p $jarfile $JBOSS/lib
    fi
done

