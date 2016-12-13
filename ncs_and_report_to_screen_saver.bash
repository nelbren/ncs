#!/bin/bash
#
# ncs_and_report_to_screen_saver.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Show an Nagios Report of (all) Hosts/Services (with problems and downtime)."
  echo "Use the color background from the states, play alarm and speech the summary."
  echo ""
  echo -e "Where: "
  echo -e "       -naa|--noaudioalarm\t\tDon't play audio alarms"
  echo -e "       -nas|--noaudiospeech\t\tDon't play speech summary"
  echo -e "       -h|--help\t\t\tShow this information."
  exit 0
}

params() {
  for i in "$@"; do
    case $i in
      -naa|--noaudioalarm) noaudioalarm=1; shift;;
      -nas|--noaudiospeech) noaudiospeech=1; shift;;
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done

  [ -z "$noaudioalarm" ] && noaudioalarm=0
  [ -z "$noaudiospeech" ] && noaudiospeech=0
}


color_background() {
  estatus=$1
  case $estatus in
    0) echo -en "\e[30;48;5;82m";;
    1) echo -en "\e[30;48;5;11m";;
    2) echo -en "\e[30;48;5;9m";;
    3) echo -en "\e[30;48;5;13m";;
  esac
}

normal() {
  echo -en "\e[0m"
}

servidor_listo() {
  nc -vz -w1 $host_nagios 22 1>/dev/null 2>&1
  if [ "$?" == "0" ]; then
    echo "SI"
  else
    echo "NO"
  fi
}

get_cols() {
  if [ -z "$terminal" ]; then
    terminal=/dev/$(who am i | cut -d" " -f2)
  fi
  max_cols=$(stty -F $terminal size | cut -d" " -f2)

  if [ -z "$max_cols" ]; then
    max_cols=80
  fi
}

play() {
  sound=$1
  player=/usr/bin/mplayer
  if [ -x $player ] ; then
    $player -really-quiet -endpos 2 "$1" 2>/dev/null
  fi
}

speech() {
  player=/usr/bin/espeak
  if [ -x $player ] ; then
    grep -E "SERVICES:|SERVICIOS:|HOSTS:EQUIPOS:" $filetemp1 > $filetemp2
    sed "s/\x1B\[[0-9;]*[JKmsu]//g" $filetemp2 > $filetemp1
    summary=$(cat $filetemp1 | cut -d"|" -f1-6)
    $player -v "$lang" "$summary" 2>/dev/null
  fi
}

cleanup() {
  [ -r $filetemp1 ] && rm $filetemp1
  [ -r $filetemp2 ] && rm $filetemp2
}

myself=$(basename $0)
myname=$(uname -n)
filetemp1=$(mktemp /tmp/$myself.1.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
filetemp2=$(mktemp /tmp/$myself.2.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }
refresh=60
terminal=$(tty)

base=/usr/local/ncs
check=${base}/ncs_from_local_or_remote.bash
conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf

params "$@"

if echo $terminal | grep -q "tty" ; then
  setterm -blank 0 > $terminal
fi
echo -n -e "\033[9;0]"

get_cols

while true; do
  $check --quiet
  state=$?

  color_background $state
  clear > $terminal

  $check  --initialstate=$state --maxcols=$max_cols | tee $filetemp1
  exitcode=${PIPESTATUS[0]}

  case $exitcode in
    0) mp3="$dir_mp3/$mp3_ok";;
    1) mp3="$dir_mp3/$mp3_warning";;
    2) mp3="$dir_mp3/$mp3_critical";;
    3) mp3="$dir_mp3/$mp3_unknown";;
  esac

  [ "$noaudioalarm" == "0" ] && play "$mp3"
  [ "$noaudiospeech" == "0" ] && speech

  echo ""
  contador=$refresh
  while [ $contador -gt 0 ]; do
    echo -ne "\033[2K" ; printf "\r"
    echo -n "REFRESH IN: $contador seconds"
    contador=$((contador-1))
    sleep 1
  done
  normal
done

cleanup
