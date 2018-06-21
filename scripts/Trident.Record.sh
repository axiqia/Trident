#
# Trident - Automated Node Performance Metrics Collection Tool
#
# trident_support.c - Determines arch of node and evaluates its
# support by the trident metrics collection tool
#
# Copyright (C) 2018, Servesh Muralidharan, IT-DI-WLCG-UP, CERN
# Contact: servesh.muralidharan@cern.ch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# 
# Change log:
# 18-Apr'18 Trident Beta-v1
#   * Moved to git repo
#	* changelog maintained thru commits henceforth
#	* Improved detection and automation
#
# 31-Jan'18 Trident Alpha-v3
#	* Name change to "Trident"
#	* Modified description
#
# 22-Nov'17 Node Memory-Core-Performance-Monitor (MCPM) v2
#	* Added support for port uitlization metrics
#
# 31-Oct'17 Node Memory-Core-Performance-Monitor (MCPM) v1
#	* Memory utilization and top down analysis metrics
#
#
# Description:
#
# This script records data from perf as per spec provided
# onto a text formated file. It consumes minimal resources
# while being executed except for writing data to a file.
#
# Tested on Haswell-E dual socket with quad channel RAM
# 
#
# Commands required: 
# 
# mkfifo, ts, date, awk, perf
#
#
# Setup required:
#
# As root run the following
# 
# Enable MSR registers from core and uncore to be read through perf
# echo -1 > /proc/sys/kernel/perf_event_paranoid
# 
# Disable NMI watchdog. Since perf also uses the same counter.
# sysctl kernel.nmi_watchdog=0
#
# Verify if it is disabled by checking its value is set to '0'
# cat /proc/sys/kernel/nmi_watchdog 
#

#-------------------------Script Begins-----------------------------

#!/bin/bash
TRIDENT_VER=Beta-v3

# Autodetect script's home directory
SCRIPT_DIR=`dirname "$(readlink -f "${BASH_SOURCE[0]}")"`
BASE_DIR="$(cd $SCRIPT_DIR/../ && pwd)"

# Binaries used with their path
# Change path to switch between local and system defaults

# Explicit path
# DATE=/usr/bin/date
# HOSTNAME=/usr/bin/hostname
# MKFIFO=/usr/bin/mkfifo
# MKTEMP=/usr/bin/mktemp
# CAT=/usr/bin/cat
# ECHO=/usr/bin/echo
# GREP=/usr/bin/grep
# SORT=/usr/bin/sort
# WC=/usr/bin/wc
# AWK=/usr/bin/awk
# SED=/usr/bin/sed
PERF=$BASE_DIR/bin/perf_static
# RM=/usr/bin/rm
# TS=/usr/bin/ts
# SLEEP=/usr/bin/sleep
# PWD=/usr/bin/pwd

# Autodetect system defaults
DATE=`which date`
HOSTNAME=`which hostname`
MKFIFO=`which mkfifo`
MKTEMP=`which mktemp`
CAT=`which cat`
ECHO=`which echo`
GREP=`which grep`
SORT=`which sort`
WC=`which wc`
AWK=`which awk`
SED=`which sed`
# PERF=`which perf`
RM=`which rm`
TS=`which ts`
SLEEP=`which sleep`
PWD=`which pwd`
TIME=`which time`


# Local only binaries
TRIDENT_SUPPORT=$BASE_DIR/bin/trident_support

# Event counter metrics directory
EVT_CNT_DIR=$BASE_DIR/EventCounters

# Time interval to record data in milli seconds
#
# Default 10000ms or 10s for ~3MiB of data per day
# Can be adjusted based on the data size that can
# be collected
INTERVAL=${1:-1000}

# Duration the script has to run in seconds
DURATION=${2:-30000}

ST_TSTMP=`$DATE -u +"%Y-%m-%dT%H:%M:%S.%3NZ"`

# Prepend the node name to this string.
OUTFILE="$($HOSTNAME).Trident.$TRIDENT_VER.$ST_TSTMP.log"

# Generate a random file in /tmp for pipe
P1="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"
TOUT="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"

# Create the pipe and ensure only I can access it for security reasons
$MKFIFO -m 600 $P1

#Supported event list detection
EVNT_LIST=$($TRIDENT_SUPPORT $EVT_CNT_DIR 2>&1 | $GREP "architecture is detected" | $AWK -F '[<>]' '{print $2}')
if [[ ! $EVNT_LIST == *.evts ]]; then
{
	$ECHO "No supported architectures found in the current system!!!"
	exit -1
}
fi
source $EVT_CNT_DIR/$EVNT_LIST


#No of parameters detection to auto format string
NO_PARM=$(( $($ECHO "$CORE_EVTS" | $GREP -o "\-e" | wc -l) + $($ECHO "$UNCORE_EVTS" | $GREP -o "\-e" | $WC -l) ))


#Automatically detect no of sockets
NO_SOCKETS=$($CAT /proc/cpuinfo | $GREP "physical id" | $SORT -u | $WC -l)

#Uncomment this to override to single socket mode
#NO_SOCKETS=1

if (( $NO_SOCKETS > 1 )); then
{
	PERF_SOCK_CMD="--per-socket"
	NO_PARM=$(( $NO_PARM * $NO_SOCKETS ))
}
fi


#File header construction
FILE_HEADER="TIMESTAMP"
for (( i=0; i<$NO_SOCKETS; i++ ))
{
	FILE_HEADER=$FILE_HEADER";S"$i" ""$($ECHO "$UNCORE_EVTS_HEADER" | $SED -e "s/;/;S$i /g")"";S"$i" ""$($ECHO "$CORE_EVTS_HEADER" | $SED -e "s/;/;S$i /g")"
}
$ECHO $FILE_HEADER";" > $OUTFILE

#Find process with the name
function p()
{
  ps aux | grep -i $1 | grep -v grep
}

#Kill the process
function ki()
{
  PROCESS="$(ps aux | grep -i $1 | grep -v grep | grep -v perf | head -1)"
  PROCESS_NAME="$(echo $PROCESS | awk '{printf $11}')"
  PROCESS_PID="$(echo $PROCESS | awk '{print $2}')"

	#echo -e "Sending SIGINT to $PROCESS_PID"
  kill -s SIGINT $PROCESS_PID
}

function trap_exit()
{
	printf "\nCaught exit request... Flushing fifos...\n"
	while [ -n "$(p "/usr/bin/sleep")" ];
  do
    ki "sleep"
  done
	exec 5<>$P1
	cat <&5 >/dev/null & cat_pid=$!
	sleep 1
	kill "$cat_pid"
	printf "Terminated gracefully...\n"
}

trap trap_exit SIGTERM SIGINT
trap '' SIGHUP

#Perf command collection
$TIME -o $TOUT -f "Trident resource usage [cpu=%P,real=%es,user=%Us,sys=%Ss]" $PERF stat -x \; -o $P1 -a -A $PERF_SOCK_CMD -I $INTERVAL $UNCORE_EVTS $CORE_EVTS $SLEEP $DURATION &> /dev/null &


#String formatting and timestamping
$CAT $P1 | TZ=UTC $TS "%Y-%m-%dT%H:%M:%.SZ;" | $AWK -F ";" 'NF>12 { printf $1";"$5"\n" }' | $AWK -vTS_VAL=$(($NO_PARM)) -F ";" '{ if( NR%TS_VAL == 1 ){ printf "%s;",$1 }; printf "%9.3G;",$2; if( NR%TS_VAL == 0 ){ printf "\n" }; }' >> $OUTFILE &

wait

#Cleanup
$RM $P1
$ECHO "" >> $OUTFILE
$ECHO "Finished at "`$DATE -u +"%Y-%m-%dT%H:%M:%S.%3NZ"` >> $OUTFILE
$CAT $TOUT >> $OUTFILE
$CAT $TOUT
$RM $TOUT

#-------------------------Script Ends-----------------------------

#---EOF---
