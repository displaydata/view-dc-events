ARG ELK_VERSION=7.9.0

FROM docker.elastic.co/elasticsearch/elasticsearch:${ELK_VERSION} AS elasticbase

# copy index files to container
COPY ./elasticsettings/index-templates /home/elasticsearch/index-templates/
# Possibly replace with the Powershell version of this sh script <== needs to be its own script or a MODULE to use this method
COPY ./check-ready.sh check-ready.sh
# copy elasticsearch config to the correct location in the container
COPY --chown=elasticsearch:elasticsearch ./elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

# Install the Displaydata internal network certificate
RUN yum install -y ca-certificates \
    && update-ca-trust force-enable
COPY ./ZBDDisplays-DDSRVBACK01-CA.crt /etc/pki/ca-trust/source/anchors/
RUN update-ca-trust extract

# Install powershell 7 in order to re-use DCSetupElastic module
RUN curl https://packages.microsoft.com/config/rhel/7/prod.repo | tee /etc/yum.repos.d/microsoft.repo \
    && yum install -y powershell \
    && pwsh -c 'Register-PSRepository -Name DisplaydataGallery -SourceLocation https://artifactory.dev.zbddisplays.local/artifactory/api/nuget/dev-powershell-nuget-local/ -InstallationPolicy Trusted' \
    && pwsh -c 'Install-Module -Name DCSetupElastic -Repository DisplaydataGallery -Verbose'

# start the Elasticsearch container endpoint and install index-templates
# NOTE: elastic entrypoint is invoked as a background task
RUN /usr/local/bin/docker-entrypoint.sh eswrapper & \
    chmod 0775 check-ready.sh \
    && ./check-ready.sh \
    && echo "running template upload" \
    && pwsh -c 'Import-ElasticSettingsToUrl -Url "http://localhost:9200" -Path /home/elasticsearch -Verbose -Username elastic -Password elastic' \
    && echo "finished template upload"

#  required to install kibana with rpm
COPY ./kibana.repo /etc/yum.repos.d/kibana.repo

# ARG must be re-declared to be available at the next build stage
ARG ELK_VERSION

# install kibana into the container
RUN echo "install kibana" \
    && rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch \
    && yum install -y "kibana-$ELK_VERSION-1"

# required to start kibana NOTE: this path is DIFFERENT FOR CONTAINERS i.e. if used in multi-stage builds this must change
COPY --chown=1000:0 ./kibana-build.yml /etc/kibana/kibana.yml

# copy the kibana settings into the container
COPY ./kibanasettings/spaces/ /home/kibana/spaces/

# REQUIRED: to be able to start kibana serice with systemctl https://github.com/gdraheim/docker-systemctl-replacement
# IMPORTANT: must be a LF end of line sequence file otherwise this won't be recognised by the host (Contos7) OS
COPY ./systemctl.py /usr/bin/systemctl

# make new systemctl executable - required to allow others users to execute this file, specifically the next command
RUN chmod +x /usr/bin/systemctl

# systemctl daemon reload required to take into account that kibana has been installed
RUN /bin/systemctl daemon-reload

# enable the kibana service and start it, install all the kibana settings
# NOTE: systemctl start and kibana entrypoint are run as background tasks
RUN /bin/systemctl enable kibana.service \
    && systemctl start kibana.service \
    && /usr/local/bin/docker-entrypoint.sh eswrapper & \
    pwsh -c 'Get-Process -IncludeUserName' \
    && pwsh -c 'Import-KibanaSavedObjects -Url "http://localhost:5601" -Path /home/kibana/spaces -Username elastic -Password elastic' \
    && echo "finished kibana settings upload"

# final image - this uses multi-stage builds to avoid carrying all the setup steps into the new container
FROM docker.elastic.co/elasticsearch/elasticsearch:${ELK_VERSION}
# copies the indexes from the previous container
COPY --from=elasticbase /usr/share/elasticsearch/data/ /usr/share/elasticsearch/data/

# NOTE: possible improvements
# 1. run the saved-objects API on the elasticbase image to properly export the .kibana_1 index & others
# 2. copy these exported items to the 'final image' using a shell script
# 3. run the saved objects API on the final image to import the indexes OR make them get imported on BEFORE container init
# 4. delete the copied items