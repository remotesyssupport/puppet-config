#!/bin/bash

while true
do
    IPTABLES=/sbin/iptables

    $IPTABLES -F
    $IPTABLES -t nat -F
    $IPTABLES -X

    $IPTABLES -t nat -P PREROUTING  ACCEPT
    $IPTABLES -t nat -P POSTROUTING ACCEPT
    $IPTABLES -t nat -P OUTPUT      ACCEPT

    $IPTABLES -P INPUT   ACCEPT
    $IPTABLES -P FORWARD ACCEPT
    $IPTABLES -P OUTPUT  ACCEPT

    sleep 300
done
