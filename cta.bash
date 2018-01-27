#! /bin/bash

#-------------------------------------------------------------------------------
# cta.bash
# Nic Hite
# 09/22/16
#
# A simple, lightweight CTA tracker written in Bash.
#
# Basically just takes your arguments, does a quick lookup for stop and / or
# station codes, makes a curl request to the CTA API, parses the XML, and
# displays the results.
#-------------------------------------------------------------------------------

# --- Constants ---

# Codes for each field in each arrival.
readonly STATION_ID=0
readonly STOP_ID=1
readonly STATION_NAME=2
readonly STOP_DESCRIPTION=3
readonly RUN=4
readonly ROUTE=5
readonly DESTINATION_STOP=6
readonly DESTINATION_NAME=7
readonly INBOUND_IND=8
readonly PREDICTION_TS=9
readonly ARRIVAL_TS=10
readonly IS_APPROACHING=11
readonly IS_SCHEDULED=12
readonly IS_DELAYED=13
readonly FAULT_IND=14
readonly LATITUDE=15
readonly LONGITUDE=16
readonly CARDINAL_DIRECTION_DEGREE=17
readonly NUM_FIELDS=18

# Train line indices to smartly insert the correct printf color
readonly Red=0
readonly Blue=1
readonly Brn=2
readonly G=3
readonly Org=4
readonly P=5
readonly Pink=6
readonly Y=7
readonly END=8

# Map user-friendly route colors to the ones actually used by the API
readonly blue=Blue
readonly red=Red
readonly green=G
readonly brown=Brn
readonly orange=Org
readonly purple=P
readonly pink=Pink
readonly yellow=Y

# A list of the train station information to be used. Rather than keep this
# in a separate file and introduce a dependency, I'll just throw this in here
# so users can move this script anywhere they want without any problems.
#
# You'll notice there's some geolocation stuff in here too. Haven't done too
# much with that yet. But soon!
stations_txt="40830,18th,pink,41.857908,-87.669147,1
41120,35th-bronzeville-iit,green,41.831677,-87.625826,1
40120,35th/archer,orange,41.829353,-87.680622,1
41270,43rd,green,41.816462,-87.619021,1
41080,47th,green,41.809209,-87.618826,1
41230,47th,red,41.810318,-87.63094,1
40130,51st,green,41.80209,-87.618487,1
40580,54th/cermak,pink,41.85177331,-87.75669201,1
40910,63rd,red,41.780536,-87.630952,1
40990,69th,red,41.768367,-87.625724,1
40240,79th,red,41.750419,-87.625112,1
41430,87th,red,41.735372,-87.624717,1
40450,95th/dan ryan,red,41.722377,-87.624342,1
40680,adams/wabash,brown,41.879507,-87.626037,0
40680,adams/wabash,green,41.879507,-87.626037,0
40680,adams/wabash,orange,41.879507,-87.626037,0
40680,adams/wabash,purple,41.879507,-87.626037,0
40680,adams/wabash,pink,41.879507,-87.626037,0
41240,addison,blue,41.9466037164,-87.7184584172,0
41420,addison,red,41.947316173,-87.6536241013,1
41440,addison,brown,41.947028,-87.674642,1
41200,argyle,red,41.9733220506,-87.6585279483,0
40660,armitage,brown,41.918217,-87.652644,1
40660,armitage,purple,41.918217,-87.652644,1
40170,ashland,green,41.885269,-87.666969,1
40170,ashland,pink,41.885269,-87.666969,1
41060,ashland,orange,41.839234,-87.665317,1
40290,ashland/63rd,green,41.77886,-87.663766,1
40010,austin,blue,41.870851,-87.776812,0
41260,austin,green,41.887293,-87.774135,0
40060,belmont,blue,41.9391107041,-87.71225212,0
41320,belmont,red,41.939751,-87.65338,1
41320,belmont,brown,41.939751,-87.65338,1
41320,belmont,purple,41.939751,-87.65338,1
40340,berwyn,red,41.977984,-87.658668,0
41380,bryn mawr,red,41.983504,-87.65884,0
40440,california,pink,41.854109,-87.694774,1
40570,california,blue,41.9221583097,-87.6972439537,0
41360,california,green,41.88422,-87.696234,1
40280,central,green,41.887389,-87.76565,1
41250,central,purple,42.063987,-87.685617,0
40780,central park,pink,41.853839,-87.714842,1
41000,cermak-chinatown,red,41.853206,-87.630968,1
41690,cermak-mccormick place,green,41.853115,-87.626402,1
40710,chicago,brown,41.89681,-87.635924,1
40710,chicago,purple,41.89681,-87.635924,1
41410,chicago,blue,41.896075,-87.655214,0
41450,chicago,red,41.896671,-87.628176,1
40420,cicero,pink,41.85182,-87.745336,1
40480,cicero,green,41.886519,-87.744698,1
40970,cicero,blue,41.871574,-87.745154,0
40630,clark/division,red,41.90392,-87.631412,1
40380,clark/lake,blue,41.885737,-87.630886,1
40380,clark/lake,brown,41.885737,-87.630886,1
40380,clark/lake,green,41.885737,-87.630886,1
40380,clark/lake,orange,41.885737,-87.630886,1
40380,clark/lake,purple,41.885737,-87.630886,1
40380,clark/lake,pink,41.885737,-87.630886,1
40430,clinton,blue,41.875539,-87.640984,0
41160,clinton,green,41.885678,-87.641782,1
41160,clinton,pink,41.885678,-87.641782,1
41670,conservatory-central park drive,green,41.884904,-87.716523,1
40720,cottage grove,green,41.780309,-87.605857,1
40230,cumberland,blue,41.984246,-87.838028,1
40090,damen,brown,41.966286,-87.678639,1
40210,damen,pink,41.854517,-87.675975,1
40590,damen,blue,41.9098452343,-87.6775400139,0
40050,davis,purple,42.04771,-87.683543,1
40690,dempster,purple,42.041655,-87.681602,0
40140,dempster-skokie,yellow,42.038951,-87.751919,1
40530,diversey,brown,41.932732,-87.653131,1
40530,diversey,purple,41.932732,-87.653131,1
40320,division,blue,41.903355,-87.666496,0
40390,forest park,blue,41.874257,-87.817318,1
40520,foster,purple,42.05416,-87.68356,0
40870,francisco,brown,41.966046,-87.701644,1
41220,fullerton,red,41.9253003719,-87.6528684398,1
41220,fullerton,brown,41.9253003719,-87.6528684398,1
41220,fullerton,purple,41.9253003719,-87.6528684398,1
40510,garfield,green,41.795172,-87.618327,1
41170,garfield,red,41.79542,-87.631157,1
40330,grand,red,41.891665,-87.628021,0
40490,grand,blue,41.891189,-87.647578,0
40760,granville,red,41.9944830093,-87.6591866269,1
40940,halsted,green,41.778943,-87.644244,1
41130,halsted,orange,41.84678,-87.648088,1
40980,harlem (forest park branch),blue,41.87349,-87.806961,0
40750,harlem (o'hare branch),blue,41.98227,-87.8089,1
40020,harlem/lake,green,41.886848,-87.803176,1
40850,harold washington library-state/van buren,brown,41.876862,-87.628196,1
40850,harold washington library-state/van buren,orange,41.876862,-87.628196,1
40850,harold washington library-state/van buren,purple,41.876862,-87.628196,1
40850,harold washington library-state/van buren,pink,41.876862,-87.628196,1
41490,harrison,red,41.874039,-87.627479,0
40900,howard,red,42.019063,-87.672892,1
40900,howard,purple,42.019063,-87.672892,1
40900,howard,yellow,42.019063,-87.672892,1
40810,illinois medical district,blue,41.875706,-87.673932,1
40300,indiana,green,41.821732,-87.621371,1
40550,irving park,blue,41.952925,-87.729229,0
41460,irving park,brown,41.954521,-87.674868,1
40070,jackson,blue,41.878183,-87.629296,1
40560,jackson,red,41.878153,-87.627596,1
41190,jarvis,red,42.0160204165,-87.6692571266,0
41280,jefferson park,blue,41.9702338623,-87.7615940115,1
41040,kedzie,pink,41.853964,-87.705408,1
41070,kedzie,green,41.884321,-87.706155,1
41150,kedzie,orange,41.804236,-87.704406,1
41180,kedzie,brown,41.965996,-87.708821,1
40250,kedzie-homan,blue,41.874341,-87.70604,1
41290,kimball,brown,41.967901,-87.713065,1
41140,king drive,green,41.78013,-87.615546,1
40600,kostner,pink,41.853751,-87.733258,1
41660,lake,red,41.884809,-87.627813,1
40700,laramie,green,41.887163,-87.754986,1
41340,lasalle,pink,41.875568,-87.631722,0
41340,lasalle,orange,41.875568,-87.631722,0
41340,lasalle,purple,41.875568,-87.631722,0
40160,lasalle/van buren,orange,41.8768,-87.631739,0
40160,lasalle/van buren,pink,41.8768,-87.631739,0
40160,lasalle/van buren,purple,41.8768,-87.631739,0
40770,lawrence,red,41.9689762882,-87.6584869372,0
41050,linden,purple,42.073153,-87.69073,1
41020,logan square,blue,41.9295342259,-87.7076881549,1
41300,loyola,red,42.001073,-87.661061,1
40270,main,purple,42.033456,-87.679538,0
40460,merchandise mart,brown,41.888969,-87.633924,1
40460,merchandise mart,purple,41.888969,-87.633924,1
40930,midway,orange,41.78661,-87.737875,1
40790,monroe,blue,41.880703,-87.629378,0
41090,monroe,red,41.880745,-87.627696,0
41330,montrose,blue,41.9609010454,-87.7429034362,0
41500,montrose,brown,41.961756,-87.675047,1
41510,morgan,green,41.88557676,-87.65212993,1
41510,morgan,pink,41.88557676,-87.65212993,1
40100,morse,red,42.008362,-87.665909,0
40650,north/clybourn,red,41.910655,-87.649177,0
40400,noyes,purple,42.058282,-87.683337,0
40890,o'hare,blue,41.97766526,-87.90422307,1
40180,oak park,blue,41.872108,-87.791602,0
41350,oak park,green,41.886988,-87.793783,0
41680,oakton-skokie,yellow,42.02624348,-87.74722084,1
41310,paulina,brown,41.943623,-87.670907,1
41030,polk,pink,41.871551,-87.66953,1
40030,pulaski,green,41.885412,-87.725404,1
40150,pulaski,pink,41.853732,-87.724311,1
40920,pulaski,blue,41.873797,-87.725663,0
40960,pulaski,orange,41.799756,-87.724493,1
40040,quincy/wells,pink,41.878723,-87.63374,0
40040,quincy/wells,orange,41.878723,-87.63374,0
40040,quincy/wells,purple,41.878723,-87.63374,0
40470,racine,blue,41.87592,-87.659458,0
40200,randolph/wabash,brown,41.884431,-87.626149,0
40200,randolph/wabash,green,41.884431,-87.626149,0
40610,ridgeland,green,41.887159,-87.783661,0
41010,rockwell,brown,41.966115,-87.6941,1
41400,roosevelt,red,41.8673785311,-87.6270314058,1
41400,roosevelt,green,41.8673785311,-87.6270314058,1
41400,roosevelt,orange,41.8673785311,-87.6270314058,1
40820,rosemont,blue,41.983507,-87.859388,1
40800,sedgwick,brown,41.910409,-87.639302,1
40800,sedgwick,purple,41.910409,-87.639302,1
40080,sheridan,red,41.9539048386,-87.6546614127,0
40840,south boulevard,purple,42.027612,-87.678329,0
40360,southport,brown,41.943744,-87.663619,1
40190,sox-35th,red,41.831191,-87.630636,1
40260,state/lake (loop 'l'),brown,41.88574,-87.627835,0
40260,state/lake (loop 'l'),green,41.88574,-87.627835,0
40260,state/lake (loop 'l'),orange,41.88574,-87.627835,0
40260,state/lake (loop 'l'),purple,41.88574,-87.627835,0
40260,state/lake (loop 'l'),pink,41.88574,-87.627835,0
40880,thorndale,red,41.9900990857,-87.6590684978,0
40350,uic-halsted,blue,41.875474,-87.649707,1
40370,washington,blue,41.883164,-87.62944,0
40730,washington/wells,brown,41.882695,-87.63378,1
40730,washington/wells,orange,41.882695,-87.63378,1
40730,washington/wells,purple,41.882695,-87.63378,1
40730,washington/wells,pink,41.882695,-87.63378,1
41210,wellington,brown,41.936033,-87.653266,1
41210,wellington,purple,41.936033,-87.653266,1
40310,western,orange,41.804546,-87.684019,1
40740,western,pink,41.854225,-87.685129,1
41480,western,brown,41.966163,-87.688502,1
40220,western (forest park branch),blue,41.875478,-87.688436,0
40670,western (o'hare branch),blue,41.916157,-87.687364,1
40540,wilson,red,41.965481568,-87.6579258145,0"

# List of colors to display line specific or error information.
# (Accessed with the same index mapping as train lines)
declare -ar colors=(
  $'\e[38;05;196m'
  $'\e[38;05;27m'
  $'\e[38;05;94m'
  $'\e[38;05;46m'
  $'\e[38;05;202m'
  $'\e[38;05;55m'
  $'\e[38;05;177m'
  $'\e[38;05;226m'
  $'\e[0m'
)

# Usage statement for later
readonly usage="Usage: $(basename $0) -s station_name [-r train_route] | -l train_route

Lists train arrivals for a given stop. If no train line is given, all relevant
lines will be listed. Alternatively, passing in the -l flag will list all
stations for a given route.

  -r: Train route to check (e.g. 'Blue', 'Red' OR shortest unambiguous identifier ('r', 'br'))
  -s: Station name (e.g. 'Clark/Lake', 'Fullteron')
  -l: List stops for a route"

# --- Functions ---

# print_usage: prints a formatted usage statement for the program
print_usage () {
  printf "%80s\n" "$usage"
}
# read_dom: function to (somewhat hackishly) parse XML.
# Locally change the IFS to break apart read commands by < or > (escaped).
# XML tags go into $tag and content goes to, well, $content.
read_dom () {
  local IFS=\>
  read -d \< tag content
}

# contains_element: quick function for checking if an element is in an
# array. The arrays in question are all really small--no scaling problems
# with a linear scan here.
doesntContainElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 1; done
  return 0
}

# to_lower: turns any uppercase letter to lowercase. Good for standardizing
# user input.
to_lower () {
  echo $1 | tr '[:upper:]' '[:lower:]'
}

validate_route () {
  local inp=$(to_lower $1)
  # allow caller to pass in more specific list of routes
  shift
  if [[ -n $2 ]]; then
    declare -a routes=("${@}")
  else
    declare -a routes=(blue red green brown pink orange purple yellow)
  fi

  # disambiguate input route--the user can enter the shortest
  # unambiguous route this way
  ambiguous=false
  match=
  for route in "${routes[@]}"; do
    if [[ ${route:0:${#inp}} == $inp ]]; then
      if [[ -z $match ]]; then
        match=$route
      else
        ambiguous=true
        break
      fi
    fi
  done

  if [[ -z $match ]]; then
    echo "Invalid route: Try {blue|red|brown|green|orange|purple|pink|yellow}"
    exit 4
    # Since we're not implementing a generalized string-contains here,
    # the only ambiguity really would be "p" (Pink and Purple).
  elif [[ -n $match && $ambiguous == true ]]; then
    echo "Multiple route matches found. Type a bit more:"
    read inp_route
    validate_route $inp_route
  else
    inp_route=$match
  fi
}

# list_stations_for: prints the list of stations for a given train route
list_stations_for () {

  validate_route $1

  printf "\nListing all stations for the ${colors[${!inp_route}]}%s${colors[END]} line:\n\n" "$inp_route"
  # Use awk to look up the given station name to find mapid and disambiguate
  awk -F',' -v route="$inp_route" '$3 == route {
    print $2
  }' <<< "$stations_txt"

}

# make_request: all the logic for making a curl request to the CTA API and
# displaying the formatted output.
make_request () {

  # URL base information
  API_KEY="6ae11e4b3a174bbf8dde5f8be2bf19f0"
  url_base="http://lapi.transitchicago.com/api/1.0/ttarrivals.aspx?"

  # Initial URL
  request_url=$url_base
  # This will always get set
  request_url+="key=${API_KEY}"
  # Add the map id to the url
  request_url+="&mapid=$1"
  # If the caller supplied a route, add it
  if [[ -n $2 ]]
  then
    request_url+="&rt=$2"
  fi

  # If no max requests are specified, default to 5.
  : ${inp_max:=10}
  request_url+="&max=${inp_max}"

  result_xml=$(curl -s ${request_url})

  # Create arrays and counters for inbound and outbound trains
  # NOTE: The notion of "inbound" and "outbound" are ill-defined in the CTA API.
  # They give a direction code specifiying either "1" or "5"--to make this
  # more understandable to the user, we print out the destination stop before
  # the list of arrivals. The API handles the case of, say, the Brown line,
  # which always terminates at Kimball, by understanding the location of the
  # train and updating the destination name to smartly reflect this
  num_inbound=0
  declare -a inbound_array

  num_outbound=0
  declare -a outbound_array

  # Read through the response XML
  while read_dom; do

    # If there's an error, skip to the error message and print it for the user
    if [[ $tag = "errCd" && $content > 0 ]]
    then
      # The next tag contains the actual error message
      read_dom; read_dom
      # Print error notification to the user
      echo "This failed--CTA API says: ${content}"
      exit 6
    fi

    # The "eta" tag specifies the start of an individual arrival. When we
    # get here, start grabbing info
    if [[ $tag = "eta" ]]
    then

      # Create a temp array to store arrival info until the direction
      # is confirmed. This info will be copied into either the inbound or
      # outbound array later
      declare -a temp_array
      declare temp_index=0

      read_dom
      while [[ $tag != "/eta" ]]
      do
        # Filter out ending tags
        # (the "flags" tag is deprecated)
        if [[ $tag != /* && $tag != "flags /" ]]
        then
          # Here's where all the useful arrival info comes in
          temp_array[$temp_index]="$content"
          ((temp_index++))
        fi

        read_dom
      done

      # Copy over the arrival info into either the inbound or outbound arrival
      # array (these arrays will be processed separately).
      if [[ ${temp_array[INBOUND_IND]} == 1 ]]
      then
        ((num_inbound++))
        inbound_array+=("${temp_array[@]}")
      else
        ((num_outbound++))
        outbound_array+=("${temp_array[@]}")
      fi
    fi
  done <<< $result_xml

  if [[ $num_inbound == 0 && $num_outbound == 0 ]]
  then
    echo "No arrivals for whatever you asked for."
    exit 4
  fi


    printf "\nResults for %s:\n" "${inbound_array[$STATION_NAME]}"

  print_arrivals $num_inbound "${inbound_array[@]}"
  print_arrivals $num_outbound "${outbound_array[@]}"
}

# print_arrivals: takes in a number of arrivals and an array containing all
# the relevant content to print.
#
# NOTE: the array is single-dimensional but contains the info for ALL stops. To
# access the correct stop, it adds a multiple of NUM_FIELDS to the index at
# every stop iteration. Works fine.
#
# A little ugly, though.
print_arrivals () {

  local num=$1
  shift
  declare -a arrival_array=("${@}")

  # In Bash, for loops using ranges (e.g. {1..5}) don't work with variables.
  # Use c-style loop instead.
  for (( i=0; i<$num; i++ )) {

      # For the first arrival, print out where the group of arrivals is headed.
      if [[ $i == 0 ]]
      then
        printf "\n%s\n" "${arrival_array[$STOP_DESCRIPTION]}"
      fi

      if [[ $(date --version) = *"coreutils"* ]]; then
          TIME1=$(date --date="${arrival_array[(($PREDICTION_TS+($NUM_FIELDS*$i)))]:9}" +%s)
          TIME2=$(date --date="${arrival_array[(($ARRIVAL_TS+($NUM_FIELDS*$i)))]:9}" +%s)
      else
          TIME1=$(date -j -f "%H:%M:%S" "${arrival_array[(($PREDICTION_TS+($NUM_FIELDS*$i)))]:9}" +%s)
          TIME2=$(date -j -f "%H:%M:%S" "${arrival_array[(($ARRIVAL_TS+($NUM_FIELDS*$i)))]:9}" +%s)
      fi

      # Convert timestamps into a "minutes away" style time
      minutes_away=$((($TIME2 - $TIME1)/60))

      printf "%20s${colors[${arrival_array[(($ROUTE+($NUM_FIELDS*$i)))]}]}%4s${colors[END]}%8s min away" \
        "To ${arrival_array[(($DESTINATION_NAME+($NUM_FIELDS*$i)))]}" \
        "(${arrival_array[(($ROUTE+($NUM_FIELDS*$i)))]:0:1})" \
        "${minutes_away}"

      if [[ ${arrival_array[(($IS_DELAYED+($NUM_FIELDS*$i)))]} == 1 ]]
      then
        printf "${colors[$Red]}%15s${colors[$END]}" "Delayed"
      elif [[ ${arrival_array[(($IS_SCHEDULED+($NUM_FIELDS*$i)))]} == 1 ]]
      then
        printf "${colors[Y]}%15s${colors[END]}" "Scheduled"
      elif [[ ${arrival_array[(($IS_APPROACHING+($NUM_FIELDS*$i)))]} == 1 ]]
      then
        printf "${colors[$G]}%15s${colors[$END]}" "Approaching"
      fi
      printf "\n"
  }
}

# --- Scripts start here ---

# Use getopts to process all the command line arguments
while getopts ":hl:m:r:s:" flag
do
  case $flag
  in
    h)
      print_usage
      exit 0;;
    l)
      list_stations_for $OPTARG
      exit 0;;
    m)
      inp_max=$OPTARG
      ;;
    s)
      inp_station=$(to_lower $OPTARG)
      ;;
    r)
      inp_route=$(to_lower $OPTARG)
      ;;
    :)
      echo "Error: -$OPTARG requires an argument"
      print_usage
      exit 1
      ;;
    --)
      break
      ;;
    esac
done

# If there was an unrecognized flag supplied, spit out the usage statement
if [[ $? != 0 ]]
then
  print_usage
  exit 5
fi

# --- Validate arguments ---
# You can make a request using a direction-specific stop or by using the parent
# station, but you'll need at least one of these. If you use both,
if [[ -z $inp_station ]]
then
  echo "Please list a station that you'd like arrival times for:"
  read inp_station
fi

if [[ -n $inp_route ]]; then
  validate_route $inp_route
fi

# Use awk to look up the given station name to find mapid and disambiguate
mapid=$(awk -F',' -v route="$inp_route" -v station="$inp_station" '$2 == station {
  if(route!="" && route==$3) {
    print $1
  }
  else if (route=="") {
    print $1 " " $3
  }
}' <<< "$stations_txt")

# Awk didn't return any mapids
if [[ -z $mapid ]]
then
  echo "No station found by that name and/or route. Try $(basename $0) -l to list stations."

# Best case: we've narrowed it down to a single mapid, just make that request
elif [[ ${#mapid} == 5 ]]
then
  make_request $mapid

# If there are multiple lines captured, we'll iterate through them and check
# out the mapid and route info. The forking logic goes like this:
#
# 1) There are multiple hits for a given station name, all with the same
# map id (e.g. Clark/Lake). In this case, just generate a single request
# and the route info for each arrival time printed will be sufficient
#
# 2) There are multiple hits for different stations that happen to have the
# same name (e.g. Damen, Cicero, etc). In this case, prompt for a station
# to disambiguate, and make that request. If none is supplied, just make
# requests for each station and display all of them.
else
  # keep track of which line it is to treat the first line differently
  hits=0
  multiple_stations=false

  # Do a quick scan through the awk results (never more than six lines)
  # to see if there are multiple stations listed

  # keep a list of the relevant train routes for smart disambiguation later
  declare -a hit_routes
  route_index=0
  while read map rt; do
    ((hits++))
    # Add to list of routes if not already there
    if doesntContainElement $rt "${hit_routes[@]}"; then
      hit_routes[$route_index]="$rt"
      ((route_index++))
    fi
    # The first line will be used as the comparison mapid
    if [[ $hits == 1 ]]
    then
      check_mapid=$map
      check_rt=$rt
    else
      # if a different station is found, we know which case it is, so exit.
      if [[ $map != $check_mapid ]]
      then
        multiple_stations=true
      # This is the unusual case where there are two stations with the
      # same name, on the same route (e.g. Western on Blue )
      fi
    fi
  done <<< "$mapid"

  # Prompt user for disambiguation, if they so desire
  if [[ $multiple_stations == true ]]
  then
    echo "Multiple stations found with that name. Enter a route to disambiguate (blank to list all):"
    read inp_route
    if [[ -n $inp_route ]]; then
      validate_route $inp_route  "${hit_routes[@]}"
    fi

    while read map rt; do

      # If a specific route was specified, list only the hits that match
      if [[ -z $inp_route || (-n $inp_route && $rt == $inp_route) ]]
      then
        make_request $map ${!rt}
      fi
    done <<< "$mapid"

  else
    make_request $check_mapid
  fi
fi

echo ""
exit 0
