// Define parameters with default empty values
parameters {
    string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'The Git branch to build')
}

// Global environment variables
def AWS_REGION = 'us-east-1'
def APP_NAME = 'my-app'

pipeline {
    // Define a single agent for the entire pipeline.
    // This agent will run all steps, including fetching AWS details.
    agent {
        ecs {
            label 'ecs-agent'
            launchType 'FARGATE'
            image 'jenkins-agent:1'
            // Note: Subnets and security groups must be defined in the ECS agent template
            // in the Jenkins UI, as we can't use dynamic variables here.
        }
    }
    stages {
        stage('Build and Deploy') {
            steps {
                script {
                    // Fetch AWS details first
                    def awsAccountId = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
                    def ecrRepository = "${awsAccountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
                    
                    // Set environment variables for subsequent steps in this stage
                    env.AWS_ACCOUNT_ID = awsAccountId
                    env.ECR_REPOSITORY = ecrRepository
                    env.ECS_CLUSTER_FARGATE = "${APP_NAME}-fargate-cluster"
                    env.ECS_SERVICE_FARGATE = "${APP_NAME}-fargate-service"
                    env.ECS_CLUSTER_EC2 = "${APP_NAME}-ec2-cluster"
                    env.ECS_SERVICE_EC2 = "${APP_NAME}-ec2-service"

                    // Now run the build and deploy steps
                    
                    // Checkout
                    stage('Checkout') {
                        git branch: params.GIT_BRANCH, url: 'https://github.com/ClintonChe/test-repo.git'
                    }

                    // Build and Push
                    stage('Build and Push Image with Kaniko') {
                        sh """
                        /kaniko/executor --dockerfile=Dockerfile --context=dir://\${WORKSPACE} \
                           --destination=${env.ECR_REPOSITORY}:${env.BUILD_NUMBER} \
                           --destination=${env.ECR_REPOSITORY}:latest
                        """
                    }

                    // Deploy to Staging
                    stage('Deploy to Staging (Fargate)') {
                        sh "aws ecs update-service --cluster ${env.ECS_CLUSTER_FARGATE} --service ${env.ECS_SERVICE_FARGATE} --force-new-deployment --region ${AWS_REGION}"
                    }

                    // Deploy to Production
                    stage('Deploy to Production (EC2)') {
                        if (env.GIT_BRANCH == 'main') {
                            input message: 'Deploy to production (EC2)?', ok: 'Deploy'
                            sh "aws ecs update-service --cluster ${env.ECS_CLUSTER_EC2} --service ${env.ECS_SERVICE_EC2} --force-new-deployment --region ${AWS_REGION}"
                        }
                    }
                }
            }
            post {
                always {
                    cleanWs()
                }
            }
        }
    }
}