// Define parameters with default empty values
parameters {
    string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'The Git branch to build')
}

// Global environment variables
def AWS_REGION = 'us-east-1'
def APP_NAME = 'my-app'

pipeline {
    // Define a single agent for the entire pipeline.
    agent {
        ecs {
            // The 'cloud' parameter has been removed as it is not allowed by your Jenkins environment.
            label 'ecs-agent'
            launchType 'FARGATE'
            image 'jenkins-agent:1'
        }
    }
    environment {
        // Initialize variables that will be set later
        AWS_ACCOUNT_ID = ""
        ECR_REPOSITORY = ""
        ECS_CLUSTER_FARGATE = "${APP_NAME}-fargate-cluster"
        ECS_SERVICE_FARGATE = "${APP_NAME}-fargate-service"
        ECS_CLUSTER_EC2     = "${APP_NAME}-ec2-cluster"
        ECS_SERVICE_EC2     = "${APP_NAME}-ec2-service"
    }
    // 2. Restructure to use proper declarative stages
    stages {
        stage('Prepare') {
            steps {
                script {
                    // Fetch AWS details and set them as environment variables
                    env.AWS_ACCOUNT_ID = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
                    env.ECR_REPOSITORY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
                }
            }
        }
        stage('Checkout') {
            steps {
                git branch: params.GIT_BRANCH, url: 'https://github.com/ClintonChe/test-repo.git'
            }
        }
        stage('Build and Push Image') {
            steps {
                sh """
                /kaniko/executor --dockerfile=Dockerfile --context=dir://\${WORKSPACE} \
                   --destination=${env.ECR_REPOSITORY}:${env.BUILD_NUMBER} \
                   --destination=${env.ECR_REPOSITORY}:latest
                """
            }
        }
        stage('Deploy to Staging') {
            steps {
                sh "aws ecs update-service --cluster ${env.ECS_CLUSTER_FARGATE} --service ${env.ECS_SERVICE_FARGATE} --force-new-deployment --region ${AWS_REGION}"
            }
        }
        stage('Deploy to Production') {
            // Only run this stage for the main branch
            when { branch 'main' }
            steps {
                input message: 'Deploy to production (EC2)?', ok: 'Deploy'
                sh "aws ecs update-service --cluster ${env.ECS_CLUSTER_EC2} --service ${env.ECS_SERVICE_EC2} --force-new-deployment --region ${AWS_REGION}"
            }
        }
    }
    // 3. Move post block to the correct top-level position
    post {
        always {
            // This ensures cleanWs runs on an agent with a workspace.
            node('master') {
                cleanWs()
            }
        }
    }
}