#!/bin/bash
#
# ncs_and_start_the_screen_saver.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Start Screen Saver."
  echo ""
  echo -e "Where: "
  echo -e "       -c|--console\tSend output to the console (set in config)"
  echo -e "       -h|--help\tShow this information."
  exit 0
}

params() {
  for i in "$@"; do
    case $i in
      -c|--console) terminal=$console; shift;;
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done

  [ -z "$terminal" ] && terminal=$(tty)
}

myself=$(basename $0)
myname=$(uname -n)

base=/usr/local/ncs
script=${base}/ncs_and_report_to_screen_saver.bash
conf=${base}/ncs.conf.${myname}
[ -x $conf ] || exit 1
. $conf

params "$@"

ps_output=$(ps -ef | grep "[/]bin/bash $script")
pid=$(echo $ps_output | cut -d" " -f2)

if [ -z "$pid" ]; then
  echo "setsid /bin/bash -c \"exec sudo $script <> $terminal >&0 2>&1 &\""
  setsid /bin/bash -c "exec sudo $script <> $terminal >&0 2>&1 &"
fi
