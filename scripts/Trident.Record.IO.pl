#!/usr/bin/env perl
#===============================================================================
# Trident - Automated Node Performance Metrics Collection Tool
#
# Trident.Record.Blockstats.pl - utility to collect specific information from
# block devices
#
# (C) Copyright 2018 CERN. This software is distributed under the terms of the
# GNU General Public Licence version 3 (GPL Version 3), copied verbatim in the
# file "COPYING". In applying this licence, CERN does not waive the privileges
# and immunities granted to it by virtue of its status as an Intergovernmental
# Organization or submit itself to any jurisdiction.
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#===============================================================================

use warnings;
use strict;
use Fcntl ':mode';
use Time::HiRes qw(clock_gettime CLOCK_MONOTONIC);

sub monotime() {
  return Time::HiRes::clock_gettime(Time::HiRes::CLOCK_MONOTONIC);
}

my $use_error = 0;
if (@ARGV < 1 || @ARGV>2) {
  $use_error = 1;
}
if (@ARGV == 1 && $ARGV[0] cmp "printheader") {
  $use_error = 1;
}

if ($use_error) {
  print STDERR "Usage: $0 <interval> <duration>\n";
  print STDERR "       $0 printheader\n";
  exit 1;
}
my ($INTERVAL,$DURATION,$printheader);
if (@ARGV == 2) {
  ($INTERVAL,$DURATION) = @ARGV;
  $printheader = 0;
} else {
  $printheader = 1;
}
my $SYS_BLOCK="/sys/block";

my %devs;
opendir(DIR, $SYS_BLOCK);
while(readdir(DIR)){
  chomp(my $entry=$_);
  my $mode = (lstat($SYS_BLOCK."/".$entry))[2];
  next unless defined $mode;
  next unless S_ISLNK($mode) == 1;
  my $ltarget = readlink($SYS_BLOCK."/".$entry);
  next if $ltarget =~ /\/virtual\//;
  $devs{$entry} = { };
}
closedir(DIR);

if (scalar(keys %devs)==0) {
  print STDERR "No devices found\n";
  exit 1;
}

if ($printheader) {
  my $didx=0;
  foreach my $dev (keys %devs) {
    print ";" if $didx;
    print "Device ".($didx+1).";Read IOP/s;Read KB/s;Write IOP/s;Write KB/s;%util";
    $didx++;
  }
  print "\n" if $didx;
  exit 0;
}

my %devnext;
my $starttime = time();
my $linere = '\s+(\d+)\s+(\d+)\s+(.+)'.'\s+(\d+)'x11;
while(1) {
  %devnext = ();
  open(SF, "< /proc/diskstats");
  while(<SF>) {
    chomp(my $line=$_);
    if ($line =~ /$linere/) {
      my ($sampletime, $dmaj,$dmin,$dname,$rok,$rmerge,$rsectors,$rtime,
          $wok,$wmerge,$wsectors,$wtime,$ios,$iotime,$iowtime) =
             (monotime(), $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14);
      next unless exists $devs{$dname};
      $devnext{$dname} = { sampletime => $sampletime,
                           dmaj       => $dmaj,
                           dmin       => $dmin,
                           rok        => $rok,
                           rmerge     => $rmerge,
                           rsectors   => $rsectors,
                           rtime      => $rtime,
                           wok        => $wok,
                           wmerge     => $wmerge,
                           wsectors   => $wsectors,
                           wtime      => $wtime,
                           ios        => $ios,
                           iotime     => $iotime,
                           iowtime    => $iowtime };
    }
  }
  close(SF);
  my $didx=0;
  foreach my $dname (keys %devs) {
    next unless exists $devnext{$dname};
    next unless defined $devs{$dname}{sampletime};

    my ($d1,$d2)=($devs{$dname},$devnext{$dname});
    my ($elapsed,$rsectors,$rok,$wsectors,$wok,$deltioms) = (
                                                   $$d2{sampletime} - $$d1{sampletime},
                                                   $$d2{rsectors}   - $$d1{rsectors},
                                                   $$d2{rok}        - $$d1{rok},
                                                   $$d2{wsectors}   - $$d1{wsectors},
                                                   $$d2{wok}        - $$d1{wok},
                                                   $$d2{iotime}     - $$d1{iotime}
                                                  );
    my $rrate = $rsectors*512/1000 / $elapsed;
    my $wrate = $wsectors*512/1000 / $elapsed;
    my $rioprate = $rok / $elapsed;
    my $wioprate = $wok / $elapsed;
    my $pcutil = $deltioms / $elapsed / 10.0;
    print ";" if $didx;
    printf "%s;%.2f;%.2f;%.2f;%.2f;%.2f", $dname,$rioprate,$rrate,$wioprate,$wrate,$pcutil;
    $didx++;
  }
  print "\n" if $didx;
  %devs = %devnext;
  last if (time() - $starttime + $INTERVAL > $DURATION);
  sleep($INTERVAL);
}

exit 0;
