#!/bin/bash
#
# ncs_and_report_to_email.bash.bash 
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
# v1.0.1 - 2017-05-28 - Nelbren <nelbren@gmail.com>
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Send email via two servers, use the hour (odd and even) to select the server."
  echo ""
  echo -e "Where: "
  echo -e "       -f|--force\tForce to send email by passing the odd/even method "
  echo -e "       -mc=COLS|--maxcols=COLS\t\tSet the max columns of console"
  echo -e "       -h|--help\t\t\tShow this information."
  exit 0
}

params() {
  for i in "$@"; do
    case $i in
      -f|--force) force=1; shift;;
      -mc=*|--maxcols=*) max_cols="${i#*=}"; shift;;
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done

  [ -z "$force" ] && force=0
  if [ -z "$max_cols" ]; then
    max_cols=$(tput cols 2>/dev/null)
    if [ -z "$max_cols" -o "$max_cols" == "0" ]; then 
      max_cols=80
    fi
  fi
  #echo $state_previous $silent $max_cols $all
}

get_number() {
  fhost=$1
  equal=$2
  max_servers=$(grep server_ $conf | grep host | wc -l)
  i=1
  while true; do
    n=$(printf "%02d\n" $i)
    r=$(grep server_$n $conf)
    if [ -n "$r" ]; then
      name=$(echo "$r" | grep server_${n}_name | cut -d"=" -f2)
      host=$(echo "$r" | grep server_${n}_host | cut -d"=" -f2)
      if [ "$host" == "$fhost" -a "$equal" == "0" ]; then
        echo $n
        break
      fi
      if [ "$host" != "$fhost" -a "$equal" == "1" ]; then
        echo $n
        break
      fi
    else
      break
    fi
    i=$((i+1))
  done
}

config() {
  number=$(get_number $myname 0)
  number_alterative=$(get_number $myname 1)

  if [ -n "$number" ]; then
    name=$(grep server_${number}_name $conf | cut -d"=" -f2)
    host=$(grep server_${number}_host $conf | cut -d"=" -f2)
    host_alternative=$(grep server_${number_alterative}_host $conf | cut -d"=" -f2)
    mod=$(($number%2))
    mod=$(echo '!'$mod | bc)
    nagios="NAGIOS$name"
  else
    echo "Can't find $myname!"
    exit 1
  fi
}

is_my_turn() {
  config 

  if [ -z "$host" ]; then
    nagios_servers=$(grep ^server_ $conf | grep _host | cut -d"=" -f2 | tr "[\n]" "[,]")
    l=${#nagios_servers}
    nagios_servers=${nagios_servers:0:$l-1}
    echo "Must run on $nagios_servers"
    exit 1
  fi
  #echo $ip $name2 $mod $nagios

  hour=$(date +"%H")
  hour=$(echo $hour | bc) # strip 09 to 9
  mod_calc=$(($hour%2))
  mod_calc=$(echo '!'$mod_calc | bc)
  #echo "$mod_calc == $mod" 
  if [ "$mod_calc" == "$mod" ]; then
    responsable=1
    turn=1
  else
    if ping -c1 -W 1 $host_alternative >/dev/null; then
      responsable=1
      turn=0
    else
      responsable=0
      turn=1
    fi
  fi
}

process() {
                        #0       1          2          3
  declare -a status_s=('OK' 'WARNING' 'CRITICAL' 'UNKNOWN');
  if [ -z "$mail_background" -o \
          "$mail_background" == "terminal" ]; then
    $check -mc=80 > $tmp1
    status=$?
  else
    $check --initialstate=9 --quiet
    status=$?
    $check -mc=80 --initialstate=$status > $tmp1
  fi 

  datetime=$(head -1 $tmp1 | cut -d"@" -f2)
  datetime=$(echo $datetime | cut -d" " -f1-2)
  asunto="${nagios}@${datetime}=${status_s[$status]}"

  cat $tmp1 | $ansi2html --bg=dark > $tmp2
  php $send_email "$mail_to" "$mail_from" "$asunto" $tmp2
}

cleanup() {
  [ -r $tmp1 ] && rm $tmp1
  [ -r $tmp2 ] && rm $tmp2
}

myself=$(basename $0)
myname=$(uname -n)
tmp1=$(mktemp /tmp/$myself.output.ansi.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
tmp2=$(mktemp /tmp/$myself.output.html.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }

base=/usr/local/ncs
check=${base}/ncs_and_report_to_console.bash 
send_email=${base}/resources/send_email.php
ansi2html=${base}/resources/ansi2html.sh 

conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf

params "$@"

is_my_turn
if [ "$turn" == "1" ]; then
  echo "It's my turn."
  process
else
  if [ "$force" == "1" ]; then
    echo "It's my turn. (Forced!)"
    process
  else
    echo "Not my turn."
    if [ "$responsable" == "1" ]; then
      echo "$host_alternative answer back"
    else
      echo "$host_alternative don't answer back, then i can help..."
      echo "It's my turn."
      process
    fi
  fi
fi
cleanup
