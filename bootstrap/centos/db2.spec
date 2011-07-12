Summary: IBM DB2 V9.52
Name: db2
Version: 9.52
Release: 1
License: Commercial
Group: Databases/DB2
Source: ftp://puppet/tar/db2exc_952_LNX_x86.tar.7z
URL: http://www-01.ibm.com/software/data/db2/express/
Distribution: Linux
Vendor: IBM
Packager: John Wiegley <johnw@3dex.com>
BuildRoot: %{_tmppath}/db2-9.52
Requires: compat-libstdc++-33 libaio
BuildRequires: compat-libstdc++-33 libaio p7zip
Prereq: /usr/bin/7za
AutoReqProv: no

# This definition stops the binaries from being "stripped"
%define __os_install_post %{nil}

%description
DB2

%prep
mkdir -p %{buildroot}/var/lib/artifacts

%build
cp %{_sourcedir}/db2exc_952_LNX_x86.tar.7z %{buildroot}/var/lib/artifacts

%install

%clean
%{__rm} -fr %{buildroot}

%post
(cd /tmp; 7za x /var/lib/artifacts/db2exc_952_LNX_x86.tar.7z -so | tar xf -)

#%{__rm} -fr /tmp/expc/samples/repl/xmlpubtk

/tmp/expc/db2_install -n -p EXP -b /usr/db2

groupadd -f db2grp1
groupadd -f db2fgrp1
groupadd -f dasadm1

useradd -g db2grp1  -m -d /usr/db2/db2inst1 db2inst1 
useradd -g db2fgrp1 -m -d /usr/db2/db2fenc1 db2fenc1 
useradd -g dasadm1  -m -d /usr/db2/dasusr1 dasusr1

cd /usr/db2/instance 
./db2icrt -p 50000 -u db2fenc1 db2inst1
sleep 10
./dascrt -u dasusr1
sleep 5

if ! grep -q DB2_TMINST /etc/services; then
    echo "DB2_TMINST      50000/tcp                       # DB2 Database" \
	>> /etc/services
fi

su - db2inst1 -c "db2 update dbm cfg using svcename 50000"
su - db2inst1 -c "db2set DB2COMM=tcpip"

cat <<'EOF' > /etc/init.d/db2
#!/bin/bash
# db2    	This shell script enables the db2 database server.
#
# Author:       Duane Griffin <d.griffin@psenterprise.com>
#
# chkconfig: - 95 05
#
# description: Server for the db2 process management tool.
# processname: db2

PATH=/usr/bin:/sbin:/bin:/usr/sbin
export PATH

lockfile=/var/lock/subsys/db2

# Source function library.
. /etc/rc.d/init.d/functions

if [ -f /etc/sysconfig/db2 ]; then
	. /etc/sysconfig/db2
fi

DB2_OPTS="${EXTRA_DB2_OPTS}"

RETVAL=0

start() {
	echo -n $"Starting DB2: "

	# Confirm the manifest exists
	daemon --user db2inst1 db2start
	RETVAL=$?
	if [ $RETVAL -eq 0 ]; then
	    touch "$lockfile"
	    ps ax | grep 'db2sysc *$' | awk '{print $1}' > /var/run/db2.pid
	fi
	echo
	return $RETVAL
}

stop() {
	echo -n  $"Stopping DB2: "
	runuser -s /bin/bash - db2inst1 -c db2stop > /dev/null 2>&1
	RETVAL=$?
	if [ $RETVAL -eq 0 ]; then
	    success $"db2 shutdown"
	    rm -f "$lockfile" /var/run/db2.pid
	else
	    failure $"db2 shutdown"
	fi
	echo
	return $RETVAL
}

restart() {
  stop
  start
}

case "$1" in
  start)
	start
	;;
  stop) 
	stop
	;;
  restart|reload|force-reload)
        restart
	;;
  condrestart)
	[ -f "$lockfile" ] && restart
	;;
  status)
	status db2
        RETVAL=$?
	;;
  *)
	echo $"Usage: $0 {start|stop|status|restart|reload|force-reload|condrestart}"
	exit 1
esac

exit $RETVAL
EOF

chmod +x /etc/init.d/db2

%preun
userdel -fr db2inst1 
userdel -fr db2fenc1 
userdel -fr dasusr1

groupdel db2grp1
groupdel db2fgrp1
groupdel dasadm1

%files
%defattr(-,root,root)
%dir /var/lib/artifacts
/var/lib/artifacts/db2exc_952_LNX_x86.tar.7z
