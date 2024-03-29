#!/bin/bash
#
# ncs_and_report_to_image.bash
#
# v1.0.0 - 2016-12-12 - Nelbren <nelbren@gmail.com>
# v1.0.1 - 2024-01-11 - Nelbren <nelbren@gmail.com>
# v1.0.2 - 2024-01-15 - Nelbren <nelbren@gmail.com>
#
# Images from:
#
# http://www.flaticon.com/packs/thick-icons
# http://www.flaticon.com/packs/essential-collection
# http://www.flaticon.com/free-icon
# http://www.flaticon.com/packs/weather-set
# http://www.flaticon.com/packs/color-circles-rating-and-validation
# http://www.flaticon.com/packs/flat-lines-circled
#

use() {
  echo "Usage: "
  echo "       $myself [OPTION]..."
  echo ""
  echo "Generate an Nagios Status Image based in the state CRITICAL, WARNING, UNKNOWN or OK."
  echo ""
  echo -e "Where: "
  echo -e "       -s=SYSTEM|--system=SYSTEM\tShow state of SYSTEM."
  echo -e "       -n=NUMBER|--number=NUMBER\tShow this NUMBER."
  echo -e "       -t=DIR|--template=DIR\t\tTemplate DIRECTORY."
  echo -e "       -o=DIR|--output=DIR\t\tOutput to DIRECTORY."
  echo -e "       -q|--quiet\t\t\tGet only the state"
  echo -e "       -h|--help\t\t\tShow this information."
  exit 0
}

params() {
  for i in "$@"; do
    case $i in
      -s=*|--system=*) system="${i#*=}"; shift;;
      -n=*|--number=*) n="${i#*=}"; shift;;
      -t=*|--template=*) template="${i#*=}"; shift;;
      -o=*|--output=*) output="${i#*=}"; shift;;
      -q|--quiet) silent=1; shift;;
      -h|--help) use; exit 1;;
      *) # unknown option
      ;;
    esac
  done

  myname=$(uname -n)
  [ -z "$system" ] && system=$myname
  [ -z "$n" ] && n=1
  [ -z "$silent" ] && silent=0
  
  if [ -z "$template" -o -z "$output" ]; then
    use
    exit 2
  fi
}

get_status_of_nagios() {
  if [ "$system" == "$myname" ]; then
    remote=""
  else
    remote="-s=$system"
  fi
  sudo $ncs_from_local_or_remote $remote -q
  status=$?
  echo "status => $status"
}

set_status_of_image() {
  [ "$status" == "0" ] && status=$SERVICE_OK
  if [ "$status" -lt "$SERVICE_OK" -o "$status" -gt "$SERVICE_UNKNOWN" ]; then
    status=$SERVICE_CRITICAL
  fi
  cp $template/${images[$status]} $dirtmp/status_${system}_1.png
  color_background=${colors_background[$status]}
  color_front=${colors_front[$status]}
}

set_update_of_image() {
  convert -define png:size=80x64 $dirtmp/status_${system}_1.png -thumbnail '32x32' -background '#f2f3f3' -gravity North -extent 80x45 $dirtmp/status_${system}_2.png

  width=$(identify -format %w $dirtmp/status_${system}_2.png)
  convert -background $color_background -fill $color_front -gravity South -size ${width}x12 -font Helvetica-Bold caption:"$datehour" $dirtmp/status_${system}_2.png +swap -gravity south -composite $dirtmp/status_${system}_3.png 

  convert $dirtmp/status_${system}_3.png -fill transparent -stroke $color_background -linewidth 1 -draw "rectangle 0,0 79,44" $dirtmp/status_${system}_4.png

  case $n in
    1) geometry="+5+0";;
    2) geometry="+5+2";;
    *) geometry="+5+0";;
  esac

  convert -background transparent -fill ${colors_front[$SERVICE_WARNING]} -size 20x40 -font Helvetica-Bold caption:"$n" $dirtmp/status_${system}_4.png +swap -gravity West -geometry $geometry -composite $output/status_${system}.png 
}

images() {
  #ls -1 $template
  if cd $template 2>/dev/null; then
    #pwd
    images[$SERVICE_OK]=$(ls -1 ok*)
    images[$SERVICE_WARNING]=$(ls -1 warning*)
    images[$SERVICE_UNKNOWN]=$(ls -1 unknown*)
    images[$SERVICE_CRITICAL]=$(ls -1 critical*)
    #echo ${images[$SERVICE_OK]}
    #echo ${images[$SERVICE_WARNING]}
    #echo ${images[$SERVICE_UNKNOWN]}
    #echo ${images[$SERVICE_CRITICAL]}
  else
    echo "Can't load template images from $template!"
    exit 2
  fi
}

# main()

base=/usr/local/ncs
sts=$base/lib/statusdata.bash
[ -x $sts ] || exit 1
 . $sts

# Constants: 
#declare -a images=(ok-up.png warning-exclamation.png critical-down.png unknown-question.png)
declare -A images
#images[$SERVICE_OK]="ok-up.png"
#images[$SERVICE_WARNING]="warning-exclamation.png"
#images[$SERVICE_UNKNOWN]="unknown-question.png"
#images[$SERVICE_CRITICAL]="critical-down.png"
#declare -a colors_background=('#498022' '#DB952B' '#D80027' '#933EC5')
declare -A colors_background
colors_background[$SERVICE_OK]="#498022"
colors_background[$SERVICE_WARNING]="#DB952B"
colors_background[$SERVICE_UNKNOWN]="#933EC5"
colors_background[$SERVICE_CRITICAL]="#D80027"
#declare -a colors_front=('#ffffff' '#000000' '#ffffff' '#ffffff')
declare -A colors_front
colors_front[$SERVICE_OK]="#ffffff"
colors_front[$SERVICE_WARNING]="#000000"
colors_front[$SERVICE_UNKNOWN]="#ffffff"
colors_front[$SERVICE_CRITICAL]="#ffffff"

datehour=$(date +'%Y-%m-%d %H:%M')
myself=$(basename $0)
myname=$(uname -n)

conf=${base}/ncs.conf
[ -x $conf ] || exit 1
. $conf

dirtmp=/tmp/$myself.$$
if [ ! -d $dirtmp ]; then
  mkdir $dirtmp
fi

params "$@"
dirbase=$output
images

get_status_of_nagios
set_status_of_image
set_update_of_image

if [ -d $dirtmp ]; then
  rm $dirtmp/status_${system}_?.png
  rmdir $dirtmp
fi
