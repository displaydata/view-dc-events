#!/bin/bash
#
# User can specify a particular object to load or leave blank for all objects
# e.g. ./load-elk.sh dashboard
# This will only load the dashboard objects

# TODO: Send curl output to log file and summarise result

# Exit immediately if any commands fail
# set -e

# Exit immediately if any variables are not set
set -u

# Enable bash debug
#set -x

# Colours:
Default="\033[39m"
Magenta="\033[35m"
Blue="\033[34m"
LightGreen="\033[92m"
Red="\033[31m"



echo "Loading elasticsearch with templates, ingest nodes, visualisations etc."

# Get the IP from environmental variables or set defaults if not available
es_url="http://${ELK_IP:=localhost}:9200"
kibana_url="http://${ELK_IP:=localhost}:5601"
echo "es_url: $es_url, kibana_url: $kibana_url"

# Set default passwords for all the builtin users
elastic_p="${ELASTIC_PASS:=elastic}"
kibana_p="${KIBANA_PASS:=kibana}"
logstash_p="${LOGSTASH_PASS:=logstash}"
beats_p="${BEATS_PASS:=beatsystem}"
apm_p="${APM_PASS:=apmsystem}"
monitor_p="${MONITOR_PASS:=monitor}"

# First argument is directory where objects can be found
if [[ $# -gt 0 ]]; then
  basedir="$1"
  shift 1
else
  echo "Object directory must be specified."
  exit 1
fi

# Capture the remaining argument as a list of elements to load
load_list="$*"
load_list=${load_list:=all}

# Function
#   $1 : Credentials e.g. "elastic:elastic"
#   $2 : HTTP method e.g. GET, POST, PUT
#   $3 : URL
#   $4 : Data
#
function mycurl()
{
  # output_file="./output.txt"
  output_file="/dev/null"
  # set -x
  __resultcode=$( curl -s -o "$output_file" -w '%{http_code}' \
    -u $1 \
    -X $2 -i \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    "$3" \
    -d"$4")
  # set +x
  if [[ $__resultcode -ge 400 ]]; then
    echo "${Red}${__resultcode}${Default}"
  else
    echo "${LightGreen}${__resultcode}${Default}"
  fi
}

# TODO: Output user friendly text instead of curl response codes
#
#  7 : CURLE_COULDNT_CONNECT
# 22 : CURLE_HTTP_RETURNED_ERROR
# 52 : CURLE_GOT_NOTHING
# 56 : CURLE_RECV_ERROR

# Function to check the status of the elasticsearch service
# Note: status doesn't go green on a single node system - see http://chrissimpson.co.uk/elasticsearch-yellow-cluster-status-explained.html
elastic_ready=-1
check_elasticsearch() {
  curl -u "elastic:$elastic_p" --silent --fail --output /dev/null -H "Content-Type: application/json" -H "kbn-xsrf: true" "$es_url/_cluster/health?wait_for_status=yellow&timeout=10s"
  elastic_ready=$?
}

# Function to return the state of the kibana service
kibana_ready=-1
check_kibana() {
  curl -u "kibana:$kibana_p" --silent --fail --output /dev/null -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/status"
  kibana_ready=$?
}

# ---------------------------------------------------------------

echo -e "\nWaiting for elasticsearch API..."
i=0
while [[ $elastic_ready -ne 0 ]] && [[ $i -le 30 ]]
do
  echo -n "$elastic_ready;"
  sleep 5s ; i=$i+1
  check_elasticsearch
done

# -------------- Elasticsearch Setup ---------------

dir="${basedir}/elasticsearch"
echo -e "\nConfiguring elasticsearch from: $dir"
# Add elasticsearch index templates for dcomm
# if [[ -d "$dir/index-templates" && ( "$load_list" =~ "all" || "$load_list" =~ "index-template" ) ]]
# Regex to recognise all, index-template or index-templates
if [[ -d "$dir/index-templates" && "$load_list" =~ (all)|(index-templates?) ]]
then
  for file in "$dir"/index-templates/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "${file}")
    echo -e "Adding elasticsearch index template ${Blue}${name}${Default} from $file:" \
      "$( mycurl "elastic:$elastic_p" PUT "$es_url/_template/$name-*" @"$file" )"
  done
fi

# Load Filebeat ingest-nodes into eleasticsearch
if [[ -d "$dir/ingest-nodes" && "$load_list" =~ (all)|(ingest-nodes?) ]]
then
  for file in "$dir"/ingest-nodes/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "${file}")
    echo -e "Loading eleasticsearch ingest-node ${Blue}${name}${Default} from $file:" \
      "$( mycurl "elastic:$elastic_p" PUT "$es_url/_ingest/pipeline/$name" @"$file" )"
  done
fi


# -------------- Kibana Setup ---------------

# Wait for Kibana to be running
echo -e "\nWaiting for kibana API to be ready..."
check_kibana
while [[ $kibana_ready -ne 0 ]]
do
	echo -e -n "$kibana_ready;"
	sleep 2s
  check_kibana
done

dir="${basedir}/kibana"
echo -e "\nConfiguring kibana from: $dir"

if [[ -d "$dir/index-pattern" && "$load_list" =~ (all)|(index-pattern) ]]
then
  for file in "$dir"/index-pattern/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "$file")
    echo -e "Adding kibana index pattern ${Blue}${name}${Default} from $file:" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/saved_objects/index-pattern/$name-*?overwrite=true" @"$file" )"
  done

  # If there is a file called default index, read in the first line and
  # set the default index to this value
  if [[ -f "$dir/default-index.txt" ]]
  then
    IFS=: read -r line < "$dir/default-index.txt"
    echo -e "Set default index to user in Kibana to: $line:" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/kibana/settings/defaultIndex" "{\"value\":\"$line\"}" )"
  fi
fi

if [[ -d "$dir/search" && "$load_list" =~ (all)|(search) ]]
then
  for file in "${dir}"/search/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "$file")
    echo -e "Adding Kibana search ${Blue}${name}${Default} from $file:" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/saved_objects/search/$name?overwrite=true" @"$file" )"
    # curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/search/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/visualization" && "$load_list" =~ (all)|(visuali[zs]ations?) ]]
then
  for file in "$dir"/visualization/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "Adding Kibana visualization ${Blue}${name}${Default}:" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/saved_objects/visualization/$name?overwrite=true" @"$file" )"
    # curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/visualization/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/dashboard" && "$load_list" =~ (all)|(dashboards?) ]]
then
  for file in "$dir"/dashboard/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "Adding Kibana dashboard ${Blue}${name}${Default}:" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/saved_objects/dashboard/$name?overwrite=true" @"$file" )"
    # curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/dashboard/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/import" && "$load_list" =~ (all)|(import) ]]
then
  for file in "$dir"/import/*.json
  do
    if [[ ! -e $file ]]; then continue; fi
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "Importing Kibana dashboard ${Blue}${name}${Default};" \
      "$( mycurl "kibana:$kibana_p" POST "$kibana_url/api/kibana/dashboards/import?exclude=index-pattern&force=true" @"$file" )"
    # curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/kibana/dashboards/import?exclude=index-pattern&force=true"  -d @"$file"
  done
fi
