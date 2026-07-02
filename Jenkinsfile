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
            when { expression { params.ACTION == 'apply' } }
            steps {
                withCredentials([string(credentialsId: 'Claude_API', variable: 'ANTHROPIC_API_KEY')]) {
                    aiAgent(
                        agent: claudeCode(),
                        model: 'claude-sonnet-5', 
                        // prompt: 'Scan the project files in the workspace, check for hardcoded secrets, and fix any minor syntax errors in all .tf files in stack-aut-Clixx',
                        prompt: '''
You are an autonomous CI agent running inside a Jenkins pipeline. Operate only within the current workspace checkout.

SCOPE
- Target directory: stack-aut-Clixx (and its subdirectories only — do not touch files outside this path)
- File types for fixes: *.tf files only

STEP 1 — Secret scan (within stack-aut-Clixx only)
Recursively scan all files under stack-aut-Clixx (skip .git, .terraform, node_modules) for hardcoded secrets: API keys, passwords, tokens, private keys, connection strings, credentials in .tfvars.
- Never print secret values in logs or output — reference only as file:line.
- If any secrets are found: report them and STOP. Do not proceed to Step 2.

STEP 2 — Syntax fixes (stack-aut-Clixx/**/*.tf only)
Fix ONLY minor syntax errors: missing braces/brackets, trailing commas, bad indentation/formatting, invalid HCL structure. Do NOT change resource arguments, variable values, resource names, or any infra-affecting logic.
Run `terraform fmt` and `terraform validate` on stack-aut-Clixx after fixing. If validate fails on a file, revert your changes to that file and report it as unfixed rather than leaving a broken file.

OUTPUT (return exactly this structure, nothing else after it)
scanned_path: stack-aut-Clixx
secrets_found: true|false
secret_locations: [file:line, ...]   # only if secrets_found=true, redacted
files_fixed: [...]
files_unfixed: [...]   # validate failed, reverted
status: success|blocked_secrets|partial
''',
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