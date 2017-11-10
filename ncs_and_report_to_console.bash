#!/bin/bash
#
# ncs_and_report_to_console.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
# v1.0.1 - 2017-01-10 - Nelbren <nelbren@gmail.com>
# v1.0.2 - 2017-01-11 - Nelbren <nelbren@gmail.com>
# v1.0.3 - 2017-01-12 - Nelbren <nelbren@gmail.com>
# v1.0.4 - 2017-01-19 - Nelbren <nelbren@gmail.com>
# v1.0.5 - 2017-01-25 - Nelbren <nelbren@gmail.com>
# v1.0.6 - 2017-05-02 - Nelbren <nelbren@gmail.com>
# v1.0.7 - 2017-05-28 - Nelbren <nelbren@gmail.com>
# v1.0.8 - 2017-05-31 - Nelbren <nelbren@gmail.com>
# v1.0.9 - 2017-11-10 - Nelbren <nelbren@gmail.com>
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Show an Nagios Report of (all) Hosts/Services (with problems and downtime)."
  echo "By default only shown problems with states CRITICAL, WARNING, and UNKNOWN."
  echo ""
  echo -e "Where: "
  echo -e "       -sa|--showall\t\t\tShow all state of Hosts/Services"
  echo -e "       -ss|--sumarystate\t\tShow only the Summary State"
  echo -e "       -d|--detail\t\tShow the detail of state"
  echo -e "       -min|--minimal\t\t\tShow the Summary State in minimal space"
  echo -e "       -q|--quiet\t\t\tGet only the state"
  echo -e "       -is=STATE|--initialstate=STATE\tSet the previous state"
  echo -e "       -mc=COLS|--maxcols=COLS\t\tSet the max columns of console"
  echo -e "       -lang=LANG|--language=LANG\tSet the language (es=spanish,en=english)"
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
      -sa|--showall) all=1; shift;;
      -ss|--sumarystate) sumarystate=1; shift;;
      -d|--detail) detail=1; shift;;
      -min|--minimal) minimal=1; shift;;
      -q|--quiet) silent=1; shift;;
      -is=*|--initialstate=*) state_previous="${i#*=}"; shift;;
      -mc=*|--maxcols=*) max_cols="${i#*=}"; shift;;
      -lang=*|--language=*) lang="${i#*=}"; shift;; 
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done

  [ -z "$state_previous" ] && state_previous=9
  [ -z "$silent" ] && silent=0
  [ -z "$all" ] && all=0
  [ -z "$sumarystate" ] && sumarystate=0
  [ -z "$detail" ] && detail=0
  [ -z "$minimal" ] && minimal=0
  if [ -z "$max_cols" ]; then
    get_cols_and_rows
    max_cols=$columns
  fi
  #echo $state_previous $silent $max_cols $all
}

convertir_de_segundos_a() {
  declare -a medida=('d' 'h' 'm' 's');
  valor=$1

  # 3600 * 24horas = 86400 segundos contiene 1 dia
  contiene=86400
  dias=$(echo -e "scale=0\n${valor}/$contiene" | bc)
  if [ "$dias" == "0" ]; then
    tiempo=""
    dias_segundos=0
  else
    tiempo="$dias ${medida[0]}"
    dias_segundos=$(echo -e "scale=0\n${dias}*$contiene" | bc)
  fi

  # 60segundos * 60minutos = 3600 segundos contiene 1 hora
  contiene=3600
  horas=$(echo -e "scale=0\n(${valor}-$dias_segundos)/$contiene" | bc)
  if [ "$horas" == "0" ]; then
    horas_segundos=0
  else
    if [ -n "$tiempo" ]; then
      tiempo="${tiempo}${horas}${medida[1]}"
    else
      tiempo="${horas}${medida[1]}"
    fi
    horas_segundos=$(echo -e "scale=0\n${horas}*$contiene" | bc)
  fi

  # 60segundos * 1minuto = 60 segundos contiene 1 minuto
  contiene=60
  minutos=$(echo -e "scale=0\n(${valor}-$dias_segundos-$horas_segundos)/$contiene" | bc)
  if [ "$minutos" == "0" ]; then
    minutos_segundos=0
  else
    if [ -n "$tiempo" ]; then
      tiempo="${tiempo}$minutos${medida[2]}"
    else
      tiempo="${minutos}${medida[2]}"
    fi
    minutos_segundos=$(echo -e "scale=0\n${minutos}*$contiene" | bc)
  fi

  segundos=$(echo -e "scale=0\n${valor}-$dias_segundos-$horas_segundos-$minutos_segundos" | bc)
  if [ "$segundos" == "0" ]; then
    segundos_segundos=0
    tiempo="${segundos}${medida[3]}"
  else
    if [ -n "$tiempo" ]; then
      tiempo="${tiempo}${segundos}${medida[3]}"
    else
      tiempo="${segundos}${medida[3]}"
    fi
  fi

  echo $tiempo
}

diff_segundos() {
  tiempo_pasado=$1
  tiempo_actual=$2
  echo $(( $(date --date="$tiempo_actual" +%s) - $(date --date="$tiempo_pasado" +%s) ))
}

color_msg() {
  pstate=$1
  message1=$2
  message2=$3
  before=$4
  if [ "$INVERT" == "0" ]; then
    case $pstate in
      $STATE_OK)       color="\e[0m\e[38;5;10m";;
      $STATE_WARNING)  color="\e[0m\e[38;5;11m";;
      $STATE_CRITICAL) color="\e[0m\e[38;5;9m";;
      $STATE_UNKNOWN)  color="\e[0m\e[38;5;5m";;
      $STATE_INFO)     color="\e[1;37m";;
    esac
  else
    case $pstate in
      $STATE_OK)       color="\e[30;48;5;82m";;
      $STATE_WARNING)  color="\e[30;48;5;11m";;
      $STATE_CRITICAL) color="\e[30;48;5;9m";;
      $STATE_UNKNOWN)  color="\e[30;48;5;5m";;
      $STATE_INFO)     color="\e[7;49;97m";;
    esac
  fi
  reset="\e[0m"
  line2=$(echo -en $reset)${message1}$(echo -en $color)${message2}$(echo -en $reset)
  if [ "$before" == "1" ]; then
    line=${line2}${line}
  else
    line=${line}${line2}
  fi
  if [ "$pstate" -gt "$bstate" -a "$bstate" != "$STATE_CRITICAL" -a "$pstate" != "$STATE_INFO" ]; then
    bstate=$pstate
  fi
}

color_background() {
  state=$1
  echo -en "\e[0m" 
  case $state in
    0) echo -en "\e[30;48;5;82m";; # OK 
    1) echo -en "\e[30;48;5;11m";; # WARNING
    2) echo -en "\e[30;48;5;9m";;  # CRITICAL
    3) echo -en "\e[30;48;5;13m";; # UNKNOWN
    #9) echo -en "\e[0m\e[38;5;6m";;
    9) echo -en "\e[1;37m";;
  esac
}

color_service() {
  [ "$silent" == "1" ] && return
  state=$1
  message=$2
  echo -en "\e[0m"
  case $state in 
    #0) echo -en "\e[0m\e[38;5;10m";; # OK
    #1) echo -en "\e[0m\e[38;5;11m";; # WARNING
    #2) echo -en "\e[0m\e[38;5;9m";;  # CRITICAL
    #3) echo -en "\e[0m\e[38;5;5m";;  # UNKNOWN
    0) echo -en "\e[30;48;5;82m";; # OK 
    1) echo -en "\e[30;48;5;11m";; # WARNING
    2) echo -en "\e[30;48;5;9m";;  # CRITICAL
    3) echo -en "\e[30;48;5;5m";;  # UNKNOWN
    8) echo -en "\e[38;5;15m";;
    9) color_background $state_previous;;
    #9) echo -en "\e[38;1;37m";;
    #9) echo -en "\e[1;37m";;
  esac
  echo -n "$message"
  echo -en "\e[0m" 
}

color_background_host() {
  state=$1
  echo -en "\e[0m"
  case $state in
    0) echo -en "\e[30;48;5;82m";; # OK 
    1) echo -en "\e[30;48;5;9m";;  # CRITICAL
    2) echo -en "\e[30;48;5;13m";; # UNREACHABLE
  esac
}

color_host() {
  [ "$silent" == "1" ] && return
  state=$1
  message=$2
  echo -en "\e[0m"
  case $state in 
    #0) echo -en "\e[0m\e[38;5;10m";; # UP
    #1) echo -en "\e[0m\e[38;5;9m";;  # DOWN
    #2) echo -en "\e[0m\e[38;5;5m";;  # UNREACHABLE
    0) echo -en "\e[30;48;5;82m";; # OK 
    1) echo -en "\e[30;48;5;9m";;  # CRITICAL
    2) echo -en "\e[30;48;5;13m";; # UNREACHABLE
    #*) echo -en "\e[38;5;11m";;
  esac
  echo -n "$message"
}

normal() {
  echo -en "\e[0m"
}

fix_state() {
  state=$1
  #echo "[STATE=$state]"
  state=$(expr "$state" : "^\([0-9]*\)$")
  if [ -z "$state" ]; then
    state=3
  fi
}

change_state() {
  state=$1
  if [ $state -gt $state_global ] ; then
    if [ "$state_global" != "2" ] ; then
      state_global=$state
    fi
  fi
}

repeat() {
  character=$1
  message="$2"
  info=$3
  length=${#message}
  spaces=$((max_cols-length))
  space1=$((spaces/2))
  space2=$((spaces-space1))

  s1=$(printf "%-${space1}s" $character)
  s2=$(printf "%-${space2}s" $character)
  echo -n "${s1// /$character}"
  [ "$state_previous" == "9" -a "$character" != " " ] && echo -en "\e[1;37m"
  echo -n "$message"
  color_background $state_previous
  echo "${s2// /$character}"
}

line_double() {
  repeat "=" "$1" $2
}

line_single() {
  repeat "-" "$1" $2
}

line_space() {
  repeat " " "$1" $2
}

test_live_sock() {
  echo -e "GET status" | $unixcat $live_sock 2>/dev/null 1>&2
  live_sock_state=$? 
}

host_state() {
  state3=$(echo -e "GET hosts\nColumns: state\nFilter: name = $host_name\n" | $unixcat $live_sock 2>/dev/null)
}

stats() {
  service_ok=$(echo -e "GET services\nStats: state = 0" | $unixcat $live_sock 2>/dev/null)
  [ -z "$service_ok" ] && service_ok="-1"
  service_warning=$(echo -e "GET services\nStats: state = 1" | $unixcat $live_sock 2>/dev/null)
  [ -z "$service_warning" ] && service_warning="-1"
  service_critical=$(echo -e "GET services\nStats: state = 2" | $unixcat $live_sock 2>/dev/null)
  [ -z "$service_critical" ] && service_critical="-1"
  service_unknown=$(echo -e "GET services\nStats: state = 3" | $unixcat $live_sock 2>/dev/null)
  [ -z "$service_unknown" ] && service_unknown="-1"
  hosts_up=$(echo -e "GET hosts\nStats: state = 0" | $unixcat $live_sock 2>/dev/null)
  [ -z "$hosts_up" ] && hosts_up="-1"
  hosts_down=$(echo -e "GET hosts\nStats: state = 1" | $unixcat $live_sock 2>/dev/null)
  [ -z "$hosts_down" ] && hosts_down="-1"
}

get_service_with_state() {
  state=$1
  scheduled=$2
  previous=""

  if [ "$live_sock_state" != "0" ]; then
    first=0
    color_service $state " I can not get state=$state,"
    return
  fi

  if [ "$state" == "-1" ]; then
    filtro=""
  else
    filtro="Filter: state = $state"
  fi

  IFSOLD=$IFS; IFS=";"
  echo -e "GET services\nColumns: comments_with_info display_name host_comments_with_info host_name host_services_with_info state\n${filtro}" | $unixcat $live_sock 2>&1 | \
  while read comments_with_info display_name host_comments_with_info host_name host_services_with_info state2; do
    IFS=$IFSOLD
    flapping=$(echo "$comments_with_info" | grep "Nagios Process")
    if [ -n "$flapping" ]; then
      comments_with_info=""
    fi
    include=0
    if [ -n "$scheduled" ]; then
      if [ -n "$comments_with_info" -o \
           -n "$host_comments_with_info" ] ; then
        if [ -n "$host_comments_with_info" ]; then
          start=$(expr "$host_comments_with_info" : ".*from \(.*\) to")
          end=$(expr "$host_comments_with_info" : ".*to \(.*\)\.  N")
          who=$(expr "$host_comments_with_info" : ".*|\(.*\)|")
        else
          start=$(expr "$comments_with_info" : ".*from \(.*\) to")
          end=$(expr "$comments_with_info" : ".*to \(.*\)\.  N")
          who=$(expr "$comments_with_info" : ".*|\(.*\)|")
        fi
	if [ -n "$start" -a -n "$end" ]; then
          include=1
        fi
      fi
    else
      if [ -z "$comments_with_info" -a \
           -z "$host_comments_with_info" ] ; then
        include=1
      fi
    fi
    if [ "$host_name" != "host_name" -a  "$include" == "1" ] ; then
      if [ "$previous" != "$host_name" ]; then
        if [ "$first" == "1" ]; then
          first=0
        else
          [ "$silent" == "0" -a "$sumarystate" == "0" -a "$minimal" == "0" ] && echo ""
        fi
        host_state 
        if [ "$silent" == "0" -a "$sumarystate" == "0" -a "$minimal" == "0" ]; then
          color_background_host $state3
          echo -n " ${host_name}: "
          color_background $state_previous
          #color_service $state2 "$display_name($state2)"
          color_service $state2 "$display_name"
	  #if [ "$detail" == "1" ]; then
	    #echo "-----"
	    #echo "$host_services_with_info"
	    #echo "====="
	  #fi
        fi
        previous=$host_name
      else
        if [ "$silent" == "0" -a "$sumarystate" == "0" -a "$minimal" == "0" ]; then
          #color_service $state2 ",$display_name($state2)"
          color_service $state2 ",$display_name"
        fi
      fi
      if [ -n "$scheduled" -a "$silent" == "0" ]; then
        echo -n "[$end|$who]"
      fi
      [ -z "$scheduled" ] && change_state $state2
    fi
    IFS=";"
  done
  IFS=$IFSOLD
}

msg() {
  num=$1
  if [ "$lang" == "es" ]; then
    case $num in
      ALL) t="REPORTE NAGIOS $name DE TODOS LOS EQUIPOS/SERVICIOS";;
      REPORT_PROBLEM) t="REPORTE NAGIOS $name DE EQUIPOS/SERVICIOS CON PROBLEMAS";;
      MESSAGE_OK) t="Estoy bien operacionalmente, y todos mis circuitos funcionan perfectamente.";;
      REPORT_DOWNTIME) t="REPORTE DE NAGIOS DE EQUIPOS/SERVICIOS CON PROBLEMAS CON TIEMPO-INACTIVIDAD.";;
      SUMMARY) t="RESUMEN DE ESTADO";;
      SERVICES) t="SERVICIOS";;
      OK) t="BIEN";;
      WARNING) t="PRECAUCION";;
      UNKNOWN) t="DESCONOCIDO";;
      CRITICAL) t="CRITICO";;
      HOSTS) t="EQUIPOS";;
      UP) t="ARRIBA";;
      DOWN) t="ABAJO";;
      RUNNING_TIME) t="TIEMPO EJECUCION";;
    esac
  else
    case $num in
      ALL) t="NAGIOS REPORT $name OF ALL HOSTS/SERVICES";;
      REPORT_PROBLEM) t="NAGIOS REPORT $name OF HOSTS/SERVICES WITH PROBLEMS";;
      MESSAGE_OK) t="I'm completely operational, and all my circuits are functioning perfectly.";;
      REPORT_DOWNTIME) t="NAGIOS REPORT OF HOSTS/SERVICES WITH PROBLEMS BUT WITH DOWNTIME.";;
      SUMMARY) t="SUMMARY OF STATE";;
      SERVICES) t="SERVICES";;
      OK) t="OK";;
      WARNING) t="WARNING";;
      UNKNOWN) t="UNKNOWN";;
      CRITICAL) t="CRITICAL";;
      HOSTS) t="HOSTS";;
      UP) t="UP";;
      DOWN) t="DOWN";;
      RUNNING_TIME) t="RUNNING TIME";;
    esac
  fi
  echo "$t"
}

header() {
  [ "$silent" == "1" -o "$sumarystate" == "1" -o "$minimal" == "1" ] && return
  color_background $state_previous
  datehour=$(date +'%Y-%m-%d %H:%M:%S')
  if [ "$all" = "1" ]; then
    title=$(msg ALL)
  else
    title=$(msg REPORT_PROBLEM)
  fi
  title=" $title @ $datehour "
  line_double "$title" 0
}

middle() {
  [ "$silent" == "1" -o "$sumarystate" == "1" -o "$minimal" == "1" ] && return
  if [ "$first" == "1" ]; then
    title=$(msg MESSAGE_OK)
    [ "$state_previous" == "9" ] && echo -en "\e[0m\e[38;5;10m"
    line_space "$title" 1
  else
    echo "";
  fi
  title=$(msg REPORT_DOWNTIME)
  color_background $state_previous
  line_single " $title " 0
}


check_dt() {
  dt=$value
  dtn=$(date +'%Y%m%d%H%M%S')
  diff=$((dtn-dt))
  state=$STATE_OK 
  [ $diff -gt 1 ] && state=$STATE_CRITICAL
  color_msg $state DT: $dt
}

check_uptime() {
  color_msg $STATE_INFO UPTIME: $value
}

check_hosts() {
  line="$line HOSTS:"
  value=$hosts_up
  if [ "$value" -gt "0" ]; then
    color_msg $STATE_OK "" "UP=$value"
    before=1
  fi
  value=$hosts_down
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $STATE_CRITICAL "" "DOWN=$value"
  fi
}

check_services() {
  line="${line} SERVICES:"
  value=$service_ok
  if [ "$value" -gt "0" ]; then
    color_msg $STATE_OK "" "OK=$value"
    before=1
  fi
  value=$service_warning
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $STATE_WARNING "" "WARN=$value"
    before=1
  fi
  value=$service_unknown
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $STATE_UNKNOWN "" "UNKN=$value"
    before=1
  fi
  value=$service_critical
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $STATE_CRITICAL "" "CRIT=$value"
  fi
}

time_usage() {
  fechahora_ahora=$(date +'%Y-%m-%d %H:%M:%S')
  diff=$(diff_segundos "$fechahora_cuando" "$fechahora_ahora")
  diff_humana=$(convertir_de_segundos_a $diff)
  line="$line "
  color_msg $STATE_INFO TIME: "$diff_humana"
}

minimal() {
  stats
  value=$(date +'%Y%m%d%H%M%S'); check_dt
  trt=$(echo $total_running_time | tr -d "[ ]")
  line="$line "; value="$trt"; check_uptime
  check_hosts; check_services
  line=" $line" 
  color_msg $bstate "" "[NAGIOS:${myname}]" 1
}

summary() {
  color_background $state_previous
  title=$(msg SUMMARY)
  line_single " $title " 0
  stats
  title=$(msg SERVICES)
  color_service 9 " $title: "
  if [ "$service_ok" != "0" ]; then
    title=$(msg OK)
    color_service 0 "$service_ok $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_warning" != "0" ]; then
    title=$(msg WARNING)
    color_service 1 "$service_warning $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_unknown" != "0" ]; then
    title=$(msg UNKNOWN)
    color_service 3 "$service_unknown $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_critical" != "0" ]; then
    title=$(msg CRITICAL)
    color_service 2 "$service_critical $title"
    color_background $state_previous; echo -n " | "
  fi
  [ $max_cols -le 80 ] && echo ""
  title="$(msg HOSTS)"
  color_service 9 " $title: "
  if [ "$hosts_ok" != "0" ]; then
    title=$(msg UP)
    color_host 0 "$hosts_up $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$hosts_down" != "0" ]; then
    title=$(msg DOWN)
    color_host 1 "$hosts_down $title"
    color_background $state_previous; echo -n " | "
  fi
  title=$(msg RUNNING_TIME)
  color_service $trt_color "$title: $total_running_time"
  #echo " ($trt_num_seconds > $trt_num_last)"
  color_background $state_previous
  if [ "$sumarystate" == "1" ]; then
    echo ""; line_single "" 0
  else
    echo ""; line_double "" 0
  fi
}

footer() {
  [ "$silent" == "1" ] && return
  if [ "$first" == "0" ]; then
    echo "";
  fi
  if [ "$minimal" == "1" ]; then
    minimal
    time_usage
    echo -e "$line"
  else
    summary
  fi
}

process_info() {
  #info=$(curl -u ${web_username}:${web_password} http://${host}:${web_port}/nagios/cgi-bin/extinfo.cgi?type=0 2>/dev/null) #; echo $info
  #rawinfo=$(echo "$info" | grep "Total Running Time")
  #total_running_time=$(expr "$rawinfo" : ".*Total Running Time:</TD><TD CLASS='dataVal'>\(.*\)</TD></TR>.*")
  #https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/nagiostats.html
  total_running_time=$($nagiostats -m --data=PROGRUNTIME)

  if [ -z "$total_running_time" ]; then
    trt_color=2 
    change_state $trt_color
    total_running_time="-1"
    return
  fi
  if [ -r "$trt_file" ]; then
    trt_num_last=$(cat $trt_file)
  else
    trt_num_last=0
  fi
  trt_num=$(echo "$total_running_time" | tr -d "[a-z]")
  trt_num_days=$(echo $trt_num | cut -d" " -f1)
  trt_num_hours=$(echo $trt_num | cut -d" " -f2)
  trt_num_mins=$(echo $trt_num | cut -d" " -f3)
  trt_num_segs=$(echo $trt_num | cut -d" " -f4)
  trt_num_seconds=$(echo "$trt_num_days*60*60*60+$trt_num_hours*60*60+$trt_num_mins*60+$trt_num_segs" | bc)
  if [ "$silent" == "0" ]; then
    echo $trt_num_seconds > $trt_file
    chown nagios $trt_file
  fi
  if [ "$trt_num_seconds" -gt "$trt_num_last" ]; then
    trt_color=0 
  else
    trt_color=2 
  fi
  change_state $trt_color
}

cleanup() {
  [ -r $filetemp ] && rm $filetemp
}

problems_or_all() {
  if [ "$all" == "1" ]; then
    get_service_with_state -1 # ANY
  else
    get_service_with_state 2 # CRITICAL
    get_service_with_state 3 # UNKNOWN
    get_service_with_state 1 # WARNING
  fi
}

problems_scheduled() {
  [ "$silent" == "1" -o "$sumarystate" == "1" -o "$minimal" == "1" ] && return
  if [ "$all" == "1" ]; then
    get_service_with_state -1 scheduled # ANY
  else
    get_service_with_state 2 scheduled # CRITICAL
    get_service_with_state 3 scheduled # UNKNOWN
    get_service_with_state 1 scheduled # WARNING
  fi
}

fechahora_cuando=$(date +'%Y-%m-%d %H:%M:%S')
myself=$(basename $0)
myname=$(uname -n)
unixcat=/usr/local/bin/unixcat
trt_file=/var/log/nagios/$myself.trt_last.txt
filetemp=$(mktemp /tmp/$myself.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }

base=/usr/local/ncs
conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf

set +m
shopt -s lastpipe

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4
STATE_INFO=5
INVERT=1

params "$@"

bstate=$STATE_OK

test_live_sock
if [ "$live_sock_state" == "0" ]; then
  state_global=0
else
  state_global=2
fi

header

first=1
problems_or_all

middle

first=1
problems_scheduled

process_info
footer

cleanup

exit $state_global
