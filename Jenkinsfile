node('docker-host') {
    checkout scm

    def ELK_VERSION = "7.6.2"
    def EDTPLUGIN_VERSION= "1.8.0"
    def dynamicCentralVersion = "1.12.0"

    def tag = "${dynamicCentralVersion}-${ELK_VERSION}-${BUILD_ID}"

    def containerPrefix = "dev-elasticsearchdocker-build-local.artifactory.dev.zbddisplays.local/displaydata/"

    def server = Artifactory.server 'default'
    def rtDocker = Artifactory.docker server: server

    //build elasticsearch container
    def elasticImageName = "${containerPrefix}elasticsearch:${tag}"
    def elasticImage = docker.build(elasticImageName, "--build-arg ELK_VERSION=${ELK_VERSION} ./docker/elasticsearch")
    def elasticBuildInfo = rtDocker.push elasticImageName, 'dev-elasticsearchdocker-build-local'
    server.publishBuildInfo elasticBuildInfo

    //build kibana container
    def kibanaImageName = "${containerPrefix}kibana:${tag}"
    def kibanaImage = docker.build(kibanaImageName, "--build-arg ELK_VERSION=${ELK_VERSION} --build-arg EDTPLUGIN_VERSION=${EDTPLUGIN_VERSION} ./docker/kibana")
    def kibanaBuildInfo = rtDocker.push kibanaImageName, 'dev-elasticsearchdocker-build-local'
    server.publishBuildInfo kibanaBuildInfo

    //build logstash container
    def logstashImageName = "${containerPrefix}logstash:${tag}"
    def logstashImage = docker.build(logstashImageName, "--build-arg ELK_VERSION=${ELK_VERSION} ./docker/logstash")
    def logstashBuildInfo = rtDocker.push logstashImageName, 'dev-elasticsearchdocker-build-local'
    server.publishBuildInfo logstashBuildInfo
    
}