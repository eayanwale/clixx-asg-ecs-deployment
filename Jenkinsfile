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
            steps {
                script {
                    sh 'rm -f secrets_found.log syntax_issues_found.log'

                    def promptFile = 'ai-source-audit-prompt.txt'
                    def fixPromptFile = 'ai-source-audit-fix-prompt.txt'

                    if (fileExists(promptFile)) {
                        claudePrompt = readFile(file: promptFile, encoding: 'UTF-8').trim()
                        echo "Successfully loaded AI scan prompt file as string"
                    } else {
                        error "Required prompt file: '${promptFile}' was not found in the workspace"
                    }

                    if (fileExists(fixPromptFile)) {
                        claudeFixPrompt = readFile(file: fixPromptFile, encoding: 'UTF-8').trim()
                        echo "Successfully loaded AI fix prompt file as string"
                    } else {
                        error "Required prompt file: '${fixPromptFile}' was not found in the workspace"
                    }
                }
            }
        }

        stage('AI Source Code Audit') {
            steps {
                slackSend (color: '#FFFF00', message: "runner: ${runner}, STARTING AI Code Audit ${action}: Job '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
                withCredentials([
                    string(credentialsId: 'Claude_API', variable: 'ANTHROPIC_API_KEY')
                ]) {
                    aiAgent(
                        agent: claudeCode(),
                        model: 'claude-sonnet-5',
                        // prompt: 'Scan the project files in the workspace, check for hardcoded secrets, and list any minor syntax errors in *.tf files',
                        prompt: claudePrompt,
                        yoloMode: true,
                        requireApprovals: false,
                        // apiCredentialsId: '${}'
                    )
                }
            }
        }

        stage('Secrets Found Gate') {
            when { expression { fileExists('secrets_found.log') } }
            steps {
                script {
                    def secretsLog = readFile('secrets_found.log')
                    echo "SECRETS FOUND:\n${secretsLog}"

                    slackSend (
                        color: '#FF0000',
                        message: "runner: ${runner}, SECRETS FOUND by AI Code Audit: Job '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - pipeline paused, approval needed to continue."
                    )

                    sh '''
                    aws sns publish \
                      --topic-arn ${SNS_SECURITY_TOPIC_ARN} \
                      --subject "Secrets found: ${JOB_BASE_NAME} #${BUILD_NUMBER}" \
                      --message "Hardcoded secrets were detected during AI source audit for job ${JOB_BASE_NAME} build #${BUILD_NUMBER}. See ${BUILD_URL} and the archived secrets_found.log for file:line references. No secret values are included."
                    '''

                    def proceed = input(
                        id: 'secretsFoundApproval',
                        message: 'Hardcoded secrets were found in this repo (see secrets_found.log / console output above). Continue the pipeline anyway?',
                        parameters: [
                            booleanParam(defaultValue: false, description: 'Continue the pipeline despite secrets found', name: 'PROCEED')
                        ]
                    )

                    if (!proceed) {
                        error "Pipeline aborted: secrets found and not approved to continue."
                    }
                }
                archiveArtifacts artifacts: 'secrets_found.log', allowEmptyArchive: true
            }
        }

        stage('Fix Approval Gate') {
            when { expression { fileExists('syntax_issues_found.log') } }
            steps {
                script {
                    def issuesLog = readFile('syntax_issues_found.log')
                    echo "SYNTAX ISSUES FOUND:\n${issuesLog}"

                    slackSend (
                        color: '#FFFF00',
                        message: "runner: ${runner}, Terraform syntax issues found by AI Code Audit: Job '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}) - approval needed to implement fixes and push."
                    )

                    applyFixes = input(
                        id: 'fixApproval',
                        message: 'Minor Terraform syntax issues were found (see syntax_issues_found.log / console output above). Implement the fixes and push them?',
                        parameters: [
                            booleanParam(defaultValue: false, description: 'Implement fixes, commit, tag, and push', name: 'APPLY_FIXES')
                        ]
                    )
                }
                archiveArtifacts artifacts: 'syntax_issues_found.log', allowEmptyArchive: true
            }
        }

        stage('AI Fix and Push') {
            when { expression { fileExists('syntax_issues_found.log') && applyFixes } }
            steps {
                slackSend (color: '#FFFF00', message: "runner: ${runner}, STARTING AI Fix and Push: Job '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
                withCredentials([
                    string(credentialsId: 'Claude_API', variable: 'ANTHROPIC_API_KEY'),
                    string(credentialsId: 'GITHUB_TOKEN', variable: 'GH_TOKEN')
                ]) {
                    aiAgent(
                        agent: claudeCode(),
                        model: 'claude-sonnet-5',
                        prompt: claudeFixPrompt,
                        yoloMode: true,
                        requireApprovals: false,
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
                    def clixxAsgUrl = sh(script: 'terraform output -raw clixx_asg_url', returnStdout: true).trim()

                    slackSend (
                        color: '#36a64f',
                        message: """
                    --DEPLOYMENT COMPLETE--
Runner: ${runner}
Job: '${env.JOB_BASE_NAME} [${env.BUILD_NUMBER}]'

Clixx ASG URL:
    ${clixxAsgUrl}
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