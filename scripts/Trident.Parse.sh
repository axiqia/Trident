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
# Trident.Parse.sh - Trident Parser
#
# Needs Bash >= 4.4
# Needs Gnuplot >= 5.2
#
# 

#-------------------------Script Begins-----------------------------

# ParseHeader
#
# Parses the header from the trident metric file
# and sets up different information regarding it
# after performing some sanity checks
#
# VE - Trident Version
# HN - Hostname
# HT - No of HW threads
# NC - No of cores
# NS - No of sockets
# CM - Processor model
# ST - Start timestamp
# AR - Architecture profiled on
# IN - Interval of samples in ms
#
ParseHeader()
{
	if [ -z "$1" ]; then
  {
    printf "Trident Parser Err: No file provided\n"
    exit 1
  }
  fi

	BASHV=$(bash -c 'echo $BASH_VERSION' | awk -F . '{print $1"."$2}')

	if (( $( echo "scale=2; $BASHV < 4.4" | bc -l ) )); then
	{
    printf "Trident Parser Err: Need Bash >= v4.4 \n"
    exit 1
  }
  fi

	printf "Trident Parser Inf: Working on %s\n" "$1"
	ParseStr=$(head -n2 $1 | grep "with specs")
	if [ -z "$ParseStr" ]; then
	{	
		printf "Trident Parser Err: Invalid file\n"
		exit 1
	}
	fi

	IFS=',' read -r -a Tokens <<< "$ParseStr"
	for (( i = 0; i < ${#Tokens[@]}; i++ ));
	do
		IFS='=' read -r -a Tokens2 <<< "${Tokens[i]}"
		case ${Tokens2[0]} in
			ve)		VE=${Tokens2[1]};;
			hn)		HN=${Tokens2[1]};;
			ht)		HT=${Tokens2[1]};;
			nc)		NC=${Tokens2[1]};;
			ns)		NS=${Tokens2[1]};;
			cm)		CM=${Tokens2[1]};;
			st)		ST=${Tokens2[1]};;
			in)		IN=${Tokens2[1]};;
		esac
	done

	if (( $( echo "$SCALE < 1" | bc -l ) )); then
	{
    printf "Trident Parser Err: Incorrect scaling, scale >= 1\n"
    exit 1
  }
  fi

	BIN=$( echo "scale=2; $SCALE * ( $IN / 1000 )" | bc -l)
}

# Reads and parses the collected trident metrics
#
# CO_INST - on instructions retired
# CO_CYCL - unhalted clock cycles.thread any
# CO_IDNC - idq.uops.not delivered to core
# CO_UISD - uops_issued.any
# CO_URTD - uops_retired.retire_slots
# CO_IMRC - int_misc.recovery_cycles_any
# CO_UEP# - uops_executed_port_#.cycles
#
# Memory
# ME_CSR# - # channel_cas_count_read ( skt, channel )
# ME_CSW# - # channel_cas_count_write ( skt, channel )
# ME_PAT# - # channel_page_activation_count ( skt, channel )
# ME_PCM# - # channel_precount_page_miss ( skt, channel )
#
# I/O
# IO_DEVN - Device_name
# IO_RIOP - Read_IO_operations
# IO_WIOP - Write_IO_operations
# IO_RKBS - Read_data_rate
# IO_WKBS - Write_data_rate
# IO_UTIL - Utilization_percentage
#
ReadPrimaryMetric()
{
	PrimaryMetric=$(head -n4 $1 | grep "TIMESTAMP")
	IFS=';' read -r -a Tokens <<< "$PrimaryMetric"
	for (( i = 0; i < ${#Tokens[@]}; i++ ));
  do
    case ${Tokens[i]} in
			TIMESTAMP)									TSTP=($((i+1)));;
			EPOCH)											EPCH=($((i+1)));;
			*INST)											AddPrimaryMetric "CO_INST" "$((i+1))";;
			*CYC)												AddPrimaryMetric "CO_CYCL" "$((i+1))";;
			*IDQ_UOPS_NOT_DELV_CORE)		AddPrimaryMetric "CO_IDNC" "$((i+1))";;
			*UOPS_ISSUED)								AddPrimaryMetric "CO_UISD" "$((i+1))";;
			*UOPS_RETIRED)							AddPrimaryMetric "CO_URTD" "$((i+1))";;
			*INT_MISC_RECOVERY_CYCLES)	AddPrimaryMetric "CO_IMRC" "$((i+1))";;
			*UOPS_EXEC_P0)							AddPrimaryMetric "CO_UEP0" "$((i+1))";;
			*UOPS_EXEC_P1)							AddPrimaryMetric "CO_UEP1" "$((i+1))";;
			*UOPS_EXEC_P2)							AddPrimaryMetric "CO_UEP2" "$((i+1))";;
			*UOPS_EXEC_P3)							AddPrimaryMetric "CO_UEP3" "$((i+1))";;
			*UOPS_EXEC_P4)							AddPrimaryMetric "CO_UEP4" "$((i+1))";;
			*UOPS_EXEC_P5)							AddPrimaryMetric "CO_UEP5" "$((i+1))";;
			*UOPS_EXEC_P6)							AddPrimaryMetric "CO_UEP6" "$((i+1))";;
			*UOPS_EXEC_P7)							AddPrimaryMetric "CO_UEP7" "$((i+1))";;

			*C0_READ_CNT)								AddPrimaryMetric "ME_CSR0" "$((i+1))";;
			*C1_READ_CNT)								AddPrimaryMetric "ME_CSR1" "$((i+1))";;
			*C2_READ_CNT)								AddPrimaryMetric "ME_CSR2" "$((i+1))";;
			*C3_READ_CNT)								AddPrimaryMetric "ME_CSR3" "$((i+1))";;
			*C0_WRITE_CNT)							AddPrimaryMetric "ME_CSW0" "$((i+1))";;
			*C1_WRITE_CNT)							AddPrimaryMetric "ME_CSW1" "$((i+1))";;
			*C2_WRITE_CNT)							AddPrimaryMetric "ME_CSW2" "$((i+1))";;
			*C3_WRITE_CNT)							AddPrimaryMetric "ME_CSW3" "$((i+1))";;
			*C0_PAGE_ACT_CNT)						AddPrimaryMetric "ME_PAT0" "$((i+1))";;										
			*C1_PAGE_ACT_CNT)						AddPrimaryMetric "ME_PAT1" "$((i+1))";;										
			*C2_PAGE_ACT_CNT)						AddPrimaryMetric "ME_PAT2" "$((i+1))";;										
			*C3_PAGE_ACT_CNT)						AddPrimaryMetric "ME_PAT3" "$((i+1))";;										
			*C0_PRE_CNT.PAGE_MISS)			AddPrimaryMetric "ME_PCM0" "$((i+1))";;
			*C1_PRE_CNT.PAGE_MISS)			AddPrimaryMetric "ME_PCM1" "$((i+1))";;
			*C2_PRE_CNT.PAGE_MISS)			AddPrimaryMetric "ME_PCM2" "$((i+1))";;
			*C3_PRE_CNT.PAGE_MISS)			AddPrimaryMetric "ME_PCM3" "$((i+1))";;

			Device*)										AddPrimaryMetric "IO_DEVN" "$((i+1))";;
			Read\ IOP*)									AddPrimaryMetric "IO_RIOP" "$((i+1))";;
			Read\ KB*)									AddPrimaryMetric "IO_REBW" "$((i+1))";;
			Write\ IOP*)								AddPrimaryMetric "IO_WIOP" "$((i+1))";;
			Write\ KB*)									AddPrimaryMetric "IO_WRBW" "$((i+1))";;
			*util*)											AddPrimaryMetric "IO_TIME" "$((i+1))";;
			*)	
				printf "Trident Parser Err: Record struct missing at col %d\n" $i; 
				exit 1;;
		esac
	done

	NI=${#IO_DEVN[@]}
}

AddPrimaryMetric()
{
	eval "$1+=($2)"
	for apm in ${PrimaryMetricName[@]}; 
	do
		if [ $apm == $1 ]; then
			return
		fi
	done
	PrimaryMetricName+=($1)
}

# Constructs the various formuals,
# and the output file based on it.
#
# Core 
#
# Instruction Execution Efficiency Analysis
# 
# CO_INPC - Instructions per cycle
# CO_INPC = inst_retired.any / cpu_clk_unhalted.thread_any
#
# Top-Down uArch Analysis
#
# CO_FACT - Factor - HT which affects the no of exec slots per thread
# CO_SLOT - Slots - No of execution slots per thread
# CO_FBND - Front-End bound - stress on inst issue
# CO_BBND - Back-End bound - stress on memory/execution unit
# CO_BSPC - Bad speculation - ratio of speculative executions
# CO_RTIR - Retiring - ratio of completed instructions
# 
# CO_FACT = ( HT == 2 ) ? 2 : 4
# CO_SLOT = CO_FACT * cpu_clk_unhalted.thread_any
# CO_FBND = idq_uops_not_delivered / CO_SLOT;
# CO_BSPC = ( uops_issued - uops_retired + CO_FACT * recovery_cycles ) / CO_SLOT;
# CO_RTIR = uops_retired / slots;
# CO_BBND = 1 - CO_FBND - CO_BSPC - CO_RTIR
#
# Execution Port's Utilization Analysis
# 
# CO_PUT# - # Port Utilization Ratio
#
# CO_PUT# - uops_executed_port_#.cycles / cpu_clk_unhalted.thread_any
#
#
# Memory
#
# Memory Bandwidth Analysis
#
# ME_REBW - Memory read bandwidth
# ME_WRBW - Memory write bandwidth
#
# ME_REBW = cas_count_read * 64
# ME_WRBW = cas_count_write * 64
#
# Memory Transaction Analysis
#
# ME_PHIT - Memory transaction resulting in page hit
# ME_PEMP - Memory transaction resulting in page empty
# ME_PMSS - Memory transaction resulting in page miss
#
# ME_PEMP = ( page_activation_count - precount_page_miss ) 
#							/ ( cas_count_read + cas_count_write )
# ME_PMSS = precount_page_miss / ( cas_count_read + cas_count_write )
# ME_PHIT = 1 - ME_PEMP - ME_PMSS
#
#
# IO
#
# Device IO Bandwidth Analysis
#
# IO_REBW - Read Bandwidth
# IO_WRBW - Write Bandwidth
# IO_UTIL - Ratio of outstanding IO requests
#
# Device IO Operations Analysis
#
# IO_RIOP - Read IO operation count 
# IO_WIOP - Write IO operation count
# IO_UTIL - Ratio of outstanding IO requests
#
#
DeriveSecondaryMetric()
{
	AddSecondaryMetric "CO_INPC" "CO_INST / CO_CYCL;"

	AddSecondaryMetric "CO_FACT" "( HT == 2 ) ? 2 : 4;";
	AddSecondaryMetric "CO_SLOT" "CO_FACT * CO_CYCL;"
	AddSecondaryMetric "CO_FBND" "CO_IDNC / CO_SLOT;"
	AddSecondaryMetric "CO_BSPC" "( CO_UISD - CO_URTD + ( CO_FACT * CO_IMRC ) ) / CO_SLOT;"
	AddSecondaryMetric "CO_RTIR" "CO_URTD / CO_SLOT;"
	AddSecondaryMetric "CO_BBND" "1 - CO_FBND - CO_BSPC - CO_RTIR;"

	for (( ip = 0; ip < 8; ip++ ));
  do
		P1="CO_PUT"$ip
		P2="CO_UEP"$ip
		AddSecondaryMetric "$P1" "$P2 / CO_CYCL;"
	done


	AGG_ME_CSR="ME_CSR0"
	AGG_ME_CSW="ME_CSW0"
	AGG_ME_PAT="ME_PAT0"
	AGG_ME_PCM="ME_PCM0"
	for (( im = 1; im < 4; im++ )); 
	do
		AGG_ME_CSR+=" + ME_CSR"$im
		AGG_ME_CSW+=" + ME_CSW"$im
		AGG_ME_PAT+=" + ME_PAT"$im
		AGG_ME_PCM+=" + ME_PCM"$im
	done

	AddSecondaryMetric "ME_REBW" "( $AGG_ME_CSR ) * 64;"
	AddSecondaryMetric "ME_WRBW" "( $AGG_ME_CSW ) * 64;"

	AddSecondaryMetric "ME_PEMP" "( ( $AGG_ME_PAT ) - ( $AGG_ME_PCM ) ) / ( ( $AGG_ME_CSR ) + ( $AGG_ME_CSW ) );"
	AddSecondaryMetric "ME_PMSS" "( $AGG_ME_PCM ) / ( ( $AGG_ME_CSR ) + ( $AGG_ME_CSW ) );"
	AddSecondaryMetric "ME_PHIT" "1 - ME_PEMP - ME_PMSS;"

	STR="IO_UTIL = ( IO_TIME[ 0 ] / ( $BIN * 1000 ) ); for( i = 1; i < ${#IO_TIME[@]}; i++ ){ "
	STR+="T_IO_UTIL = IO_TIME[ i ] / ( $BIN * 1000 ) ; if( T_IO_UTIL > IO_UTIL ) IO_UTIL= T_IO_UTIL; };"
	STR+="IO_UTIL = IO_UTIL*100;"
	AddSecondaryMetric "IO_UTIL" "$STR"
}

AddSecondaryMetric()
{
	SecondaryMetricName+=( $1 )

	if [[ $1 =~ CO_[A-Z|0-9]{4}$ ]]; then
		for (( i = 0; i < $NS; i++ ));
		do
			Result=$( echo "$1" | sed -e "s/CO_\([A-Z|0-9]\{1,\}\)/CO_\1[ $i ]/g" )
			Formula=$( echo "$2" | sed -e "s/CO_\([A-Z|0-9]\{1,\}\)/CO_\1[ $i ]/g" )
			SecondaryMetricFormula+=( "$Result = $Formula" )
		done
	elif [[ $1 =~ ME_[A-Z|0-9]{4}$ ]]; then
		for (( i = 0; i < $NS; i++ ));
    do
      Result=$( echo "$1" | sed -e "s/ME_\([A-Z|0-9]\{1,\}\)/ME_\1[ $i ]/g" )
      Formula=$( echo "$2" | sed -e "s/ME_\([A-Z|0-9]\{1,\}\)/ME_\1[ $i ]/g" )
			SecondaryMetricFormula+=( "$Result = $Formula" )
    done
	elif [[ $1 =~ IO_[A-Z|0-9]{4}$ ]]; then
			SecondaryMetricFormula+=( "$2" )
	else
		echo "Trident Parser Err: Secondary metric $1 creation error"
		exit 1;
	fi
}

FormatMetric()
{
	unset PrintMetricHeader
	unset PrintMetricFormat
	unset PrintMetricName

	AddPrintMetricFormat "Elapsed Time"		"%9.2F" "ETIME"		"#000000"
	AddPrintMetricFormat "Core Cycles" 		"%9.3G" "CO_CYCL"	"#A6D854"
	AddPrintMetricFormat "IPC" 						"%5.2F"	"CO_INPC" "#8060C0"

	AddPrintMetricFormat "Front-End" 			"%7.4F"	"CO_FBND"	"#A0A0A0"
	AddPrintMetricFormat "Back-End" 			"%7.4F"	"CO_BBND" "#2E8B57"
	AddPrintMetricFormat "Bad Spec" 			"%7.4F"	"CO_BSPC" "#0000CD"
	AddPrintMetricFormat "Retiring" 			"%7.4F"	"CO_RTIR"	"#F08080"

	declare -a EightColors=( '#238B45' '#74C476' '#CB181D' '#FB6A4A' \
														'#FCAE91' '#BAE4B3' '#EDF8E9' '#FEE5D9' );
	for (( ip = 0; ip < 8; ip++ ));
  do
    P1="Port"$ip
    P2="CO_PUT"$ip
    AddPrintMetricFormat "$P1" 					"%5.2F" "$P2"			"${EightColors[ip]}"
  done


	AddPrintMetricFormat "Read"						"%9.3G"	"ME_REBW"	"#386CB0"
	AddPrintMetricFormat "Write"					"%9.3G"	"ME_WRBW" "#F0027F"

	AddPrintMetricFormat "Page Empty"			"%7.4F"	"ME_PEMP"	"#7570B3"
	AddPrintMetricFormat "Page Miss"			"%7.4F"	"ME_PMSS"	"#D95F02"
	AddPrintMetricFormat "Page Hit"				"%7.4F"	"ME_PHIT"	"#66A61E"


	AddPrintMetricFormat "Util"						"%5.2F"	"IO_UTIL" "#FFDC00"
	AddPrintMetricFormat "Read"						"%9.3G" "IO_REBW" "#66C2A5"
	AddPrintMetricFormat "Write"					"%9.3G" "IO_WRBW"	"#8DA0CB"
	AddPrintMetricFormat "Read"						"%9.3G" "IO_RIOP"	"#66C2A5"
	AddPrintMetricFormat "Write"					"%9.3G" "IO_WIOP"	"#8DA0CB"
}

AddPrintMetricFormat()
{
	PrintMetricHeader+=( "$1" )
	PrintMetricFormat+=( "$2" )
	PrintMetricName+=( "$3" )
	PrintMetricColor+=( "$4" )

	Result="( "
	if [[ $3 =~ CO_[A-Z|0-9]{4}$ ]]; then
		for (( i = 0; i < $NS - 1; i++ ));
    do
      Result+="$( echo "$3" | sed -e "s/CO_\([A-Z|0-9]\{1,\}\)/CO_\1[ $i ]/g" ) + "
    done
		Result+="$( echo "$3" | sed -e "s/CO_\([A-Z|0-9]\{1,\}\)/CO_\1[ $(( $i )) ]/g" )"
  elif [[ $3 =~ ME_[A-Z|0-9]{4}$ ]]; then
    for (( i = 0; i < $NS - 1; i++ ));
    do
      Result+="$( echo "$3" | sed -e "s/ME_\([A-Z|0-9]\{1,\}\)/ME_\1[ $i ]/g" ) + "
    done
		Result+="$( echo "$3" | sed -e "s/ME_\([A-Z|0-9]\{1,\}\)/ME_\1[ $i ]/g" )"
	elif [[ $3 == IO_UTIL ]]; then
		Result+="$3"
  elif [[ $3 =~ IO_[A-Z|0-9]{4}$ ]]; then
		for (( i = 0; i < $NI - 1; i++ ));
    do
      Result+="$( echo "$3" | sed -e "s/IO_\([A-Z|0-9]\{1,\}\)/IO_\1[ $i ]/g" ) + "
		done
    Result+="$( echo "$3" | sed -e "s/IO_\([A-Z|0-9]\{1,\}\)/IO_\1[ $i ]/g" )"
  elif [[ $3 == "ETIME" ]]; then
		Result+="$3"
	else
    echo "Trident Parser Err: Print metric $3 creation error"
    exit 1;
  fi
	Result+=" )"
		
	PrintMetricFormula+=( "$Result" )
}

FindMetricLocation()
{
	declare -n RetParm=$2
	for (( i = 0; i < ${#PrintMetricName[@]}; i++ ))
	do
		if [[ $1 == ${PrintMetricName[i]} ]]; then
			RetParm+=( $i )
			return
		fi
	done

	echo "Trident PlotGN Err: Unable to find print metric $1"
  exit 1
}

ParseData()
{
	AWK_CMD="echo \""
	for (( i = 0; i < ${#PrintMetricName[@]}; i++ ));
  do
    AWK_CMD+="${PrintMetricName[i]};"
  done
	AWK_CMD+="TIMESTAMP;\";"

	AWK_CMD+="tail -n+5 $1 | awk -F \";\""
	#AWK_CMD+=" -v SCALE=\"$((SCALE-1))\""
	AWK_CMD+=" -v SCALE=\"$SCALE\""

	EST=$(date --date $ST +%s.%N)
  AWK_CMD+=" -v OldTimestamp=\"$EST\" '"

	if (( $SCALE > 1 )); then
	{
		AWK_CMD+="( NF > 20 && SCALE > 1 ){"
		for (( i = 0; i < ${#PrimaryMetricName[@]}; i++ ));
		do
			declare -n t="${PrimaryMetricName[i]}";
			for (( j = 0; j < ${#t[@]}; j++ ));
			do
				AWK_CMD+="${PrimaryMetricName[i]}[ $j ] += \$${t[j]};"
			done
		done
		AWK_CMD+="} "
	}
	fi

	#AWK_CMD+="( NF > 20 && NR % SCALE == 0 ){ Timestamp = \$$TSTP;"
	AWK_CMD+="( NF > 20 && NR % SCALE == 0 ){ Timestamp = \$$EPCH;"

	if (( $SCALE == 1 )); then
	for (( i = 0; i < ${#PrimaryMetricName[@]}; i++ ));
	do
		declare -n t="${PrimaryMetricName[i]}";
		for (( j = 0; j < ${#t[@]}; j++ ))
		do
			AWK_CMD+="${PrimaryMetricName[i]}[ $j ] += \$${t[j]};"
		done	
	done
  fi	

	#AWK_CMD+="S1 = \"date --date \\\"\" Timestamp \"\\\" +%s.%N\"; "
  #AWK_CMD+="S2 = \"date --date \\\"\" OldTimestamp \"\\\" +%s.%N\"; "
  #AWK_CMD+="S1 | getline S1T; "
  #AWK_CMD+="S2 | getline S2T; "
  #AWK_CMD+="close(S1); "
  #AWK_CMD+="close(S2); "
  #AWK_CMD+="ETIME = S1T - S2T; "
	AWK_CMD+="ETIME = Timestamp - OldTimestamp; "

	for (( i = 0; i < ${#SecondaryMetricFormula[@]}; i++ ));
  do
		AWK_CMD+="${SecondaryMetricFormula[i]} "
	done

	AWK_CMD+="printf \""

	for (( i = 0; i < ${#PrintMetricName[@]}; i++ ));
	do
		AWK_CMD+="${PrintMetricFormat[i]};"
	done

	AWK_CMD+=" %s;\\n\", "

	for (( i = 0; i < ${#PrintMetricName[@]}; i++ ));
  do
    AWK_CMD+="${PrintMetricFormula[i]}, "
  done

	#AWK_CMD+="Timestamp; "
	AWK_CMD+="\$$TSTP; "

	for (( i = 0; i < ${#PrimaryMetricName[@]}; i++ ));
  do
    declare -n t="${PrimaryMetricName[i]}";
    for (( j = 0; j < ${#t[@]}; j++ ))
    do
      AWK_CMD+="${PrimaryMetricName[i]}[ $j ] = 0;"
    done  
  done

	AWK_CMD+="}'"

	UFNAME=$( echo $1 | awk -F . '{print $1"."$2"."$3}' )
	UFNAME+=".$SCALE"
	OFNAME="$UFNAME.proc"

	#echo "$AWK_CMD" > RunParse.sh
	#( bash RunParse.sh ) > $OFNAME
	#( rm RunParse.sh )

	if [ -f $OFNAME ]; then
		read -r -p "Existing $OFNAME found, Overwrite? [y/N] " response
		response=${response,,}    # tolower
		if [[ "$response" =~ ^(yes|y)$ ]]; then
			rm $OFNAME
		fi
	fi

	if [ ! -f $OFNAME ]; then
		( echo "$AWK_CMD" | /usr/bin/env bash > $OFNAME )
	fi

	ORIG=$(grep -nR "Trident profiled" $1 | awk -F ":" '{print $1}')
	PROC=$(cat $OFNAME | wc -l)

	if (( $((PROC * SCALE)) < $((ORIG - 5)) ));
	then
			BADFNAME="$UFNAME.badproc"
			echo "Trident Parser Err:Records processing mismatch Orig:$ORIG Proc:$PROC"
			if [ -f $OFNAME ]; then
				mv $OFNAME $BADFNAME
			fi
			exit 1
	fi

	echo "Trident Parser Inf: Completed processing $((PROC - 1)) entries"
}

SetupPlot()
{
	ParseHeader $1
  ReadPrimaryMetric $1
  DeriveSecondaryMetric $1
  FormatMetric

	UFNAME=$( echo $1 | awk -F . '{print $1"."$2"."$3}' )
	UFNAME+=".$SCALE"
	PFNAME=$( ls $UFNAME".proc" 2> /dev/null ) && true
  
	if [ -z $PFNAME ]; then
  {
    printf "Trident PlotGN Inf: Reparsing $1 for scale=$SCALE\n"
		ParseData $1
		PFNAME=$( ls $UFNAME".proc" 2> /dev/null )
  }
  fi

	NXTICS=30
	MAX_RECORD=$( tail -n+2 $PFNAME | wc -l )
	XTIC_OFF=$(( MAX_RECORD / NXTICS ))
	XTIC_OFF=$(( XTIC_OFF <= 0 ? 1 : XTIC_OFF ))

	XTIC_STR=" "
	for (( i = 1; i < $MAX_RECORD - $XTIC_OFF; i+=$XTIC_OFF ));
	{
		TS=$( tail -n+2 $PFNAME | sed "$i q;d" | awk -F ";" '{printf "%d", $1}' ) && true
		XTIC_STR=$XTIC_STR"\"$TS\" $i, "
	}

	FTS=$( tail -n+2 $PFNAME | sed "$i q;d"| awk -F ";" '{printf "%d", $1}' ) && true
	XTIC_STR=$XTIC_STR"\"$FTS\" $i"
	FIN_XTIC=$i
}

SetupPlotGN()
{
	#PLOT_TYPE="default";
	GNUPLOT_STR=("reset")
	case $PLOT_TYPE in
		png)
			PLOT_FILE_EXT="png"
			GNUPLOT_STR+=("set terminal pngcairo nocrop enhanced size 4000,2000 \\" \
										"truecolor notransparent font \"Helvetica,30\";")
			OBJ_SZ_OFF=4
			ME_OBJ_X_OFF=-0.037
			IO_OBJ_X_OFF=-0.042
			CO_OBJ_X_OFF=-0.032
			#GNUPLOT_STR+=("set key font \",24\";")
			#GNUPLOT_STR+=("set ytics font \",24\";")
			;;

		svg)
			PLOT_FILE_EXT="svg"
			GNUPLOT_STR+=("set terminal svg enhanced size 2000,1000 \\" \
										"dynamic background rgb 'white' font \"Helvetica,30\";")
			GNUPLOT_STR+=("set key font \",20\";")
			OBJ_SZ_OFF=0
			ME_OBJ_X_OFF=0
			IO_OBJ_X_OFF=0
			CO_OBJ_X_OFF=0
			#GNUPLOT_STR+=("set ytics font \",28\";")
			;;
	esac

	GNUPLOT_STR+=("set autoscale;")
	GNUPLOT_STR+=("set key autotitle columnhead;")
	GNUPLOT_STR+=("set datafile separator \";\";")
	GNUPLOT_STR+=("set key top right inside vertical;")
	GNUPLOT_STR+=("set key box opaque;")
	GNUPLOT_STR+=("set key maxrows 1;")
	GNUPLOT_STR+=("set style data histogram;")
	GNUPLOT_STR+=("set style histogram rowstacked gap 0;")
	GNUPLOT_STR+=("set style fill solid noborder;")
	GNUPLOT_STR+=("set boxwidth 1;")
	
	GNUPLOT_STR+=("set xrange [1:$FIN_XTIC];")
	GNUPLOT_STR+=("set ytics nomirror;")
	GNUPLOT_STR+=("set tics scale 0;")
	
	#GNUPLOT_STR+=(";")
}

GenPlotStrCount()
{
	#GNUPLOT_STR+="plot '$PFNAME' u ${PRM[ 0 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 0 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 0 ]} ]}', "
  #GNUPLOT_STR+="'' u ${PRM[ 1 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 1 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 1 ]} ]}', "
  #GNUPLOT_STR+="'' u ${PRM[ 2 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 2 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 2 ]} ]}';"

	declare -n t=$1
	for (( i = 0; i < ${#t[@]}; i++ ))
	do
		STR=""
		if (( $i > 0 )); then
      STR+="'' "
    fi
		index=${t[ i ]}
		gindex=$(( index + 1 ))

		STR+="u ( \$$gindex ) "
		STR+="t \"${PrintMetricHeader[ $index ]}\" "
		STR+="fs solid 1 noborder axes x1y1 lc rgb '${PrintMetricColor[ $index ]}'"

		if (( $i < ${#t[@]} - 1 )); then
			STR+=", \\"
		fi
		GNUPLOT_STR+=("$STR")
	done
	unset t
}

GenPlotStrRate()
{
	#GNUPLOT_STR+="plot '$PFNAME' u ${PRM[ 0 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 0 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 0 ]} ]}', "
  #GNUPLOT_STR+="'' u ${PRM[ 1 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 1 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 1 ]} ]}', "
  #GNUPLOT_STR+="'' u ${PRM[ 2 ]} "
  #GNUPLOT_STR+="t \"${PrintMetricHeader[ ${PRM[ 2 ]} ]}\" lc rgb '${PrintMetricColor[ ${PRM[ 2 ]} ]}';"

	declare -n t=$1
	for (( i = 0; i < ${#t[@]}; i++ ))
	do
		STR=""
		if (( $i > 0 )); then
      STR+="'' "
    fi
		index=${t[ i ]}
		gindex=$(( index + 1 ))

		STR+="u ( \$$gindex / $BIN ) "
		STR+="t \"${PrintMetricHeader[ $index ]}\" "
		STR+="fs solid 1 noborder axes x1y1 lc rgb '${PrintMetricColor[ $index ]}'"

		if (( $i < ${#t[@]} - 1 )); then
			STR+=", \\"
		fi
		GNUPLOT_STR+=("$STR")
	done
	unset t
}

MemoryAnalysis()
{
	MAX_TRAN=$( echo "scale=2; 1 * $NS" | bc -l )
	TOP_MARGIN1=1.2
	TRAN_LABEL_Y=0.9
	BAND_LABEL_Y=2

	ME_GRAPH="$UFNAME.me.$PLOT_FILE_EXT"
	GENGRAPH_NAMES+=("$ME_GRAPH")
  printf "Trident PlotGN Inf: Generating memory analysis $ME_GRAPH\n"
	GNUPLOT_STR+=("set output '$ME_GRAPH';")
	GNUPLOT_STR+=("set multiplot layout 2,1;")
	GNUPLOT_STR+=("set tmargin $TOP_MARGIN1;")
	GNUPLOT_STR+=("set rmargin 1.1;")
	GNUPLOT_STR+=("set bmargin 0;")
	GNUPLOT_STR+=("set lmargin 10;")
	GNUPLOT_STR+=("set title sprintf( \"Trident Beta-v4 - Memory Access Classification\" ) offset 0,-1 tc rgb '#000099';")
	GNUPLOT_STR+=("")
	
	GNUPLOT_STR+=("unset xtics;")
	GNUPLOT_STR+=("unset ylabel;")
	#GNUPLOT_STR+=("set label 30 \"Memory Access (Bytes)\" at graph -0.05, graph 0.2 rotate by 90 tc lt 3;")
	GNUPLOT_STR+=("set ylabel \"Memory Acess (Bytes per sec)\" offset 2,0 tc rgb '#9966FF';")
	GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("set yrange [0:];")
	GNUPLOT_STR+=("set ytics offset 0.7;")
	GNUPLOT_STR+=("set ytics add ( \" \" 0 );")
	GNUPLOT_STR+=("L1=\"Bandwidth Analysis\";")
	#GNUPLOT_STR+=("set obj 10 rect at graph 0.095, graph $BAND_LABEL_Y size char strlen(L1)-3, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 10 L1 at graph 0.01, graph $BAND_LABEL_Y front;")
	GNUPLOT_STR+=("")
	unset PRM;
  FindMetricLocation "ME_REBW" "PRM"
  FindMetricLocation "ME_WRBW" "PRM"
  GNUPLOT_STR+=("plot '$PFNAME' \\")
  GenPlotStrRate "PRM"
	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("unset label 30;")
	GNUPLOT_STR+=("unset title;")
	GNUPLOT_STR+=("set arrow from graph -1, graph 1 to graph 2, graph 1 nohead dt 2 lw 2;")
	#GNUPLOT_STR+=("set arrow from -10,$MAX_TRAN to 1,$MAX_TRAN nohead dt 2 lw 2;")
	GNUPLOT_STR+=("set xlabel sprintf ( \"Elapsed Time (seconds)\t\t \\" \
								"(Histogram Bin Width = %.2f second)\", $BIN ) \\" \
								"offset 0,1 tc lt 1;")
	GNUPLOT_STR+=("L2=\"Transaction Analysis\";")
	GNUPLOT_STR+=("set obj 10 rect at graph 0.095+$ME_OBJ_X_OFF, graph $BAND_LABEL_Y size char strlen(L1)-3+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set obj 20 rect at graph 0.105+$ME_OBJ_X_OFF, graph $TRAN_LABEL_Y size char strlen(L2)-3+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 20 L2 at graph 0.01, graph $TRAN_LABEL_Y front;")
	GNUPLOT_STR+=("set tmargin 0;")
	GNUPLOT_STR+=("set bmargin 3;")
	GNUPLOT_STR+=("set xtics auto rotate by 45 right font \",24\" offset 0,0.3;")
	GNUPLOT_STR+=("set xtics ( $XTIC_STR );")
	GNUPLOT_STR+=("set xtics nomirror;")
	GNUPLOT_STR+=("")
	GNUPLOT_STR+=("set ylabel \"Memory transaction type\" offset -0.75,-0.5 tc rgb '#9966FF';")
	GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("set yrange [0:$MAX_TRAN];")
	GNUPLOT_STR+=("set ytics add ( \" \" $MAX_TRAN );")
	GNUPLOT_STR+=("")

	unset PRM;
  FindMetricLocation "ME_PEMP" "PRM"
  FindMetricLocation "ME_PMSS" "PRM"
  FindMetricLocation "ME_PHIT" "PRM"
  GNUPLOT_STR+=("plot '$PFNAME' \\")
  GenPlotStrCount "PRM"
	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("unset multiplot;")
}

IOAnalysis()
{
	MAX_TRAN=$( echo "scale=2; 1 * $NS" | bc -l )
	TOP_MARGIN1=1.2
	TRAN_LABEL_Y=0.9
	BAND_LABEL_Y=2

	IO_GRAPH="$UFNAME.io.$PLOT_FILE_EXT"
	GENGRAPH_NAMES+=("$IO_GRAPH")
  printf "Trident PlotGN Inf: Generating IO analysis $IO_GRAPH\n"
	GNUPLOT_STR+=("set output '$IO_GRAPH';")
	GNUPLOT_STR+=("set multiplot layout 2,1;")
	GNUPLOT_STR+=("set tmargin $TOP_MARGIN1;")
	GNUPLOT_STR+=("set rmargin 6.5;")
	GNUPLOT_STR+=("set bmargin 0;")
	GNUPLOT_STR+=("set lmargin 10;")
	GNUPLOT_STR+=("set title sprintf( \"Trident Beta-v4 - IO Access Classification\" ) offset 0,-1 tc rgb '#000099';")
	GNUPLOT_STR+=("")
	
	GNUPLOT_STR+=("unset xtics;")
	GNUPLOT_STR+=("set ylabel \"IO Access (KB/s)\" offset 2 tc lt 3;")
	GNUPLOT_STR+=("set y2label \"IO Utilization (%)\" offset -3 tc lt 7;")
	GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("set yrange [0:];")
	GNUPLOT_STR+=("set ytics offset 0.7,0.3;")
	GNUPLOT_STR+=("set ytics add ( \" \" 0 );")
	GNUPLOT_STR+=("L1=\"Transfer Rate Analysis\";")
	#GNUPLOT_STR+=("set obj 10 rect at graph 0.125, graph $BAND_LABEL_Y size char strlen(L1)-4.5, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 10 L1 at graph 0.022, graph $BAND_LABEL_Y front;")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("set y2tics")
	GNUPLOT_STR+=("set y2range[0:100]")
	GNUPLOT_STR+=("set y2tics add ( \"0\" 0 ) offset 0,0.3;" )
	GNUPLOT_STR+=("")
	unset PRM2;
  FindMetricLocation "IO_UTIL" "PRM2"
	UTIL_CURVE="u ( \$$(( ${PRM2[ 0 ]} + 1 )) ) t \"${PrintMetricHeader[ ${PRM2[ 0 ]} ]}\" "
  UTIL_CURVE+="w boxes fs solid 1 noborder axes x1y2 lc rgb '${PrintMetricColor[ ${PRM2[ 0 ]} ]}', '' \\"
  #UTIL_CURVE+="w lines axes x1y2 lc rgb '${PrintMetricColor[ ${PRM2[ 0 ]} ]}' lw 4, '' \\"


	unset PRM;
  FindMetricLocation "IO_REBW" "PRM"
  FindMetricLocation "IO_WRBW" "PRM"
  GNUPLOT_STR+=("plot '$PFNAME' \\")
  GNUPLOT_STR+=("$UTIL_CURVE")
  GenPlotStrRate "PRM"
	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")
	GNUPLOT_STR+=("unset title;")
	GNUPLOT_STR+=("set arrow from graph -1, graph 1 to graph 2, graph 1 nohead dt 2 lw 2;")
	GNUPLOT_STR+=("set xlabel sprintf ( \"Elapsed Time in seconds\t\t \\" \
								"(Histogram Bin Width = %.2f second)\", $BIN ) \\" \
								"offset 0,1 tc lt 1;")
	GNUPLOT_STR+=("L2=\"Operation Rate Analysis\";")
	GNUPLOT_STR+=("set obj 10 rect at graph 0.125+$IO_OBJ_X_OFF, graph $BAND_LABEL_Y size char strlen(L1)-4.5+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set obj 20 rect at graph 0.125+$IO_OBJ_X_OFF, graph $TRAN_LABEL_Y size char strlen(L2)-5+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 20 L2 at graph 0.02, graph $TRAN_LABEL_Y front;")
	GNUPLOT_STR+=("set tmargin 0;")
	GNUPLOT_STR+=("set bmargin 3;")
	GNUPLOT_STR+=("set xtics auto rotate by 45 right font \",24\" offset 0,0.3;")
	GNUPLOT_STR+=("set xtics ( $XTIC_STR );")
	GNUPLOT_STR+=("set xtics nomirror;")
	GNUPLOT_STR+=("")
	GNUPLOT_STR+=("set ylabel \"IO Operations per second\" offset 0,0 tc rgb '#9966FF';")
	#GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("")
	#GNUPLOT_STR+=("set yrange [0:500];")
	
	unset PRM;
  FindMetricLocation "IO_RIOP" "PRM"
  FindMetricLocation "IO_WIOP" "PRM"

	GNUPLOT_STR+=("max=0; med=0;")
	GNUPLOT_STR+=("stats '$PFNAME' u $((1+${PRM[ 0 ]})) nooutput;")
	GNUPLOT_STR+=("if( STATS_max > max ) max = STATS_max;")
	GNUPLOT_STR+=("if( STATS_median > med ) med = STATS_median;")
	GNUPLOT_STR+=("stats '$PFNAME' u $((1+${PRM[ 1 ]})) nooutput;")
	GNUPLOT_STR+=("if( STATS_max > max ) max = STATS_max;")
	GNUPLOT_STR+=("if( STATS_median > med ) med = STATS_median;")
	#GNUPLOT_STR+=("show variables all;")
	GNUPLOT_STR+=("set yrange [0:((max+med)/$BIN)];")
	GNUPLOT_STR+=("set ytics add ( \" \" STATS_max+10 );")
 
	GNUPLOT_STR+=("set y2tics add ( \"0\" 0 ) offset 0,0;" )
	GNUPLOT_STR+=("set y2tics add ( \"100\" 100 ) offset 0,-0.3;" )

 	GNUPLOT_STR+=("plot '$PFNAME' \\")
  GNUPLOT_STR+=("$UTIL_CURVE")
  GenPlotStrRate "PRM"

	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("unset multiplot;")

}

CoreAnalysis()
{
	TOP_MARGIN1=1.2
	TRAN_LABEL_Y=0.9
	BAND_LABEL_Y=2

	CO_GRAPH="$UFNAME.co.$PLOT_FILE_EXT"
	GENGRAPH_NAMES+=("$CO_GRAPH")
  printf "Trident PlotGN Inf: Generating core efficiency analysis $CO_GRAPH\n"
	GNUPLOT_STR+=("set output '$CO_GRAPH';")
	GNUPLOT_STR+=("set multiplot layout 2,1;")
	GNUPLOT_STR+=("set tmargin $TOP_MARGIN1;")
	GNUPLOT_STR+=("set rmargin 10;")
	GNUPLOT_STR+=("set bmargin 0;")
	GNUPLOT_STR+=("set lmargin 6;")
	GNUPLOT_STR+=("set title sprintf( \"Trident Beta-v4 - Core Efficiency Classification\" ) offset 0,-1 tc rgb '#000099';")
	GNUPLOT_STR+=("")
	
	GNUPLOT_STR+=("unset xtics;")
	GNUPLOT_STR+=("set ylabel \"IPC\" offset 3,0 tc lt 3;")
	GNUPLOT_STR+=("set y2label \"Unhalted Cycles Per Sec\" offset -3 tc lt 7;")
	GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("set yrange [0:4];")
	GNUPLOT_STR+=("set ytics add offset 0.7,0.3;")
	GNUPLOT_STR+=("L1=\"Efficiency Analysis\";")
	#GNUPLOT_STR+=("set obj 10 rect at graph 0.092, graph $BAND_LABEL_Y size char strlen(L1)-5, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 10 L1 at graph 0.01, graph $BAND_LABEL_Y front;")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("set y2tics;")
	GNUPLOT_STR+=("set autoscale y2;")
  GNUPLOT_STR+=("set y2range[0:];")
  GNUPLOT_STR+=("set y2tics offset -1,0.3;" )
  GNUPLOT_STR+=("")
  unset PRM2;
  FindMetricLocation "CO_CYCL" "PRM2"
  UTIL_CURVE="u ( \$$(( ${PRM2[ 0 ]} + 1 )) / $BIN ) t \"${PrintMetricHeader[ ${PRM2[ 0 ]} ]}\" "
  UTIL_CURVE+="w boxes fs solid 1 axes x1y2 lc rgb '${PrintMetricColor[ ${PRM2[ 0 ]} ]}', '' \\"

	unset PRM;
  FindMetricLocation "CO_INPC" "PRM"
  GNUPLOT_STR+=("plot '$PFNAME' \\")
  GNUPLOT_STR+=("$UTIL_CURVE")
  GenPlotStrCount "PRM"
	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("unset label 30;")
	GNUPLOT_STR+=("unset title;")
	GNUPLOT_STR+=("unset y2tics;")
	GNUPLOT_STR+=("unset y2label;")
	GNUPLOT_STR+=("set arrow from graph -1, graph 1 to graph 2, graph 1 nohead dt 2 lw 2;")
	#GNUPLOT_STR+=("set arrow from -10,$MAX_TRAN to 1,$MAX_TRAN nohead dt 2 lw 2;")
	GNUPLOT_STR+=("set xlabel sprintf ( \"Elapsed Time (seconds)\t\t \\" \
								"(Histogram Bin Width = %.2f second)\", $BIN ) \\" \
								"offset 0,1 tc lt 1;")
	GNUPLOT_STR+=("L2=\"Top-Down Analysis\";")
	GNUPLOT_STR+=("set obj 10 rect at graph 0.092+$CO_OBJ_X_OFF, graph $BAND_LABEL_Y size char strlen(L1)-5+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set obj 20 rect at graph 0.092+$CO_OBJ_X_OFF, graph $TRAN_LABEL_Y size char strlen(L2)-3+$OBJ_SZ_OFF, char 1.05 fc rgb \"#50FFFFFF\" front;")
	GNUPLOT_STR+=("set label 20 L2 at graph 0.01, graph $TRAN_LABEL_Y front;")
	GNUPLOT_STR+=("set tmargin 0;")
	GNUPLOT_STR+=("set bmargin 3;")
	GNUPLOT_STR+=("set xtics auto rotate by 45 right font \",24\" offset 0,0.3;")
	GNUPLOT_STR+=("set xtics ( $XTIC_STR );")
	GNUPLOT_STR+=("set xtics nomirror;")
	GNUPLOT_STR+=("")
	GNUPLOT_STR+=("set ylabel \"Execution Slots\" offset 3,0 tc rgb '#9966FF';")
	GNUPLOT_STR+=("set autoscale y;")
	GNUPLOT_STR+=("set yrange [0:1];")
	GNUPLOT_STR+=("set ytics 0.1;")
	GNUPLOT_STR+=("set ytics add ( \" \" 1 );")
	GNUPLOT_STR+=("")

	unset PRM;
  FindMetricLocation "CO_FBND" "PRM"
  FindMetricLocation "CO_BSPC" "PRM"
  FindMetricLocation "CO_RTIR" "PRM"
  FindMetricLocation "CO_BBND" "PRM"
  GNUPLOT_STR+=("plot '$PFNAME' \\")
  GenPlotStrCount "PRM"
	GNUPLOT_STR+=(";")
	GNUPLOT_STR+=("")

	GNUPLOT_STR+=("unset multiplot;")
}

CoreBackendAnalysis()
{
  TOP_MARGIN1=1.2
  TRAN_LABEL_Y=0.9
  BAND_LABEL_Y=2

	CB_GRAPH="$UFNAME.cb.$PLOT_FILE_EXT"
	GENGRAPH_NAMES+=("$CB_GRAPH")
  printf "Trident PlotGN Inf: Generating core backend analysis $CB_GRAPH\n"
  GNUPLOT_STR+=("set output '$CB_GRAPH';")
	GNUPLOT_STR+=("set tmargin 1;")
  GNUPLOT_STR+=("set rmargin 1;")
  #GNUPLOT_STR+=("set bmargin 0;")
  GNUPLOT_STR+=("set lmargin 6;")
  GNUPLOT_STR+=("set title sprintf( \"Trident Beta-v4 - Core Backend Utilization\" ) offset 0,-1 tc rgb '#000099';")
	GNUPLOT_STR+=("set ylabel \"Ratio of cycles the port is active\" offset 3,0 tc lt 3;")
	GNUPLOT_STR+=("set autoscale y;")
  GNUPLOT_STR+=("set yrange [0:];")
  GNUPLOT_STR+=("set ytics 0.2;")
  GNUPLOT_STR+=("set ytics add offset 0.7,0.3;")
	GNUPLOT_STR+=("set xlabel sprintf ( \"Elapsed Time (seconds)\t\t \\" \
                "(Histogram Bin Width = %.2f second)\", $BIN ) \\" \
                "offset 0,1 tc lt 1;")
	GNUPLOT_STR+=("set xtics auto rotate by 45 right font \",24\" offset 0,0.3;")
  GNUPLOT_STR+=("set xtics ( $XTIC_STR );")
  GNUPLOT_STR+=("set xtics nomirror;")

	unset PRM;
  FindMetricLocation "CO_PUT0" "PRM"
  FindMetricLocation "CO_PUT1" "PRM"
  FindMetricLocation "CO_PUT5" "PRM"
  FindMetricLocation "CO_PUT6" "PRM"
  FindMetricLocation "CO_PUT2" "PRM"
  FindMetricLocation "CO_PUT3" "PRM"
  FindMetricLocation "CO_PUT4" "PRM"
  FindMetricLocation "CO_PUT7" "PRM"
	GNUPLOT_STR+=("plot '$PFNAME' \\")
  GenPlotStrCount "PRM"
  GNUPLOT_STR+=(";")
  GNUPLOT_STR+=("")
}

PlotGN()
{
	GNUPLOTV=$(gnuplot -V | awk '{print $2}')

  if (( $( echo "scale=2; $GNUPLOTV < 5.2" | bc -l ) )); then
  {
    printf "Trident Parser Err: Need Gnuplot >= v5.2 \n"
    exit 1
  }
  fi

	gnuplot <<-EOFMarker
	$(for (( i = 0; i < ${#GNUPLOT_STR[@]}; i++ )); do echo ${GNUPLOT_STR[i]}; done) 
	EOFMarker
	
	#(for (( i = 0; i < ${#GNUPLOT_STR[@]}; i++ )); do echo ${GNUPLOT_STR[i]}; done) 
}

Parse()
{
	ParseHeader $1
	ReadPrimaryMetric $1
	DeriveSecondaryMetric $1
	FormatMetric
	ParseData $1
}

Plot()
{
	SetupPlot $1

	SetupPlotGN
	MemoryAnalysis
	PlotGN

	SetupPlotGN
	IOAnalysis
	PlotGN

	SetupPlotGN
	CoreAnalysis
	PlotGN

	SetupPlotGN
	CoreBackendAnalysis
	PlotGN
}

Combine()
{
  printf "Trident PlotGN Inf: Generating analysis overview $UFNAME.overview.png\n"
	convert -border 20 -bordercolor '#00FF7D' $IO_GRAPH $IO_GRAPH.tmp &
	convert -border 20 -bordercolor '#8200FF' $ME_GRAPH $ME_GRAPH.tmp &
	convert -border 20 -bordercolor '#FF8C00' $CB_GRAPH $CB_GRAPH.tmp &
	convert -border 20 -bordercolor '#FF0032' $CO_GRAPH $CO_GRAPH.tmp &
	wait
	convert $CB_GRAPH.tmp $CO_GRAPH.tmp +append $UFNAME.btile.png &
	convert $IO_GRAPH.tmp $ME_GRAPH.tmp +append $UFNAME.ttile.png &
	wait
	convert -gravity Center $UFNAME.ttile.png $UFNAME.btile.png -append $UFNAME.overview.png
	rm $UFNAME.btile.png $UFNAME.ttile.png $CB_GRAPH.tmp $CO_GRAPH.tmp $IO_GRAPH.tmp $ME_GRAPH.tmp
}

Usage()
{
    printf "Usage: $0 [OPTION] [TRIDENT LOG FILE] \n";
    printf "\nOptions: \n"
    printf "\t-h, --help \t\t Print usage \n";
    printf "\t-s, --scale=VALUE \t Histogram binwidth, VALUE >= 1\n";
    printf "\t-p, --parse \t\t Parse the trident log file \n";
    printf "\t-g, --graph \t\t Graph the parsed data file \n";
    printf "\t-c, --combine \t\t Combine the graphs into a single overview, use with '-g' \n";
    printf "\t-l, --svg \t\t Generate plots as vector graphs (Warning! very large output files) \n";
    printf "\nReport bugs to smuralid@cern.ch.\n"
    exit 4
}

! getopt --test > /dev/null 
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    printf "Trident Parser Err: Unsupported environment, `getopt --test` failed. Please rectify.\n"
    exit 1
fi

OPTIONS=s:vhpgcl
LONGOPTS=scale:,verbose,help,parse,plot,combine,svg

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
PLOT_TYPE="png";
SCALE=1 
v=n
h=n
g=n
p=n
c=n
l=n

# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -s|--scale)
            SCALE=$2
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
        -g|--graph)
            g=y
            shift
            ;;
        -p|--parse)
            p=y
            shift
            ;;
        -c|--combine)
            c=y
            shift
            ;;
        -l|--svg)
            l=y
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            printf "Trident Parser Err: Unknown option <<<$1>>> \n"
            exit 3
            ;;
    esac
done

if [[ $# -ne 1 ]] || [[ $h == 'y' ]]; then
	Usage
fi

if ! [[ $SCALE =~ ^[0-9]+$ ]] || ((  $( echo "scale=2; $SCALE < 1" | bc -l ) )); then
	printf "Trident Parser Err: scale should be a number >= 1\n"
	exit 1
fi

#echo "verbose: $v, scale: $SCALE, in: $1"

if [[ $g == 'y' ]]; then
	Plot $1
elif [[ $p == 'y' ]]; then
	Parse $1
elif [[ $l == 'y' ]]; then
	PLOT_TYPE="svg";
	Plot $1
else
	Usage
fi

if [[ $g == 'y' && $c == 'y' ]]; then
	Combine
fi

