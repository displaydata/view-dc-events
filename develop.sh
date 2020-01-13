#!/usr/bin/env bash
#
# develop <cmd> <options>
#   up
#   clean
#   ingest
#   update
#   export
#   shell
#   backup [<filename>]
#   restore [<filename>]
#   dynamic up [visualisations]
#   dynamic decode
#   dcomm up [visualisations]
#   dcomm decode

# TODO: Send scripts output to a file for debugging, not to console

# Exit immediately if any commands fail
set -e
# Exit immediately if any variables are not set
# set -u
# set -x

# Load the environmental variables if present
if [[ -f .env ]]; then
   . .env
fi


# Colours:
Default="\033[39m"
# Magenta="\033[35m"
Blue="\033[34m"
LightGreen="\033[92m"

# Create docker-compose command to run
# Set COMPOSE_FILE in .env for the functionality you require
COMPOSE_FILE=${COMPOSE_FILE:="docker-compose.yml"} # default to basic functionality
COMPOSE="docker-compose"
# DOCKER="docker"

# If we pass any arguments...
if [[ $# -gt 0 ]];then
  # build: Build a customised docker container
  if [[ "$1" == "build" ]]; then
    shift 1
    $COMPOSE build "$@"

  # up: Bring up elastic & kibana base containers
  #     Can be used for ingest from other sources
  elif [[ "$1" == "up" ]]; then
    shift 1
    $COMPOSE up --detach --no-deps elastic kibana filebeat logstash "$@"

  # clean: Bring machines down and remove the volume(s)
  elif [[ "$1" == "clean" ]]; then
    shift 1
    $COMPOSE down --volumes "$@"

  # shell: go to a shell prompt in the service container specifcied in $2
  elif [[ "$1" == "shell" ]]; then
    shift 1
    $COMPOSE exec "$1" /bin/bash

  # ingest: start up logstash and ingest log files
  elif [[ "$1" == "ingest" ]]; then
    shift 1
    $COMPOSE up --detach elastic kibana
    # Load the index patterns, templates etc...
    $COMPOSE run powershell pwsh -c '/home/powershell/manage-elastic.ps1 -Url "http://elasticsearch:9200" -Path /home/elasticsearch ; /home/powershell/manage-kibana.ps1 -Import -Url "http://kibana:5601" -Path /home/kibana/spaces'
    # Load logstash pipeline into elasticsearch
    $COMPOSE run --rm filebeat filebeat setup --strict.perms=false --pipelines --modules logstash
    # Start logstash
    $COMPOSE up --detach filebeat logstash

  # update: update the visualisations etc...
  elif [[ "$1" == "update" ]]; then
    shift 1
    $COMPOSE up --detach elastic kibana
    # Load the index patterns, templates etc...
    $COMPOSE run powershell pwsh -c '/home/powershell/manage-elastic.ps1 -Url "http://elasticsearch:9200" -Path /home/elasticsearch ; /home/powershell/manage-kibana.ps1 -Import -Url "http://kibana:5601" -Path /home/kibana/spaces'

  # export: export the visualisations etc...
  elif [[ "$1" == "export" ]]; then
    shift 1
    # Export the index patterns, templates etc...
    $COMPOSE run powershell pwsh -c '/home/powershell/manage-kibana.ps1 -Export -Url "http://kibana:5601" -Path /home/kibana/spaces'

  # decode: Uncompress log files in DYNAMIC_BASEDIR
  # elif [[ "$1" == "decode" ]]; then
  #   echo "Finding and uncompressing any compressed log files..."
  #   find "${DYNAMIC_BASEDIR}" -name '*json.gz' -exec gunzip {} \;

  # backup: backup the volume to host PC
  elif [[ "$1" == "backup" ]]; then
    # $COMPOSE run --rm -v /tmp:/backup elastic /usr/bin/touch /backup/test.txt
    echo "Ensure you elastic instance is down before this command is run"
    # Name the backup_file after the elastic volume name
    if [[ -z "$2" ]]; then
      # Name the backup_file after the elastic volume name
      backup_file="$($COMPOSE config --volumes | head -n 1).tar.gz"
    else
      backup_file="${2}.tar.gz"
    fi

    echo -e "Backing up ${Blue}/usr/share/elasticsearch/data${Default} to here: ${LightGreen}/tmp/${backup_file}${Default}"
    if [[ -f "/tmp/${backup_file}" ]]; then rm -f "/tmp/${backup_file}"; fi
    $COMPOSE run --rm -v /tmp:/backup elastic tar czf "/backup/${backup_file}" -C /usr/share/elasticsearch/data ./

  # restore: restore a saved backup to container volume
  elif [[ "$1" == "restore" ]]; then
    echo "Ensure you elastic instance is down before this command is run."
    echo "It will erase any elastic data in the volume."
    if [[ -z "$2" ]]; then
      # Name the backup_file after the elastic volume name
      restore_file="/tmp/$($COMPOSE config --volumes | head -n 1).tar.gz"
    else
      restore_file="$2"
    fi
    volume=$($COMPOSE config --volumes | head -n 1)

    if [[ -f "${restore_file}" ]] && [[ "${restore_file}" =~ \.tar.gz$ ]]; then
      echo -e "Restoring ${LightGreen}${restore_file}${Default} to container volume ${Blue}${volume}${Default}"
      $COMPOSE run --rm --user="elasticsearch" -v "${restore_file}":/tmp/restore.tar.gz elastic tar xvzf /tmp/restore.tar.gz -C /usr/share/elasticsearch/data --no-same-owner
    else
      echo -e "Backup file ${LightGreen}${restore_file}${Default} does not exist"
    fi

  # Else, pass-thru args to docker-compose
  else
    $COMPOSE "$@"
  fi

else
  $COMPOSE ps
fi