node('docker-host') {
    checkout scm

    def ELK_VERSION = "7.8.1"
    def dynamicCentralVersion = "1.13.0"

    def tag_branch = ''
    if (BRANCH_NAME != 'develop') {
        tag_branch = "-${BRANCH_NAME.replaceAll('/', '_')}"
    }

    def tag = "${dynamicCentralVersion}-${ELK_VERSION}${tag_branch}-${BUILD_ID}"

    def containerPrefix = "dev-elasticsearchdocker-build-local.artifactory.dev.zbddisplays.local/displaydata/"

    def server = Artifactory.server 'default'
    def rtDocker = Artifactory.docker server: server

    //build elasticsearch container
    def elasticImageName = "${containerPrefix}elasticsearch:${tag}"
    def elasticImage = docker.build(elasticImageName, "--build-arg ELK_VERSION=${ELK_VERSION} ./docker/elasticsearch")
    def elasticBuildInfo = rtDocker.push elasticImageName, 'dev-elasticsearchdocker-build-local'
    server.publishBuildInfo elasticBuildInfo

    //build logstash container
    def logstashImageName = "${containerPrefix}logstash:${tag}"
    def logstashImage = docker.build(logstashImageName, "--build-arg ELK_VERSION=${ELK_VERSION} ./docker/logstash")
    def logstashBuildInfo = rtDocker.push logstashImageName, 'dev-elasticsearchdocker-build-local'
    server.publishBuildInfo logstashBuildInfo
    
}
