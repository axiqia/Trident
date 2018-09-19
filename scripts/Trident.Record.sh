#!/usr/bin/env bash
#
# saner programming env: these switches turn some bugs into errors
set -o pipefail -o noclobber -o nounset

#
# Trident - Automated Node Performance Metrics Collection Tool
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
# Trident.Record.sh - Main script to record the performance data
#
# Change log:
#
# Stopped recording changelogs as codebase is moved to gitrepo
#
# 18-Apr'18 Trident Beta-v1
# * Moved to git repo
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

#Version
TRIDENT_VER=Beta-v4

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    printf "Trident Error: Unsupported environment, `getopt --test` failed. Please rectify.\n"
    exit 1
fi

OPTIONS=i:d:vh
LONGOPTS=interval:duration:,verbose,help

# -use ! and PIPESTATUS to get exit code with errexit set
# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out ?--options?)
# -pass arguments only via   -- "$@"   to separate them correctly
! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    # e.g. return value is 1
    #  then getopt has complained about wrong arguments to stdout
    Usage
fi
# read getopt?s output this way to handle the quoting right:
eval set -- "$PARSED"

v=n
h=n

# Time interval to record processor data in seconds
#
# Default 1s for ~30MiB of data per day
# Can be adjusted based on the data size that can
# be collected
USER_INTERVAL=1

# Duration the script has to run in seconds
DURATION=30000

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -i|--interval)
            USER_INTERVAL=$2
            shift 2
            ;;
        -d|--duration)
            DURATION=$2
            shift 2
            ;;
				-v|--verbose)
            v=y
            shift
            ;;
        -h|--help)
            h=y
            shift
            ;;
				--)
            shift
            break
            ;;
        *)
            printf "Trident Error: Unknown option <<<$1>>> \n"
            exit 3
            ;;
    esac
done

if [[ $# -gt 0 ]] || [[ $h == 'y' ]] || \
		! [[ $USER_INTERVAL =~ ^[0-9]+\.?[0-9]*$ ]]	|| (( $( echo "scale=2; $USER_INTERVAL < 0.1" | bc -l ) )) ||
		! [[ $DURATION =~ ^[0-9]+$ ]] || (( $( echo "scale=2; $DURATION < 1" | bc -l ) )) || \
		(( $( echo "scale=2; $DURATION < $USER_INTERVAL" | bc -l ) )); then 
	  printf "Usage: $0 [OPTION] \n";
    printf "\nOptions: \n"
		printf "\t-h, --help \t\t Print usage \n";
    printf "\t-i, --interval=VALUE \t Sampling interval in seconds, 60 > VALUE >= 0.1 \n";
    printf "\t-d, --duration=VALUE \t Run interval in seconds, VALUE >= 1 \n";
		printf "\nCtrl+c to exit script and finalize data before end of duration \n";
		printf "\nReport bugs to smuralid@cern.ch.\n"
    exit 4
fi


printf "Trident started with %.2fs interval for %ds duration >>>>\n" $USER_INTERVAL $DURATION

#----------------------EOF User Parameters--------------------------

# Set internal interval variable
# We need ms for perf and sec for IO script
INTERVAL=$( echo "$USER_INTERVAL * 1000" | bc |  awk '{printf "%d", $0}' )

# Find out if NMI is off
NMI_S=$( cat /proc/sys/kernel/nmi_watchdog )

# Find out if kernel paranoid setting is sufficient
PERF_S=$( cat /proc/sys/kernel/perf_event_paranoid )

if (( NMI_S != 0 ));	
then 
		printf "Trident Error: Kindly ensure "
		printf "/proc/sys/kernel/nmi_watchdog is set to 0\n"; 
		exit 1; 
fi

if (( PERF_S != -1 ));	
then 
		printf "Trident Error: Kindly ensure "
		printf "/proc/sys/kernel/perf_event_paranoid is set to -1\n"; 
		exit 1; 
fi

if (( $( echo "$INTERVAL < 100" | bc -l ) || \
		$( echo "$INTERVAL > 60000" | bc -l ) )); 
then 
		printf "Trident Error: Interval resolution affects performance, "
		printf "counter granularity not within spec of 0.1->60s\n"; 
		exit 1; 
fi

if (( $( echo "$DURATION < 0" | bc -l ) || \
		$( echo "$DURATION < $INTERVAL / 1000" | bc -l ) )); 
then 
		printf "Trident Error: Profiling duration "
		printf "is too short for specified intervals\n"; 
		exit 1; 
fi

#---------------EOF User Parameters Sanity Check---------------------

# Autodetect script's home directory
SCRIPT_DIR=`dirname "$(readlink -f "${BASH_SOURCE[0]}")"`
BASE_DIR="$(cd $SCRIPT_DIR/../ && pwd)"

# Binaries used with their path
# Change path to switch between local and system defaults

# Autodetect system defaults
DATE=$(command -v date) || { echo >&2 "Trident Error: 'date' is not installed."; exit 1; }
HOSTNAME=$(command -v hostname) || { echo >&2 "Trident Error: 'hostname' is not installed."; exit 1; }
MKFIFO=$(command -v mkfifo) || { echo >&2 "Trident Error: 'mkfifo' is not installed."; exit 1; }
MKTEMP=$(command -v mktemp) || { echo >&2 "Trident Error: 'mktemp' is not installed."; exit 1; }
CAT=$(command -v cat) || { echo >&2 "Trident Error: 'cat' is not installed."; exit 1; }
ECHO=$(command -v echo ) || { echo >&2 "Trident Error: 'echo' is not installed."; exit 1; }
GREP=$(command -v grep ) || { echo >&2 "Trident Error: 'grep' is not installed."; exit 1; }
SORT=$(command -v sort ) || { echo >&2 "Trident Error: 'sort' is not installed."; exit 1; }
WC=$(command -v wc ) || { echo >&2 "Trident Error: 'wc' is not installed."; exit 1; }
AWK=$(command -v awk ) || { echo >&2 "Trident Error: 'awk' is not installed."; exit 1; }
SED=$(command -v sed ) || { echo >&2 "Trident Error: 'sed' is not installed."; exit 1; }
RM=$(command -v rm ) || { echo >&2 "Trident Error: 'rm' is not installed."; exit 1; }
TS=$(command -v ts ) || { echo >&2 "Trident Error: 'ts' is not installed."; exit 1; }
SLEEP=$(command -v sleep ) || { echo >&2 "Trident Error: 'sleep' is not installed."; exit 1; }
PWD=$(command -v pwd ) || { echo >&2 "Trident Error: 'pwd' is not installed."; exit 1; }
READ=$(command -v read ) || { echo >&2 "Trident Error: 'read' is not installed."; exit 1; }
TR=$(command -v tr ) || { echo >&2 "Trident Error: 'tr' is not installed."; exit 1; }
LSCPU=$(command -v lscpu ) || { echo >&2 "Trident Error: 'lscpu' is not installed."; exit 1; }
TIME=$(command -v /usr/bin/time ) || { echo >&2 "Trident Error: '/usr/bin/time' is not installed."; exit 1; }
PERF=$(command -v $BASE_DIR/bin/perf_static ) || { echo >&2 "Trident Error: '$BASE_DIR/bin/perf_static' not found."; exit 1; }
IO=$(command -v $BASE_DIR/scripts/Trident.Record.IO.pl ) || { echo >&2 "Trident Error: '$BASE_DIR/scripts/Trident.Record.IO.pl' not found."; exit 1; }

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
# RM=/usr/bin/rm
# TS=/usr/bin/ts
# SLEEP=/usr/bin/sleep
# PWD=/usr/bin/pwd
# TIME=/usr/bin/time
# PERF=$BASE_DIR/bin/perf_static
# IO=$BASE_DIR/scripts/Trident.Record.IO.pl

#---------------EOF Program Binaries Sanity Check---------------------

#System parameters
CPU_MODEL=$(lscpu | grep "Model name" | awk -F : '{print $2}' | sed -e 's/^[[:space:]]*//')
NO_CORES=$(lscpu | grep "Core(s) per socket:" | awk -F : '{print $2}' | sed -e 's/^[[:space:]]*//')
NO_HT=$(lscpu | grep "Thread(s) per core:" | awk -F : '{print $2}' | sed -e 's/^[[:space:]]*//')
NO_SOCKETS=$(lscpu | grep "Socket(s):" | awk -F : '{print $2}' | sed -e 's/^[[:space:]]*//')
HSTNAME=$($HOSTNAME -s)

# Local only binaries
TRIDENT_SUPPORT=$BASE_DIR/bin/trident_support

# Event counter metrics directory
EVT_CNT_DIR=$BASE_DIR/EventCounters

ST_TSTMP=`$DATE -u +"%Y-%m-%dT%H:%M:%S.%6NZ"`
ST_UTSTM=$($DATE --date "$ST_TSTMP" +%s)

# Prepend the node name to this string.
OUTFILE="$HSTNAME.Trident.$ST_UTSTM.log"

# Generate a random file in /tmp for pipe
P1="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"
P2="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"
P3="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"
TOUT="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"
T2OUT="$($MKTEMP -u /dev/shm/Trident.XXXXXX)"

# Create the pipe and ensure only I can access it for security reasons
$MKFIFO -m 600 $P1
$MKFIFO -m 600 $P2
$MKFIFO -m 600 $P3

#Supported event list detection
EVNT_LIST=$($TRIDENT_SUPPORT $EVT_CNT_DIR 2>&1 | $GREP "architecture is detected" | $AWK -F '[<>]' '{print $2}')
if [[ ! $EVNT_LIST == *.evts ]]; then
{
	$ECHO "No supported architectures found in the current system!!!"
	exit -1
}
fi
source $EVT_CNT_DIR/$EVNT_LIST

ARCH=$($ECHO $EVNT_LIST | $AWK -F . '{print $1}')

#No of parameters detection to auto format string
NO_PARM=$(( $($ECHO "$CORE_EVTS" | $GREP -o "\-e" | wc -l) + $($ECHO "$UNCORE_EVTS" | $GREP -o "\-e" | $WC -l) ))
SOCKP=4

#Uncomment this to override to single socket mode
NO_SOCKETS=1
PERF_SOCK_CMD=""

if (( $NO_SOCKETS > 1 )); then
{
	PERF_SOCK_CMD="-A --per-socket"
	NO_PARM=$(( $NO_PARM * $NO_SOCKETS ))
	SOCKP=6
}
fi

#File header construction
FILE_HEADER="TIMESTAMP;EPOCH"
IO_HDR=$($IO printheader)

if (( $NO_SOCKETS > 1 )); then
{
	for (( i = 0; i < $NO_SOCKETS; i++ ))
	{
		FILE_HEADER=$FILE_HEADER";S"$i" ""$($ECHO "$UNCORE_EVTS_HEADER" | $SED -e "s/;/;S$i /g")"";S"$i" ""$($ECHO "$CORE_EVTS_HEADER" | $SED -e "s/;/;S$i /g")"
	}
}
else
{
	FILE_HEADER=$FILE_HEADER";"$($ECHO "$UNCORE_EVTS_HEADER")";"$($ECHO "$CORE_EVTS_HEADER")
}
fi

#echo "$FILE_HEADER"

$ECHO "" > $OUTFILE
$ECHO "Trident with specs,st=$ST_TSTMP,ve="$TRIDENT_VER",hn="$HSTNAME",cm="$CPU_MODEL",ar="$ARCH",nc="$NO_CORES",ht="$NO_HT",ns="$NO_SOCKETS",in="$INTERVAL >> $OUTFILE
$ECHO "" >> $OUTFILE

$ECHO $FILE_HEADER";"$IO_HDR";" >> $OUTFILE

#Find process with the name
function p()
{
  ps aux | grep -i $1 | grep -v grep
}

#Kill the process
function ki()
{
  PROCESS="$(ps aux | grep -i $1 | grep -v grep | grep -v perf | tail -1)"
  PROCESS_NAME="$(echo $PROCESS | awk '{printf $11}')"
  PROCESS_PID="$(echo $PROCESS | awk '{print $2}')"

	echo -e "Sending SIGINT to $PROCESS_NAME $PROCESS_PID"
  kill -s $2 $PROCESS_PID
}

function trap_exit()
{
	printf "\nCaught exit request... Flushing fifos...\n"
	while [ -n "$(p "/usr/bin/sleep")" ];
  do
    ki "sleep" SIGINT
  done

	while [ -n "$(p "Trident.Record.IO.pl")" ];
  do
		ki "Trident.Record.IO.pl" SIGINT
  done

	exec 5<>$P1
	cat <&5 >/dev/null & cat_pid=$!
	sleep 0.1
	kill "$cat_pid"

	exec 6<>$P2
  cat <&6 >/dev/null & cat_pid2=$!
  sleep 0.1
  kill "$cat_pid2"

	exec 7<>$P3
  cat <&7 >/dev/null & cat_pid3=$!
  sleep 0.1
  kill "$cat_pid3"

	printf "Terminated gracefully...\n"
}

trap trap_exit SIGTERM SIGINT
trap '' SIGHUP


PERF_CMD="$PERF stat -x \; -o $P1 -c -a $PERF_SOCK_CMD -I $INTERVAL $UNCORE_EVTS $CORE_EVTS $SLEEP $DURATION"

#Perf command collection
$TIME -o $TOUT -f "core and memory [cpu=%P,real=%es,user=%Us,sys=%Ss]" $PERF_CMD &> /dev/null &
#echo "$PERF_CMD"

$TIME -o $T2OUT -f "IO [cpu=%P,real=%es,user=%Us,sys=%Ss]" $IO $( echo "$INTERVAL / 1000" | bc -l | awk '{printf "%.2f", $0}' ) $DURATION >> $P2 &

#String formatting and timestamping
$CAT $P1 | TZ=UTC $TS "%Y-%m-%dT%H:%M:%.SZ;%.s;" | stdbuf -oL $AWK -v AVSOCKP="$SOCKP" -F ";" 'NF>5 { printf $1";"$2";"$AVSOCKP"\n" }' | stdbuf -oL $AWK -vTS_VAL=$(($NO_PARM)) -F ";" '{ if( NR%TS_VAL == 1 ){ printf "%s; %s;",$1,$2 }; printf "%9.3G;",$3; if( NR%TS_VAL == 0 ){ printf "\n" }; }' >> $P3 &

(
exec 30< <( $CAT $P3 )
exec 40< <( $CAT $P2 )

while IFS= $READ -r -u30 LINE1;
do
    IFS= $READ -r -u40 LINE2;
		printf "%s %s;\n" "$LINE1" "$LINE2" >> $OUTFILE
done
exec 30<&- 40<&-
$SED -i '$ d' $OUTFILE
) &

wait

EN_TSTMP=$($DATE -u +"%Y-%m-%dT%H:%M:%S.%6NZ");
ST=$(date --date "$ST_TSTMP" +%s.%N);
EN=$(date --date "$EN_TSTMP" +%s.%N);
DUR=$( echo "$EN - $ST" | bc )

#Cleanup
$RM $P1
$RM $P2

$ECHO "" >> $OUTFILE
$ECHO "Trident profiled for $ST_TSTMP -> $EN_TSTMP , $DUR s" >> $OUTFILE
printf "Trident resource usage by module, %s, %s\n" "$($CAT $TOUT | $TR -d "\n")" "$($CAT $T2OUT | $TR -d "\n")" >> $OUTFILE
printf "<<<< Trident resource usage by module,\n\t%s,\n\t%s\n" "$($CAT $TOUT | $TR -d "\n")" "$($CAT $T2OUT | $TR -d "\n")"

$RM $TOUT $T2OUT

#-------------------------Script Ends-----------------------------

exit 0
#---EOF---
