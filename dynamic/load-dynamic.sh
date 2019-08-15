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

# Capture the list of elements to load
load_list="$*"
load_list=${load_list:=all}

# -------------- Elasticsearch Setup ---------------

dir="./elasticsearch"
echo -e "\nConfiguring elasticsearch from: $dir"
# Add elasticsearch index templates for dcomm
# if [[ -d "$dir/index-templates" && ( "$load_list" =~ "all" || "$load_list" =~ "index-template" ) ]]
if [[ -d "$dir/index-templates" && "$load_list" =~ (all)|(index-template) ]]
then
  for file in "$dir"/index-templates/*.json
  do
    name=$(basename -s .json "${file}")
    echo -e "\nAdding elasticsearch index template $name from $file"
    curl -u "elastic:$elastic_p" -X POST -H "Content-Type: application/json" -H "kbn-xsrf: true" "$es_url/_template/$name-*" -d @"$file"
  done
fi

# Load Filebeat ingest-nodes into eleasticsearch
if [[ -d "$dir/ingest-nodes" && "$load_list" =~ (all)|(ingest-nodes) ]]
then
  for file in "$dir"/ingest-nodes/*.json
  do
    name=$(basename -s .json "${file}")
    echo -e "\nLoading eleasticsearch ingest-node $name from $file"
    curl -u "elastic:$elastic_p" -X PUT -H "Content-Type: application/json" -H "kbn-xsrf: true" "$es_url/_ingest/pipeline/$name" -d @"$file"
  done
fi


# -------------- Kibana Setup ---------------

dir="./kibana"
echo -e "\nConfiguring kibana from: $dir"

if [[ -d "$dir/index-pattern" && "$load_list" =~ (all)|(index-pattern) ]]
then
  for file in "$dir"/index-pattern/*.json
  do
    name=$(basename -s .json "$file")
    echo -e "\n\nAdding kibana index pattern $name from $file"
    curl -u "kibana:$kibana_p" -X POST -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/index-pattern/$name-*?overwrite=true" -d @"$file"
  done

  # If there is a file called default index, read in the first line and
  # set the default index to this value
  if [[ -f "$dir/default-index.txt" ]]
  then
    IFS=: read -r line < "$dir/default-index.txt"
    echo -e "\nSet default index to user in Kibana to: $line"
    curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/kibana/settings/defaultIndex" -d"{\"value\":\"$line\"}"
  fi
fi

if [[ -d "$dir/search" && "$load_list" =~ (all)|(search) ]]
then
  for file in "$dir"/search/*.json
  do
    name=$(basename -s .json "$file")
    echo -e "\n\nAdding Kibana search $name from $file"
    curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/search/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/visualization" && "$load_list" =~ (all)|(visuali[zs]ation) ]]
then
  for file in "$dir"/visualization/*.json
  do
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "\n\nAdding Kibana visualization $name"
    curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/visualization/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/dashboard" && "$load_list" =~ (all)|(dashboard) ]]
then
  for file in "$dir"/dashboard/*.json
  do
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "\n\nAdding Kibana Dashboard $name"
    curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/saved_objects/dashboard/$name?overwrite=true"  -d @"$file"
  done
fi

if [[ -d "$dir/import" && "$load_list" =~ (all)|(import) ]]
then
  for file in "$dir"/import/*.json
  do
    name=$(basename -s .json "$file")
    # Skip the visualisation if it is not part of the DC_MODE e.g. api when in data driven mode
    echo -e "\n\nImporting Kibana Dashboard $name"
    curl -u "kibana:$kibana_p" -X POST -i -H "Content-Type: application/json" -H "kbn-xsrf: true" "$kibana_url/api/kibana/dashboards/import?exclude=index-pattern&force=true"  -d @"$file"
  done
fi
