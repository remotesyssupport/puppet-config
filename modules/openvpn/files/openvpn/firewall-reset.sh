#!/bin/bash

# A Sample OpenVPN-aware firewall.

# eth0 is connected to a private subnet.
# eth1 is connected to the internet.
LNET=eth0
INET=eth1

# Change this subnet to correspond to your private ethernet subnet.
PRIVATE=10.9.0.0/16

# Loopback address
LOOP=127.0.0.1

# Delete old iptables rules and temporarily block all traffic.
iptables -P OUTPUT ACCEPT
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -F

iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A INPUT -i tap+ -j ACCEPT
iptables -A FORWARD -i tap+ -j ACCEPT
