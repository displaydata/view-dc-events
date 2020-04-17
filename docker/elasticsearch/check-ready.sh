#!/bin/sh


# Function to check the status of the elasticsearch service
# Note: status doesn't go green on a single node system - see http://chrissimpson.co.uk/elasticsearch-yellow-cluster-status-explained.html
elastic_ready=-1
check_elasticsearch() {
  curl -u "elastic:elastic" --silent --fail --output /dev/null -H "Content-Type: application/json" -H "kbn-xsrf: true" "localhost:9200/_cluster/health?wait_for_status=yellow&timeout=10s"
  elastic_ready=$?
}



echo -e "\nWaiting for elasticsearch API..."
i=0
while [[ $elastic_ready -ne 0 ]] && [[ $i -le 30 ]]
do
  echo -n "$elastic_ready;"
  sleep 5s ; i=$i+1
  check_elasticsearch
done

if [[ $elastic_ready -ne 0 ]]; then
  echo "Elastic is not ready!"
  exit 1
else
  echo "Elastic is ready!"
  exit 0
fi
