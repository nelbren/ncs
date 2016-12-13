#!/bin/bash
#
# ncs_and_stop_the_screen_saver.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
#

base=/usr/local/ncs
script=${base}/ncs_and_report_to_screen_saver.bash

ps_output=$(ps -ef | grep "[/]bin/bash $script")
pid=$(echo $ps_output | cut -d" " -f2)

if [ -n "$pid" ]; then
  echo "kill -9 $pid"
  kill -9 $pid
fi
