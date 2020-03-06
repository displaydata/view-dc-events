ARG ELK_VERSION

FROM docker.elastic.co/logstash/logstash:${ELK_VERSION}

WORKDIR /usr/share/logstash

# required to properly process audit events
RUN bin/logstash-plugin install logstash-filter-json_encode