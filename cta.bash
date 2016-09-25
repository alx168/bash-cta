#! /bin/bash

#-------------------------------------------------------------------------------
# cta.bash
# Nic Hite
# 07/22/16
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

  -r: Train route to check (e.g. 'Blue', 'Red')
  -s: Station name (e.g. 'Clark/Lake', 'Fullteron')
  -l: List stops for a route"

# --- Functions ---

# read_dom: function to (somewhat hackishly) parse XML.
# Locally change the IFS to break apart read commands by < or > (escaped).
# XML tags go into $tag and content goes to, well, $content.
read_dom () {
  local IFS=\>
  read -d \< tag content
}

# to_lower: turns any uppercase letter to lowercase. Good for standardizing
# user input.
to_lower () {
  echo $1 | tr '[:upper:]' '[:lower:]'
}

validate_route () {
  # Valid the supplied route, if any
  if [[ -z $inp_route ]]
  then
    :
  else
    # NOTE: we could create an array with all these string values and use
    # something like if [[ " ${valid_routes[@]} " =~ " $inp_route " ]], but
    # including the regex capability is actually a bit more overhead
    if [[ $inp_route != "blue" &&
          $inp_route != "red" &&
          $inp_route != "green" &&
          $inp_route != "brown" &&
          $inp_route != "pink" &&
          $inp_route != "orange" &&
          $inp_route != "purple" &&
          $inp_route != "yellow"
        ]]
    then
      echo "Invalid route: Try {blue|red|brown|green|orange|purple|pink|yellow}"
      exit 4
    fi
  fi
}

# list_stations_for: prints the list of stations for a given train route
list_stations_for () {

  validate_route $1

  printf "\nListing all stations for the %s line:\n\n" "$1"
  # Use awk to look up the given station name to find mapid and disambiguate
  awk -F',' -v route="$1" '$3 == route {
    print $2
  }' < train_stations.txt

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

      # Convert timestamps into a "minutes away" style time
      TIME1=$(date -j -f "%H:%M:%S" "${arrival_array[(($PREDICTION_TS+($NUM_FIELDS*$i)))]:9}" +%s)
      TIME2=$(date -j -f "%H:%M:%S" "${arrival_array[(($ARRIVAL_TS+($NUM_FIELDS*$i)))]:9}" +%s)
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
while getopts "hl:m:r:s:" flag
do
  case $flag
  in
    h)
      printf "%80s\n" "$usage"
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
    --)
      break
      ;;
    esac
done

# If there was an unrecognized flag supplied, spit out the usage statement
if [[ $? != 0 ]]
then
  printf "%80s\n" "$usage"
  exit 5
fi

# --- Validate arguments ---
# You can make a request using a direction-specific stop or by using the parent
# station, but you'll need at least one of these. If you use both,
if [[ -z $inp_station ]]
then
  echo "You're gonna need either a stop or a station."
  exit 3
fi

validate_route $inp_route

# Use awk to look up the given station name to find mapid and disambiguate
mapid=$(awk -F',' -v route="$inp_route" -v station="$inp_station" '$2 == station {
  if(route!="" && route==$3) {
    print $1
  }
  else if (route=="") {
    print $1 " " $3
  }
}' < train_stations.txt)

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
  while read map rt; do
    ((hits++))
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
        break

      # This is the unusual case where there are two stations with the
      # same name, on the same route (e.g. Western on Blue )
      fi
    fi
  done <<< "$mapid"

  # Prompt user for disambiguation, if they so desire
  if [[ $multiple_stations == true ]]
  then
    echo "Multiple stations found. Enter a route to disambiguate (blank to list all):"
    read inp_route
    validate_route

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
