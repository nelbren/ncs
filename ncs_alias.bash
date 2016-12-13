#!/bin/bash
#
# ncs_alias.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
#

base=/usr/local/ncs

alias ncs="sudo ${base}/ncs_from_local_or_remote.bash"
alias ncs_all="sudo ${base}/ncs_from_local_or_remote.bash -sa"
alias ncs_sum="sudo ${base}/ncs_from_local_or_remote.bash -ss"
alias ncs_start="sudo ${base}/ncs_and_start_the_screen_saver.bash"
alias ncs_stop="sudo ${base}/ncs_and_stop_the_screen_saver.bash"
alias ncs_mail="sudo ${base}/ncs_and_report_to_email.bash"
