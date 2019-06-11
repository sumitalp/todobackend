node {
    checkout scm
    
    try{
        stage('Run unit/integration tests'){
            sh label: '', script: 'sudo make test'
        }
        
        stage('Build application artefacts'){
            sh script: 'sudo make build'
        }
        
        stage('Create release environment and run acceptance tests'){
            sh script: 'sudo make release'
        }
        
        stage('Tag and publish release image'){
            sh script: 'sudo make tag latest \$(git rev-parse --short HEAD) \$(git tag --points-at HEAD)'
            sh script: 'sudo make buildtag master \$(git tag --points-at HEAD)'

            sh script: "sudo make login DOCKER_USER=${DOCKER_USER} DOCKER_PASSWORD=${DOCKER_PASSWORD}"
            
            sh script: 'sudo make publish'
        }
        
    } finally {
        stage('Collect test reports'){
            step([$class: 'JUnitResultArchiver', testResults: '**/reports/*.xml'])
        }
        
        // stage('Clean up'){
        //     sh script: 'sudo make clean'
        //     sh script: 'sudo make logout'
        // }
    }
}