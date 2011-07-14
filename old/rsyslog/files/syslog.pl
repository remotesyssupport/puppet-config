#!/usr/bin/perl

use strict;
use Sys::Syslog qw( :DEFAULT setlogsock );
use IO::Handle;

chdir '/'; # Avoid the possibility of our working directory resulting in
	   # keeping an otherwise unused filesystem in use

# Double-fork to avoid leaving a zombie process behind
exit if (fork());
exit if (fork());
sleep 1 until getppid() == 1;

openlog $ARGV[1], 'cons', 'pid', $ARGV[2];

my $replicate = 0;
if ($ARGV[4] ne "false") {
    open(REPLICATE, ">> $ARGV[4]") || die "Can't write to $ARGV[4]: $!";
    REPLICATE->autoflush(1);
    $replicate = 1;
}

while (1) {
    open(FIFO, "< $ARGV[0]") || die "Can't read from $ARGV[0]: $!";

    my $log;
    while ($log = <FIFO>) {
	my $priority = $ARGV[3];

	if ($log =~ /(err|fatal)/i) {
	    $priority = "error";
	}
	elsif ($log =~ /warning/i) {
	    $priority = "warning";
	}
	syslog $priority, $log;

	if ($replicate) {
	    print REPLICATE $log;
	}
    }
    close FIFO;
}

closelog
