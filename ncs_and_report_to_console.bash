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
# v1.1.0 - 2018-01-04 - Nelbren <nelbren@gmail.com>
# v1.1.1 - 2018-02-24 - Nelbren <nelbren@gmail.com>
# v1.1.2 - 2018-02-26 - Nelbren <nelbren@gmail.com>
# v1.1.3 - 2018-04-22 - Nelbren <nelbren@gmail.com>
# v1.1.4 - 2018-04-27 - Nelbren <nelbren@gmail.com>
# v1.1.5 - 2018-05-01 - Nelbren <nelbren@gmail.com>
# v1.1.6 - 2018-05-03 - Nelbren <nelbren@gmail.com>
# v1.1.7 - 2018-05-09 - Nelbren <nelbren@gmail.com>
# v1.1.8 - 2018-10-15 - Nelbren <nelbren@gmail.com>
# v1.1.9 - 2018-10-17 - Nelbren <nelbren@gmail.com>
# v1.2.0 - 2018-12-08 - Nelbren <nelbren@gmail.com>
# v1.2.1 - 2019-10-01 - nelbren@npr3s.com
# v1.2.2 - 2024-01-11 - nelbren@npr3s.com
# v1.2.3 - 2024-12-30 - nelbren@npr3s.com
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
  echo -e "       -d|--detail\t\t\tShow the detail of state"
  echo -e "       -min|--minimal\t\t\tShow the Summary State in minimal space"
  echo -e "       -min2|--minimal2\t\t\tShow the Summary State in minimal space without color "
  echo -e "       -n|--nagios\t\t\tShow info for nagios."
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
      -min2|--minimal2) minimal=1; minimal2=1; nagios=1; shift;;
      -n|--nagios) minimal=1; nagios=1; shift;;
      -q|--quiet) silent=1; shift;;
      -is=*|--initialstate=*) state_previous="${i#*=}"; shift;;
      -mc=*|--maxcols=*) max_cols="${i#*=}"; shift;;
      -lang=*|--language=*) lang="${i#*=}"; shift;; 
      -h|--help) use;;
      *) # unknown option
      ;;
    esac
  done

  #echo "state_previous 1 => $state_previous"
  [ -z "$state_previous" ] && state_previous=$CUSTOM_INFO
  #echo "state_previous 2 => $state_previous"
  [ -z "$silent" ] && silent=0
  [ -z "$all" ] && all=0
  [ -z "$sumarystate" ] && sumarystate=0
  [ -z "$detail" ] && detail=0
  [ -z "$minimal" ] && minimal=0
  [ -z "$nagios" ] && nagios=0
  if [ -z "$max_cols" ]; then
    get_cols_and_rows
    max_cols=$columns
  fi
  #echo $state_previous $silent $max_cols $all
}

get_hostname() {
  host=$(hostname --fqdn)
  if [ "$host" == "localhost.localdomain" ]; then
    # vpsdime issue with autogenerated replace of /etc/host
    host0=$(hostname)
    host1=$(grep domain /etc/resolv.conf | cut -d" " -f2)
    host=$host0.$host1
  fi
  echo $host
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
  msg1=$2
  msg2=$3
  before=$4
  hight=$5
  if [ "$INVERT" == "0" ]; then
    case $pstate in
      $SERVICE_OK)       color="$cOK";; #"\e[0m\e[38;5;10m";;
      $SERVICE_WARNING)  color="$cWA";; #"\e[0m\e[38;5;11m";;
      $SERVICE_CRITICAL) color="$cCR";; #\e[0m\e[38;5;9m";;
      $SERVICE_UNKNOWN)  color="$cUN";; #\e[0m\e[38;5;5m";;
      $STATE_INFO)       color="$cIN";; #"\e[1;37m";;
    esac
  else
    case $pstate in
      $SERVICE_OK)       color="$COK";; #"\e[30;48;5;82m";;
      $SERVICE_WARNING)  color="$CWA";; #"\e[30;48;5;11m";;
      $SERVICE_CRITICAL) color="$CCR";; #\e[30;48;5;9m";;
      $SERVICE_UNKNOWN)  color="$CUN";; #"\e[30;48;5;5m";;
      $STATE_INFO)       color="$CIN2";; #\e[7;49;97m";;
    esac
  fi
  if [ "$hight" == "1" ]; then
    if [ "$INVERT" == "0" ]; then
      color2=$nB
    else
      color2=$Ib
    fi
  else
    color2=""
  fi
  if [ "$nagios" == "1" ]; then
    if [ "$pstate" == "$SERVICE_OK" -o "$pstate" == "$STATE_INFO" ]; then
      flag=""
    else
      flag="*"
    fi
    line2="${msg1}${flag}${msg2}${flag}"
  else
    line2=$(echo -en $S)$(echo -en $color2)${msg1}$(echo -en $color)${msg2}$(echo -en $S)
  fi
  if [ "$before" == "1" ]; then
    line=${line2}${line}
  else
    line=${line}${line2}
  fi
  if [ "$pstate" -gt "$bstate" -a "$bstate" != "$SERVICE_CRITICAL" -a \
      "$pstate" != "$SERVICE_UNKNOWN" -a "$pstate" != "$STATE_INFO" ]; then
    bstate=$pstate
  fi
}

color_background() {
  state=$1
  echo -en "$S" #"\e[0m" 
  case $state in
    $STATE_OK) echo -en "$ig";;         # OK 
    $SERVICE_OK) echo -en "$Ig";;       # OK 
    $SERVICE_WARNING) echo -en "$Iy";;  # WARNING
    $SERVICE_UNKNOWN) echo -en "$Im";;  # UNKNOWN
    $SERVICE_CRITICAL) echo -en "$Ir";; # CRITICAL
    #9) echo -en "\e[0m\e[38;5;6m";;
    $CUSTOM_INFO) echo -en "$cIN";; #"\e[1;37m";;
    *) echo -en "color_background $state unknown!"
  esac
}

color_service() {
  [ "$silent" == "1" ] && return
  state=$1
  message=$2
  echo -en "$S" #"\e[0m"
  #echo "($state)"
  case $state in 
    #0) echo -en "\e[0m\e[38;5;10m";; # OK
    #1) echo -en "\e[0m\e[38;5;11m";; # WARNING
    #2) echo -en "\e[0m\e[38;5;9m";;  # CRITICAL
    #3) echo -en "\e[0m\e[38;5;5m";;  # UNKNOWN
    $SERVICE_OK) echo -en "$COK";; #"\e[30;48;5;82m";; # OK 
    $SERVICE_WARNING) echo -en "$CWA";; #"\e[30;48;5;11m";; # WARNING
    $SERVICE_UNKNOWN) echo -en "$CUN";; #"\e[30;48;5;5m";;  # UNKNOWN
    $SERVICE_CRITICAL) echo -en "$CCR";; #"\e[30;48;5;9m";;  # CRITICAL
    #8) echo -en "$cIN";; #"\e[38;5;15m";;
    $CUSTOM_INFO) color_background $state_previous;;
    #9) echo -en "\e[38;1;37m";;
    #9) echo -en "\e[1;37m";;
  esac
  echo -n "$message"
  [ "$state_previous" -ge "108" ] && echo -en "$S$E" #"\e[0m" 
}

color_background_host() {
  state=$1
  echo -en "$S" #\e[0m"
  case $state in
    $SD_HOST_UP) echo -en "$COK";; #"\e[30;48;5;82m";; # UP
    $SD_HOST_DOWN) echo -en "$CCR";; #"\e[30;48;5;9m";;  # DOWN
    $SD_HOST_UNREACHABLE) echo -en "$CUN";; #e[30;48;5;13m";;   # UNREACHABLE
  esac
}

color_host() {
  [ "$silent" == "1" ] && return
  state=$1
  message=$2
  echo -en "$S" #"\e[0m"
  case $state in 
    #0) echo -en "\e[0m\e[38;5;10m";; # UP
    #1) echo -en "\e[0m\e[38;5;9m";;  # DOWN
    #2) echo -en "\e[0m\e[38;5;5m";;  # UNREACHABLE
    $SD_HOST_UP) echo -en "$COK";; #"\e[30;48;5;82m";; # OK 
    $SD_HOST_DOWN) echo -en "$CCR";; #"\e[30;48;5;9m";;  # CRITICAL
    $SD_HOST_UNREACHABLE) echo -en "$CUN";; #"\e[30;48;5;13m";; # UNREACHABLE
    #*) echo -en "\e[38;5;11m";;
  esac
  echo -n "$message"
}

normal() {
  echo -en "$S" #"\e[0m"
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
    if [ "$state_global" != "$STATE_CRITICAL" ] ; then # CRITICAL
      state_global=$state
    fi
  fi
  #echo "CHANGE_STATE -> $state_global"
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
  [ "$state_previous" == "$CUSTOM_INFO" -a "$character" != " " ] && echo -en "\e[1;37m"
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

#test_live_sock() {
#  echo -e "GET status" | $unixcat $live_sock 2>/dev/null 1>&2
#  live_sock_state=$? 
#}

test_access() {
  nagios_pid=$(curl -s -u $username:$password $statusjson?query=programstatus | jq ".data[] | .nagios_pid")
  executable=$(ps -hf --pid $nagios_pid -o args | cut -d" " -f1)
  test_state=1
  [ "$executable" == "/usr/local/nagios/bin/nagios" ] && test_state=0
}

host_state() {
  #state3=$(echo -e "GET hosts\nColumns: state\nFilter: name = $host_name\n" | $unixcat $live_sock 2>/dev/null)
  state3=$(curl -su $username:$password "$statusjson?query=host&hostname=$host_name" | jq '.data[] | .status')
}

stats() {
  statusjson2="$statusjson?query=servicecount&servicestatus"
  if [ "$minimal" == "1" ]; then
    filter="\nFilter: downtimes ="
  else
    filter=""
  fi
  #service_ok=$(echo -e "GET services\nStats: state = 0" | $unixcat $live_sock 2>/dev/null)
  service_ok=$(curl -s -u $username:$password "$statusjson2=ok" | jq "last(.data[].ok)")
  [ -z "$service_ok" ] && service_ok="-1"
  #service_warning=$(echo -e "GET services\nStats: state = 1$filter" | $unixcat $live_sock 2>/dev/null)
  service_warning=$(curl -s -u $username:$password "$statusjson2=warning" | jq "last(.data[].warning)")
  [ -z "$service_warning" ] && service_warning="-1"
  #service_critical=$(echo -e "GET services\nStats: state = 2$filter" | $unixcat $live_sock 2>/dev/null)
  #echo curl -s -u $username:$password "$statusjson2=critical"
  service_critical=$(curl -s -u $username:$password "$statusjson2=critical" | jq "last(.data[].critical)")
  [ -z "$service_critical" ] && service_critical="-1"
  #if [ "$service_critical" == "1" ]; then
  #   statusjson21="$statusjson?query=servicelist&details=true&servicestatus"
  #   nagios_minimal=$(curl -su $username:$password "$statusjson21=critical" | grep '"description": "APP-NAGIOS-minimal"')
     #echo $nagios_minimal
     #if [ -n "$nagios_minimal" ]; then
     #  service_critical=$((service_critical-1))
     #fi
  #fi
  #service_unknown=$(echo -e "GET services\nStats: state = 3$filter" | $unixcat $live_sock 2>/dev/null)
  service_unknown=$(curl -s -u $username:$password "$statusjson2=unknown" | jq "last(.data[].unknown)")
  [ -z "$service_unknown" ] && service_unknown="-1"
  #service_pending=$(curl -s -u $username:$password "$statusjson2=pending" | jq "last(.data[].pending)") # TODO
  statusjson2="$statusjson?query=hostcount&hoststatus"
  #hosts_up=$(echo -e "GET hosts\nStats: state = 0" | $unixcat $live_sock 2>/dev/null)
  hosts_up=$(curl -s -u $username:$password "$statusjson2=up" | jq "last(.data[].up)")
  [ -z "$hosts_up" ] && hosts_up="-1"
  #hosts_down=$(echo -e "GET hosts\nStats: state = 1" | $unixcat $live_sock 2>/dev/null)
  hosts_down=$(curl -s -u $username:$password "$statusjson2=down" | jq "last(.data[].down)")
  #hosts_unreachable=$(curl -s -u $username:$password "$statusjson2=unreachable" | jq "last(.data[].unreachable)") #TODO
  #hosts_pending=$(curl -s -u $username:$password "$statusjson2=pending" | jq "last(.data[].pending)") #TODO
  [ -z "$hosts_down" ] && hosts_down="-1"
}

get_service_with_state() {
  statusjson2="$statusjson?query=servicelist&details=true&servicestatus"
  statusjson3="$statusjson?query=commentlist&details=true&commenttypes=service&servicedescription"
  state=$1
  states=$2
  scheduled=$3

  previous=""

  #if [ "$live_sock_state" != "0" ]; then
  if [ "$test_state" != "0" ]; then
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
  #echo -e "GET services\nColumns: comments_with_info display_name host_comments_with_info host_name host_services_with_info state\n${filtro}" | $unixcat $live_sock 2>&1 | \
  echo curl -su $username:$password "$statusjson2=$states" > /tmp/txt.txt
  echo jq -r 'last(.data[]) | .[] | to_entries[] | [.value] | [ .[].description, .[].host_name, .[].status ] | join(";")' >> /tmp/txt.txt
  curl -su $username:$password "$statusjson2=$states" | jq -r 'last(.data[]) | .[] | to_entries[] | [.value] | [ .[].description, .[].host_name, .[].status ] | join(";")' | \
  while read display_name host_name state2; do
  #while read comments_with_info display_name host_comments_with_info host_name host_services_with_info state2; do
    IFS=$IFSOLD
    #echo $display_name $host_name $state2

    #curl -su $username:$password "$statusjson3=$display_name" | jq 'last(.data[]) | to_entries[] | [.value] | [ .[].host_name, .[].service_description, .[].author, .[].comment_data, .[].comment_type ] | join(";")'
    echo curl -su $username:$password "$statusjson3=$display_name" >> /tmp/txt.txt
    who_and_comment=$(curl -su $username:$password "$statusjson3=$display_name" | jq -r 'last(.data[]) | to_entries[] | [.value] | [ .[].author, .[].comment_data ] | join(";")')
    #echo "$who_and_comment"
    if [ -n "$who_and_comment" ]; then
      who=$(echo "$who_and_comment" | tail -1 | cut -d";" -f1)
      comments_with_info=$(echo "$who_and_comment" | tail -1 | cut -d";" -f2-)
    else
      host_comments_with_info=""
      comments_with_info=""
    fi

    #echo "WHO->$who COMMENTS-> $comments_with_info"
    #exit
    #flapping=$(echo "$comments_with_info" | grep "Nagios Process")
    #echo "FLAPPING $flapping"
    if [ "$who" == "(Nagios Process)" ]; then
      comments_with_info=""
    fi
    include=0
    if [ -n "$scheduled" ]; then
      #echo "SCHEDULED -> $scheduled"
      #echo "CWI -> $comments_with_info"
      #echo "HCWI -> $host_comments_with_info"
      if [ -n "$comments_with_info" -o \
           -n "$host_comments_with_info" ] ; then
        if [ -n "$host_comments_with_info" ]; then
          start=$(expr "$host_comments_with_info" : ".*from \(.*\) to")
          end=$(expr "$host_comments_with_info" : ".*to \(.*\)\.  N")
          who=$(expr "$host_comments_with_info" : ".*|\(.*\)|")
	  # TODO: TEST
        else
          start=$(expr "$comments_with_info" : ".*from \(.*\) to")
          end=$(expr "$comments_with_info" : ".*to \(.*\)\.  N")
          #who=$(expr "$comments_with_info" : ".*|\(.*\)|")
	  #echo "END -> $end"
	  #echo "WHO -> $who"
        fi
	if [ -n "$start" -a -n "$end" ]; then
          include=1
        fi
      fi

      #echo "ANTES $states INCLUDE $include -> $display_name $service_critical $service_warning"
      if [ "$include" == "1" ]; then
        case $states in
	  critical) service_critical=$((service_critical-1));;
	  warning) service_warning=$((service_warning-1));;
	  unknown) service_unknown=$((service_unknown-1));;
        esac
      fi
      #echo "DESPUES $states INCLUDE $include -> $display_name $service_critical $service_warning"

    else
      if [ -z "$comments_with_info" -a \
           -z "$host_comments_with_info" ]; then
	if [ "$service_warning" == "0" -a \
	      "$service_unknown" == "0" -a \
	      "$service_critical" == "1" -a \
	      "$display_name" == "APP-NAGIOS-minimal" ] ; then
	  service_critical=0
	else
          #echo "AQUI -> $display_name $scheduled $service_warning $service_critical $service_unknown"
          include=1
	fi
      fi
    fi
    if [ "$host_name" != "host_name" -a "$include" == "1" ] ; then
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
        color_background $state_previous
        echo -n "[$end|$who]"
      fi
      case $state2 in
	SERVICE_PENDING) state3=$STATE_UNKNOWN;;
	SERVICE_OK) state3=$STATE_OK;;
	SERVICE_WARNING) state3=$STATE_WARNING;;
	SERVICE_UNKNOWN) state3=$STATE_UNKNOWN;;
	SERVICE_CRITICAL) state3=$STATE_CRITICAL;;
     esac
      #echo "CHANGE_STATE $state2 -> $state3"
      [ -z "$scheduled" -a "$include" == "1" ] && change_state $state3
      #echo "$include CS -> $state2 -> $state_global"
    fi
    IFS=";"
  done
  IFS=$IFSOLD
}

get_host_with_state() {
  host_problems=0
  IFSOLD=$IFS; IFS=";"
  echo -e "GET hosts\nColumns: host_comments_with_info host_name state\n${filtro}" | $unixcat $live_sock | \
  while read host_comments_with_info host_name state2; do
    IFS=$IFSOLD
    include=0
    if [ "$state2" != "0" -a \
	 -z "$host_comments_with_info" ] ; then
      host_problems=$((host_problemas + 1))
    fi
  done
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
  stats
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
    [ "$state_previous" == "$CUSTOM_INFO" ] && echo -en "$nG" #"\e[0m\e[38;5;10m"
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
  state=$SERVICE_OK 
  [ $diff -gt 1 ] && state=$SERVICE_CRITICAL
  color_msg $state D $dt
}

check_uptime() {
  color_msg $STATE_INFO U $value
}

check_hosts() {
  line="$line "
  color_msg $STATE_INFO "H" "" 0 1
  value=$hosts_up
  if [ "$value" -gt "0" ]; then
    color_msg $SERVICE_OK "" "U=$value"
    before=1
  fi
  value=$hosts_down
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $SERVICE_CRITICAL "" "D=$value"
  fi
}

check_services() {
  line="$line "
  color_msg $STATE_INFO "S" "" 0 1
  value=$service_ok
  if [ "$value" -gt "0" ]; then
    color_msg $SERVICE_OK "" "O=$value"
    before=1
  fi
  value=$service_warning
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $SERVICE_WARNING "" "W=$value"
    before=1
  fi
  value=$service_unknown
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $SERVICE_UNKNOWN "" "U=$value"
    before=1
  fi
  value=$service_critical
  if [ "$value" -gt "0" ]; then
    [ "$before" == "1" ] && color_msg $STATE_INFO "" "/"
    color_msg $SERVICE_CRITICAL "" "C=$value"
  fi
}

time_usage() {
  fechahora_ahora=$(date +'%Y-%m-%d %H:%M:%S')
  diff=$(diff_segundos "$fechahora_cuando" "$fechahora_ahora")
  diff_humana=$(convertir_de_segundos_a $diff)
  line="$line "
  color_msg $STATE_INFO T "$diff_humana"
}

minimal() {
  #stats
  value=$(date +'%Y%m%d%H%M%S'); check_dt
  trt=$(echo $total_running_time | tr -d "[ ]")
  line="$line "; value="$trt"; check_uptime
  check_hosts; check_services
  if [ "$minimal2" != "1" ]; then
    line=" $line" 
    short=$(echo $myname | cut -d"." -f1)
    color_msg $bstate "" "[NAGIOS:${short}]" 1
  fi
}

summary() {
  color_background $state_previous
  title=$(msg SUMMARY)
  line_single " $title " 0
  title=$(msg SERVICES)
  color_service $CUSTOM_INFO " $title: "
  if [ "$service_ok" != "0" ]; then
    title=$(msg OK)
    color_service $SERVICE_OK "$service_ok $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_warning" != "0" ]; then
    title=$(msg WARNING)
    # AQUI
    color_service $SERVICE_WARNING "$service_warning $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_unknown" != "0" ]; then
    title=$(msg UNKNOWN)
    color_service $SERVICE_UNKNOWN "$service_unknown $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$service_critical" != "0" ]; then
    title=$(msg CRITICAL)
    color_service $SERVICE_CRITICAL "$service_critical $title"
    color_background $state_previous; echo -n " | "
  fi
  [ $max_cols -le 80 ] && echo ""
  title="$(msg HOSTS)"
  color_service $CUSTOM_INFO " $title: "
  if [ "$hosts_ok" != "0" ]; then
    title=$(msg UP)
    color_host $SD_HOST_UP "$hosts_up $title"
    color_background $state_previous; echo -n " | "
  fi
  if [ "$hosts_down" != "0" ]; then
    title=$(msg DOWN)
    color_host $SD_HOST_DOWN "$hosts_down $title"
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
  if [ "$silent" == "1" ]; then
    stats
  else
    if [ "$first" == "0" ]; then
      echo "";
    fi
    if [ "$minimal" == "1" ]; then
      minimal
      time_usage
      if [ "$nagios" == "1" ]; then
        if [ "$minimal2" == "1" ]; then
          case $state_global in
            $SERVICE_OK) msg0="OK";;
            $SERVICE_WARNING) msg0="WARNING";;
            $SERVICE_CRITICAL) msg0="CRITICAL";;
          esac
          echo "${msg0} - $line"
        else
          echo -e "$line | hosts_up=$hosts_up hosts_down=$hosts_down service_ok=$service_ok service_warning=$service_warning service_critical=$service_critical service_unknown=$service_unknown"
        fi
      else
        echo -e "$line$S$E"
      fi
    else
      summary
    fi
  fi
  #echo "SG -> $state_global"
  if [ "$hosts_down" != "0" ]; then
    get_host_with_state
    if [ $host_problems -gt 0 ] ; then
      state2=2
      change_state $state2
    fi
  fi
}

converts() {
  # https://unix.stackexchange.com/questions/683143/how-to-convert-seconds-to-day-hour-minute-seconds
  t=$1
  case $t in
    *.*) tfrac=${t##*.}       # fractional seconds
         t=${t%%.*}           # full seconds
         ;;
      *) tfrac=0              # no decimal point
         ;;
  esac
  d=$((t/60/60/24))
  h=$((t/60/60%24))
  m=$((t/60%60))
  s=$((t%60))
  r=""
  [ $d -gt 0 ] && r="${d}d "
  [ $h -gt 0 ] && r="$r${h}h "
  [ $m -gt 0 ] && r="$r${m}m "
  [ $s -gt 0 ] && r="$r${s}s"
  echo $r
}

process_info() {
  trt_color=0
  program_start=$(curl -su $username:$password "$statusjson?query=programstatus" | jq '.data[] | .program_start')
  unix_start=$(echo $program_start / 1000 | bc)
  unix_now=$(date +%s%3N)
  unix_now=$(echo $unix_now / 1000 | bc)
  unix_diff=$(($unix_now - $unix_start))
  #echo "program_start $program_start"
  #echo "unix_start    $unix_start"
  #echo "unix_now      $unix_now"
  #echo "unix_diff     $unix_diff"
  total_running_time=$(converts $unix_diff)
  #info=$(curl -u ${web_username}:${web_password} http://${host}:${web_port}/nagios/cgi-bin/extinfo.cgi?type=0 2>/dev/null) #; echo $info
  #rawinfo=$(echo "$info" | grep "Total Running Time")
  #total_running_time=$(expr "$rawinfo" : ".*Total Running Time:</TD><TD CLASS='dataVal'>\(.*\)</TD></TR>.*")
  #https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4/en/nagiostats.html
  #total_running_time=$($nagiostats -m --data=PROGRUNTIME)

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
  if [ -z "$trt_num_segs" ]; then
    trt_num_segs=0
  fi
  trt_num_seconds=$(echo "$trt_num_days*60*60*60+$trt_num_hours*60*60+$trt_num_mins*60+$trt_num_segs" | bc)
  #echo $trt_num_seconds
  if [ "$silent" == "0" ]; then
    echo $trt_num_seconds > $trt_file
    chown nagios $trt_file
  fi
  if [ -n "$trt_num_seconds" -a -n "$trt_num_last" ]; then
    if [ "$trt_num_seconds" -gt "$trt_num_last" ]; then
      trt_color=0 
    else
      trt_color=2 
    fi
  fi
  change_state $trt_color
}

cleanup() {
  [ -r $filetemp ] && rm $filetemp
}

problems_or_all() {
  if [ "$all" == "1" ]; then
    get_service_with_state -1 ok+warning+critical+unknown+pending # ANY
  else
    get_service_with_state 2 critical                             # CRITICAL
    get_service_with_state 3 unknown                              # UNKNOWN
    get_service_with_state 1 warning                              # WARNING
  fi
}

problems_scheduled() {
  [ "$silent" == "1" -o "$sumarystate" == "1" -o "$minimal" == "1" ] && return
  if [ "$all" == "1" ]; then
    get_service_with_state -1 ok+warning+critical+unknown+pending scheduled # ANY
  else
    get_service_with_state 2 critical scheduled                             # CRITICAL
    get_service_with_state 3 unknown  scheduled                             # UNKNOWN
    get_service_with_state 1 warning  scheduled                             # WARNING
  fi
}

base=/usr/local/ncs

stc=$base/lib/super-tiny-colors.bash
[ -x $stc ] || exit 1
. $stc

sts=$base/lib/statusdata.bash
[ -x $sts ] || exit 1
. $sts

fechahora_cuando=$(date +'%Y-%m-%d %H:%M:%S')
myself=$(basename $0)
myname=$(get_hostname)
unixcat=/usr/local/bin/unixcat
trt_file=/var/log/nagios/$myself.trt_last.txt
filetemp=$(mktemp /tmp/$myself.XXXXXXXXXX) || { echo "Failed to create temp file"; exit 1; }

conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf
statusjson=https://$domain/nagios/cgi-bin/statusjson.cgi

set +m
shopt -s lastpipe

params "$@"

bstate=$STATE_OK
#bstate=$SERVICE_OK

#test_live_sock
test_access
#if [ "$live_sock_state" == "0" ]; then
if [ "$test_state" == "0" ]; then
  state_global=0
else
  state_global=2
fi

header
#echo "SG 0 -> $state_global"

first=1
problems_or_all
#echo "SG 1 -> $state_global"
middle

first=1
problems_scheduled
#echo "SG 2 -> $state_global"

process_info
footer
#echo "SG 3 -> $state_global"

cleanup
#echo "NAGIOS -> $nagios $SERVICE_OK"

#[ "$nagios" == "1" ] && state_global=$SERVICE_OK
#[ "$nagios" == "1" ] && state_global=$STATE_OK
#echo "SG 4 -> $state_global"
exit $state_global
