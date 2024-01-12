#!/bin/bash
#
# ncs_and_check_prerequisites.bash
#
# v1.0.0 - 2016-12-16 - Nelbren <nelbren@gmail.com>
# v1.0.1 - 2017-01-10 - Nelbren <nelbren@gmail.com>
# v1.0.2 - 2018-01-04 - Nelbren <nelbren@gmail.com>
# v1.0.3 - 2024-01-09 - Nelbren <nelbren@gmail.com>
#

show_task() {
  echo -ne "  $1..." 
}

color() {
  echo -en "$S"
  case $1 in
    0) echo -en "${COK}";; # OK
    1) echo -en "${CWA}";; # WARNING
    2) echo -en "${CCR}";; # CRITICAL
    9) echo -en "${CUN}";;
  esac
}

check_task() {
  echo -en "$S => "
  r=$1
  if [ "$r" == "0" ]; then
    color 0
    echo -n "[ OK ]"
  else
    c=1
    [ "$warning" == "1" ] || c=2
    color $c
    echo -n "[ FAIL! ]"
  fi
  echo -en "$S"
  echo ""
}

check_conf1() {
  show_task "Exist ${conf}"
  if [ -r $conf ]; then
    r=0 
  else
    r=1
  fi
  check_task $r
  if [ "$r" != "0" ]; then
    echo -e "\n\tTry this to fix:\n\n\tcd $base\n\tmv ncs.conf.example ncs.conf\n"
    exit 1
  fi
}

check_bash() {
  bash="#!/bin/bash"
  echo -en "  ${bash}"
  r=0
  [ "$line" == "$bash" ] || r=1
  check_task $r
  if [ "$r" != "0" ]; then
    echo -e "\n\tTry this to fix:\n\n\tcd $base\n\techo '$bash'; cat $conf > /tmp/ncs.conf\n\tmv /tmp/ncs.conf ncs.conf\n"
    exit 1
  fi
}

check_param_comun() {
  p=$1
  v=$2
  c=$3
  v1=$4
  v2=$5
  #echo "p=$p v=$v c=$c v1=$v1 v2=$v2"
  echo -en "  ${CIN4}${p}$S=${CIN2}${v}$S"
  r=0
  case $c in
   choices) [ "$v" == "$v1" -o "$v" == "$v2" ] || r=1;;
     equal) [ "$v" == "$v1" ] || r=1;;
 different) [ "$v" != "$v1" ] || r=1;;
 directory) [ -d "$v" ] || r=1;;
executable) if [ -n "$v1" ]; then
              owner=$(stat -c '%U' $v 2>/dev/null)
              if [ "$owner" != "$v1" ]; then
                [ -x "$v" ] || r=1
              fi
            else
              [ -x "$v" ] || r=1
            fi;;
   special) [ -c "$v" ] || r=1;;
      read) [ -r "$v" ] || r=1;;
       mp3) v="$(echo $v | sed "s/\"//g")"
            file=$(file "$v")
            type="MPEG ADTS, layer III, v1, 128 kbps, 44.1 kHz, JntStereo"
            ( echo $file | grep -q "$type" ) ||  r=1;;
  esac
  check_task $r
}

check_param() {
  l=$1
  p=$(echo $l | cut -d"="  -f1)
  v=$(echo $l | cut -d"="  -f2)
  
  case $p in
    lang) check_param_comun $p "$v" choices "en" "es";;
    name) check_param_comun $p "$v" different "";;
    base) base=$v
          check_param_comun $p "$v" directory;;
    ncs_and_report_to_console) v1=$base/$(basename "$v")
          check_param_comun $p "$v1" executable;;
    ncs_from_local_or_remote) v1=$base/$(basename "$v")
          check_param_comun $p "$v1" executable;;
    nagiostats) warning=1
                check_param_comun $p "$v" executable nagios
                warning=0;;
    console) check_param_comun $p "$v" special;;
    mail_background) check_param_comun $p "$v" choices "screen_saver" "terminal";;
    mail_to) check_param_comun $p "$v" different "";;
    mail_from) check_param_comun $p "$v" different "";;
    dir_mp3) dir_mp3=$v
             check_param_comun $p "$v" directory;;
    mp3_ok) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_warning) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_critical) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    mp3_unknown) v1=$dir_mp3/$v
            check_param_comun $p "$v1" mp3;;
    domain) check_param_comun $p "$v" different "";;
    server_*_name) check_param_comun $p "$v" different "";;
    server_*_host) check_param_comun $p "$v" different "";;
    server_*_port) check_param_comun $p "$v" different "";;
  esac
}

check_conf2() {
  n=0
  cat $conf | \
  while read line; do
    n=$((n+1)) 
    if [ "$n" == "1" ]; then
      check_bash
    else
      check_param "$line"
    fi
  done
}

check_files1() {
  check_param_comun "ansi2html" "$base/resources/ansi2html.sh" executable
  check_param_comun "send_email.php" "$base/resources/send_email.php" executable
  check_param_comun "curl" "/usr/bin/curl" executable
  check_param_comun "jq" "/usr/bin/jq" executable
}

check_files2() {
  warning=1
  check_param_comun "mplayer" "/usr/bin/mplayer" executable
  check_param_comun "espeak" "/usr/bin/espeak" executable
  warning=0
}

check_access() {
  p=nagios
  v=/usr/local/nagios/bin/nagios
  source $conf
  nagios_pid=$(curl -s -u $username:$password https://$domain/nagios/cgi-bin/statusjson.cgi?query=programstatus | jq ".data[] | .nagios_pid")
  executable=$(ps -hf --pid $nagios_pid -o args | cut -d" " -f1)
  check_param_comun $p "$v" equal "$executable"

}

stc=/usr/local/ncs/lib/super-tiny-colors.bash
[ -x $stc ] || exit 1
. $stc

base=/usr/local/ncs
conf=${base}/ncs.conf

echo -e "${CIN1}\nCONFIGURATION:$S\n"
check_conf1
check_conf2
echo -e "\n${CIN1}NECESSARY FILES:$S\n"
check_files1
echo -e "\n${CIN1}OPTIONAL FILES:$S\n"
check_files2
echo -e "\n${CIN1}VALIDATE ACCESS:$S\n"
check_access

exit
