#!/bin/sh
java -Xmx512m -Djboss-profiler-client.properties=jboss-profiler-client.properties -classpath ../client/jbossall-client.jar:jboss-profiler-client.jar org.jboss.profiler.client.cmd.Client snapshot
