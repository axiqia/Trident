#!/bin/bash

BENCHMARK=$1
[ -z "$BENCHMARK" ] && echo -e "Error: No benchmark specified" && \
	echo -e "Usage: Trident.Profile.sh <BENCHMARK> <NO_REPEAT>" && exit 1

CURR_DIR=$(pwd)
TRIDENT_BIN=Trident.Record.sh
TRIDENT_ARGS="-i 0.1"
REPEAT=${2:-1}
WAIT_DUR=30

set -o pipefail -o noclobber -o nounset
BASH_ISHELL_PID=""

trap_exit() 
{
	if [[ ! -z "$BASH_ISHELL_PID" ]]; then
		echo
		echo "Premature exit...Cleaning up and Killing job $BASH_ISHELL_PID..."
		kill -TERM -$BASH_ISHELL_PID 2>/dev/null
		wait $JOB_PIDS
	fi

	kill -TERM $TRIDENT_PID 2>/dev/null
  wait $TRIDENT_PID

	rm -f /dev/shm/BThTimes.* &> /dev/null;
	rm -f /dev/shm/Trident.* &> /dev/null;
	exit
}

trap trap_exit SIGTERM SIGINT
trap '' SIGHUP

PTIME=$(mktemp -u /dev/shm/BThTimes.XXXXXX)

# Now we're ready to go. 
$TRIDENT_BIN $TRIDENT_ARGS & TRIDENT_PID=$!

BENCHMARK_LOG=$CURR_DIR/$BENCHMARK.log	
BENCHMARK_OUT=$CURR_DIR/$BENCHMARK.out
rm $BENCHMARK_LOG $BENCHMARK_OUT.RPT* &> /dev/null

OSTART=`date -u +"%Y-%m-%dT%H:%M:%S.%6NZ"`
echo -e "Benchmark $BENCHMARK:" > $BENCHMARK_LOG

for rpt in `seq $REPEAT`;
do
		sleep $WAIT_DUR 

		START=`date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"`
		printf "Benchmark $BENCHMARK iteration $rpt started at $START...\n"
	
		/usr/bin/time -o $PTIME -f "$BENCHMARK IT $rpt resource usage [cpu=%P,real=%es,user=%Us,sys=%Ss]" /usr/bin/setsid /usr/bin/bash -ci "source $CURR_DIR/$BENCHMARK" &> $BENCHMARK_OUT.RPT$rpt &

		JOB_PIDS=$!
		BASH_ISHELL_PID=$(ps h --ppid $JOB_PIDS -o pgid)

		echo -e "\e[1m\e[41m\e[39m To stop the benchmark job:\e[0m\e[40m\e[93m kill -TERM -$BASH_ISHELL_PID \e[0m"
		
		wait $JOB_PIDS

		END=`date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"`
		printf "...finished at $END\n"

		ST=$(date --date "$START" +%s.%N);
		EN=$(date --date "$END" +%s.%N);
		DUR=$( echo "$EN - $ST" | bc )
	
		echo -e "Iteration $rpt : $START -> $END, $DUR s" >> $BENCHMARK_LOG
		cat $PTIME >> $BENCHMARK_LOG
		echo -e "[MKR];$START;$BENCHMARK IT $rpt Start;" >> $BENCHMARK_LOG
		echo -e "[MKR];$END;$BENCHMARK IT $rpt End;" >> $BENCHMARK_LOG

		sleep $WAIT_DUR
done

OEND=`date -u +"%Y-%m-%dT%H:%M:%S.%6NZ"`

echo -e "[MKR];$OSTART;$BENCHMARK CO Start;" >> $BENCHMARK_LOG
echo -e "[MKR];$OEND;$BENCHMARK CO End;" >> $BENCHMARK_LOG

kill -TERM $TRIDENT_PID 2>/dev/null
wait "$TRIDENT_PID"
TRIDENT_LOG=$(ls -Art | grep Trident.*.log | tail -n 1)

cat $BENCHMARK_LOG >> $TRIDENT_LOG
mv $TRIDENT_LOG $BENCHMARK.$TRIDENT_LOG

rm -f $PTIME;
