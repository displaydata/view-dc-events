ARG ELK_VERSION

FROM docker.elastic.co/logstash/logstash:${ELK_VERSION}

COPY ./config/pipelines.yml /usr/share/logstash/config/pipelines.yml

COPY ./pipeline /usr/share/logstash/pipeline

WORKDIR /usr/share/logstash

# required to properly process audit events
RUN bin/logstash-plugin install logstash-filter-json_encode