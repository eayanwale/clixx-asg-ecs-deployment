def action
def runner = "ENOCH"

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

        stage('Checkout and load prompt') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                script {
                    def promptFile = 'ai-source-audit-prompt.txt'

                    if (fileExists(promptFile)) {
                        claudePrompt = readFile(file: promptFile, encoding: 'UTF-8').trim()
                        echo "Successfully loaded AI prompt file as string"
                    } else {
                        echo "Required prompt file: '${promptFile}' was not found in the workspace"
                        sh 'exit 1'
                    }

                }
            }
        }

        stage('AI Source Code Audit') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                slackSend (color: '#FFFF00', message: "runner: ${runner}, STARTING AI Code Audit: Job '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
                withCredentials([
                    string(credentialsId: 'Claude_API', variable: 'ANTHROPIC_API_KEY'),
                    string(credentialsId: 'GITHUB_TOKEN', variable: 'GH_TOKEN')
                ]) {
                    aiAgent(
                        agent: claudeCode(),
                        model: 'claude-sonnet-5', 
                        // prompt: 'Scan the project files in the workspace, check for hardcoded secrets, and fix any minor syntax errors in main.tf',
                        prompt: claudePrompt,               
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
Runner: ${runner}
Job: ${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]
Build: (${env.BUILD_URL})
"""
                )
                sh '''
                terraform init -upgrade
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                sh """
                terraform plan -out=tfplan -input=false ${params.ACTION == 'destroy' ? '-destroy' : ''}
                """
            }
        }

        stage('Terraform Apply') {
            when { expression { params.ACTION == 'apply' } }
            steps {
                sh '''
                terraform apply -auto-approve tfplan
                '''
                script { 
                    // def clixxUrl = sh(script: 'terraform output -raw clixx_url', returnStdout: true).trim()

                    slackSend (
                        color: '#36a64f', 
                        message: """
                    --DEPLOYMENT COMPLETE--
Runner: ${runner}
Job: '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' 

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
                terraform destroy -auto-approve
                '''
                slackSend (
                    color: 'good', 
                    message: """
                --CLIXX DESTROYED-- 
Runner: ${runner}
Job: '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' 
                """
                )
            }
        }
    }

    post {
        failure {
            slackSend(
                channel: '#stackjenkins',
                color: 'danger',
                message: "FAILED: ${env.JOB_BASE_NAME} #${env.BUILD_NUMBER} (${env.BUILD_URL})"
            )
        }
        success {
            slackSend(
                channel: '#stackjenkins',
                color: 'good',
                message: "SUCCESS: ${env.JOB_BASE_NAME} #${env.BUILD_NUMBER} (${env.BUILD_URL})"
            )
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