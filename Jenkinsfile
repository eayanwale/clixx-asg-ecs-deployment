def action

pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Terraform action to run')
    }

    environment {
        PATH = "${getTerraformPath()}:${PATH}"
        VERSION = "1.0.${BUILD_NUMBER}"
    }

    stages {

        stage('Determine action') {
            steps {
                
                script {
                    if (params.ACTION == 'apply') {
                        action = "DEPLOYING"
                    } else if (params.ACTION == 'destroy') {
                        action = "TEARING DOWN"
                    } else {
                        action = "TINKERING..."
                    }
                }
            }
        }

        stage('AI Source Code Audit') {
            steps {
                withCredentials([string(credentialsId: 'Claude_API', variable: 'ANTHROPIC_API_KEY')]) {
                    aiAgent(
                        agent: claudeCode(),
                        model: 'claude-sonnet-5', 
                        prompt: 'Scan the project files in the workspace, check for hardcoded secrets, and fix any minor syntax errors in all .tf files',
                        yoloMode: true,
                        requireApprovals: false,
                        // apiCredentialsId: '${}'
                    )
                }
            }
        }

        stage('Terraform Init') {
            steps {
                slackSend (
                    color: '#FFFF00', 
                    message: """
                    --${action}--
        Job: ${env.JOB_NAME} [${env.BUILD_NUMBER}]
        Build: (${env.BUILD_URL})
                    """
                )
                sh '''
                cd stack-aut-Clixx
                terraform init -upgrade
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh """
                cd stack-aut-Clixx
                terraform plan -out=tfplan -input=false ${params.ACTION == 'destroy' ? '-destroy' : ''}
                """
            }
        }

        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                cd stack-aut-Clixx
                terraform apply -auto-approve tfplan
                '''
                script { 
                    def clixxUrl = sh(script: 'cd stack-aut-Clixx && terraform output -raw clixx_url', returnStdout: true).trim()

                    slackSend (
                        color: '#36a64f', 
                        message: """
                    --DEPLOYMENT COMPLETE--
                    Job: '${env.JOB_NAME} [${env.BUILD_NUMBER}]' 
                    Build: (${env.BUILD_URL})
                    
                    Clixx URL: 
                     ${clixxUrl}
                    """
                    )
                }
            }
        }

        stage('Terraform Destroy') {
            when { expression { params.ACTION == 'destroy' } }
            steps {
                sh '''
                cd stack-aut-Clixx
                terraform destroy -auto-approve
                '''
                slackSend (
                    color: '#FF0000', 
                    message: """
                --CLIXX DESTROYED-- 
                Job: '${env.JOB_NAME} [${env.BUILD_NUMBER}]' 
                Build: (${env.BUILD_URL})
                """
                )
            }
        }
    }
}

def getTerraformPath() {
    def tfHome = tool name: 'terraform-1.10', type: 'terraform'
    return tfHome
}

def getNodeJsPath(){
    def njshome= tool name: 'nodejs26', type: 'jenkins.plugins.nodejs.tools.NodeJSInstallation'
    return njshome
}