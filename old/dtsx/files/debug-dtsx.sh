#!/bin/bash

echo "Make sure you have X11 running and open on your system."
echo
echo "For example, here's how one might access DTSX from another UNIX host:"
echo
echo "me$ startx"
echo "me$ xhost +               # Allow any client to connect"
echo "me$ ssh -Y abc-p1-dtsx-1  # Pass authorization and forward X11 via SSH"
echo "dtsx$ ./debug-dtsx.sh 1   # Start the DTSX1 server and display on local X11"

WINEPREFIX=/usr/indesign/dtsx$1 WINEDEBUG=err-ole                      \
    /usr/bin/wine 'c:\servers\jdk1.6\bin\java.exe'                     \
        -cp 'z:\usr\adagio\Adagio_Lib-2.9.1-client-full.jar'           \
        -DJINTEGRA_NATIVE_MODE                                         \
        '-Ddtsx.server.configfile=c:\servers\DTSX\dtsx-server.config'  \
        adk.dts.server.DTSXAdminServer
