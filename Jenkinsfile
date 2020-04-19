//pipeline {
//    agent {
//        node {
//            label 'docker-host'
//       }
//    }
//    environment {
//        // put global env vars here
//        def server = Artifactory.server 'default'
//        def rtDocker = Artifactory.docker server: server
//    }
//    stages {
//        stage('Build elasticsearch container') {
//           steps {
//                docker.build("docker-infra-local.artifactory.dev.zbddisplays.local/displaydata/elasticsearch:7.6.2", "./docker/elasticsearch")
//                def elasticInfo = rtDocker.push "docker-infra-local.artifactory.dev.zbddisplays.local/displaydata/elasticsearch:7.6.2", 'docker-infra-local'
//                server.publishBuildInfo elasticInfo
//           }
//        }
//        stage('Build kibana container') {
//            steps {
//
//            }
//        }
//        stage('Build logstash container') {
//            steps {
//
//            }
//        }
//    }
//}

node('docker-host') {
    checkout scm

    // see example https://gitlab.dev.zbddisplays.local/infrastructure/cloud-costs-docker/blob/master/Jenkinsfile

    def server = Artifactory.server 'default'
    def rtDocker = Artifactory.docker server: server

    def elasticImage = docker.build("docker-infra-local.artifactory.dev.zbddisplays.local/displaydata/elasticsearch:7.6.2", "./docker/elasticsearch")//.inside("--privileged")
    def elasticInfo = elasticInfo.push "docker-infra-local.artifactory.dev.zbddisplays.local/displaydata/elasticsearch:7.6.2", 'docker-infra-local'
    server.publishBuildInfo elasticInfo
    //docker.build // name? & build commands go here <<buildto>>?

    //def elasticInfo = rtDocker.push "<<buildto>>", 'docker-infra-local'
    //server.publishBuildInfo elasticInfo

    //docker.build // kibana defined how?

    //def kibanaInfo = rtDocker.push 
    //server.publishBuildInfo kibanaInfo

    //docker.build // logstash defined how?

    //def logstashInfo = rtDocker.push 
    //server.publishBuildInfo logstashInfo
    

}