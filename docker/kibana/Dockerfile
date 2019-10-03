#
# A version of kibana that includes the enhanced table plugin
# giving us the ability to have multiple column metrics
ARG ELK_VERSION

FROM docker.elastic.co/kibana/kibana:${ELK_VERSION}

ARG ELK_VERSION
ARG EDTPLUGIN_VERSION
ARG KETPLUGIN=https://github.com/fbaligand/kibana-enhanced-table/releases/download/v${EDTPLUGIN_VERSION}/enhanced-table-${EDTPLUGIN_VERSION}_${ELK_VERSION}.zip

WORKDIR /usr/share/kibana

# Plug releases can be found here: https://github.com/fbaligand/kibana-enhanced-table/releases
# RUN if ( curl -o/dev/null -sfI ${KETPLUGIN} ) ; \
#   then bin/kibana-plugin install ${KETPLUGIN} ; \
#   else echo "Kibana Enhanced Table plugin does not exist or no release available" ; \
#   fi
RUN bin/kibana-plugin install ${KETPLUGIN}
# Start up kibana and wait for it to run its optimise process before stopping
RUN /usr/share/kibana/bin/kibana --optimize 2>/dev/null
