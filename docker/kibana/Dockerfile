#
# A version of kibana that includes the enhanced table plugin
# giving us the ability to have multiple column metrics
ARG ELK_VERSION="7.3.0"

FROM docker.elastic.co/kibana/kibana:${ELK_VERSION}
ARG ELK_VERSION
ARG EDTPLUGIN_VERSION
WORKDIR /usr/share/kibana
# Plug releases can be found here: https://github.com/fbaligand/kibana-enhanced-table/releases
RUN bin/kibana-plugin install https://github.com/fbaligand/kibana-enhanced-table/releases/download/v${EDTPLUGIN_VERSION}/enhanced-table-${EDTPLUGIN_VERSION}_${ELK_VERSION}.zip