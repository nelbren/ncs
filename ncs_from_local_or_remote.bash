#!/bin/bash
#
# ncs_from_local_or_remote.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
# v1.0.1 - 2017-05-31 - Nelbren <nelbren@gmail.com>
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Get report from local or remote."
  echo "By default search local and remote using the configuration."
  echo ""
  echo -e "Where: "
  echo -e "       -s=SYSTEM|--system=SYSTEM\tGet from SYSTEM."
  echo -e "       -mc=COLS|--maxcols=COLS\t\tSet the max columns of console"
  echo -e "       -q|--quiet\t\t\tGet only the state"
  echo -e "       -h|--help\t\t\tShow this information."
  exit 0
}

get_cols_and_rows()  {
  terminal=$(tty)
  if [ "$terminal" == "not a tty" ]; then
    columns=80
    rows=25
  else
    columns=$(stty -a <"$terminal" | grep -Po '(?<=columns )\d+')
    rows=$(stty -a <"$terminal" | grep -Po '(?<=rows )\d+')
  fi
}

params() {
  for i in "$@"; do
    case $i in
      -s=*|--system=*) system="${i#*=}"; shift;;
      -mc=*|--maxcols=*) max_cols="${i#*=}"; shift;;
      -q|--quiet) silent=1; shift;;
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done
  [ -z "$silent" ] && silent=0
  if [ -z "$max_cols" ]; then
    get_cols_and_rows
    max_cols=$columns
  fi
}

ssh_command() {
  command="$@"
  su nagios -c "ssh -o ConnectTimeout=3 -q -p ${port} nagios@${host} $command"
}

automatic() {
  if [ -r $live_sock ]; then
    #echo "Usando nagios localmente..."
    $ncs_and_report_to_console --maxcols=$max_cols $params 
    exit $?
  fi

  grep "^server_" $conf | \
  while read linea; do
    if echo $linea | grep -q host; then
      host=$(echo $linea | cut -d"=" -f2)
    fi
    if echo $linea | grep -q port; then
      if [ "$myname" == "$host" ]; then
        continue
      fi
      port=$(echo $linea | cut -d"=" -f2)
      ssh_command "[ -x $ncs_and_report_to_console ]"
      if [ "$?" == "0" ]; then
        #echo "Usando nagios remotamente(${host})..."
        ssh_command "$ncs_and_report_to_console --initialstate=9 --maxcols=$max_cols $params"
        exit $?
        break
      fi
    fi
  done
}

system() {
  grep "^server_" $conf | \
  while read linea; do
    if echo $linea | grep -q host; then
      host=$(echo $linea | cut -d"=" -f2)
    fi
    if echo $linea | grep -q port; then
      if [ "$system" == "$host" ]; then
        port=$(echo $linea | cut -d"=" -f2)
        ssh_command "$ncs_and_report_to_console --initialstate=9 --maxcols=$max_cols $params"
        exit $?
        break
      fi
    fi
  done
}

myself=$(basename $0)
myname=$(uname -n)

base=/usr/local/ncs
conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf

params=$@
params "$@"

if [ -z "$system" ]; then
  automatic
else
  system
fi
