// Define parameters with default empty values
parameters {
    string(name: 'GIT_BRANCH', defaultValue: 'main', description: 'The Git branch to build')
}

// Global environment variables
def AWS_REGION = 'us-east-1'
def APP_NAME = 'my-app'
def AWS_ACCOUNT_ID
def ECR_REPOSITORY
def VPC_ID
def PRIVATE_SUBNET_IDS
def AGENT_SECURITY_GROUP_ID

pipeline {
    agent none 
    stages {
        stage('Prepare Environment') {
            agent {
                ecs {
                    label 'ecs-agent'
                    launchType 'FARGATE'
                    image 'jenkins-agent:1'
                }
            }
            steps {
                script {
                    AWS_ACCOUNT_ID = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
                    ECR_REPOSITORY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
                    VPC_ID = sh(returnStdout: true, script: "aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=${APP_NAME}-vpc' --query 'Vpcs[0].VpcId' --output text").trim()
                    PRIVATE_SUBNET_IDS = sh(returnStdout: true, script: "aws ec2 describe-subnets --filters 'Name=vpc-id,Values=${VPC_ID}' 'Name=tag:Name,Values=${APP_NAME}-private-*' --query 'Subnets[].SubnetId' --output text | tr '\\t' ','").trim()
                    AGENT_SECURITY_GROUP_ID = sh(returnStdout: true, script: "aws ec2 describe-security-groups --filters 'Name=vpc-id,Values=${VPC_ID}' 'Name=group-name,Values=jenkins-sg' --query 'SecurityGroups[0].GroupId' --output text").trim()
                }
            }
        }
        stage('Build and Deploy') {
            agent {
                ecs {
                    label 'ecs-agent'
                    launchType 'FARGATE'
                    image 'jenkins-agent:1'
                    subnets PRIVATE_SUBNET_IDS
                    securityGroups AGENT_SECURITY_GROUP_ID
                    taskrole "arn:aws:iam::${AWS_ACCOUNT_ID}:role/JenkinsAgentECSTaskRole"
                }
            }
            environment {
                AWS_ACCOUNT_ID      = "${AWS_ACCOUNT_ID}"      // Added quotes
                AWS_REGION          = "${AWS_REGION}"          // Added quotes
                ECR_REPOSITORY      = "${ECR_REPOSITORY}"      // Added quotes
                ECS_CLUSTER_FARGATE = "${APP_NAME}-fargate-cluster"
                ECS_SERVICE_FARGATE = "${APP_NAME}-fargate-service"
                ECS_CLUSTER_EC2     = "${APP_NAME}-ec2-cluster"
                ECS_SERVICE_EC2     = "${APP_NAME}-ec2-service"
            }
            stages {
                stage('Checkout') {
                    steps {
                        git branch: params.GIT_BRANCH, url: 'https://github.com/your-org/your-app.git' // ✏️ Update your Git URL
                    }
                }
                stage('Build and Push Image with Kaniko') {
                    steps {
                        sh """
                        /kaniko/executor --dockerfile=Dockerfile --context=dir://\${WORKSPACE} \
                           --destination=${ECR_REPOSITORY}:${env.BUILD_NUMBER} \
                           --destination=${ECR_REPOSITORY}:latest
                        """
                    }
                }
                stage('Deploy to Staging (Fargate)') {
                    steps {
                        sh "aws ecs update-service --cluster ${ECS_CLUSTER_FARGATE} --service ${ECS_SERVICE_FARGATE} --force-new-deployment --region ${AWS_REGION}"
                    }
                }
                stage('Deploy to Production (EC2)') {
                    when { branch 'main' }
                    steps {
                        input message: 'Deploy to production (EC2)?', ok: 'Deploy'
                        sh "aws ecs update-service --cluster ${ECS_CLUSTER_EC2} --service ${ECS_SERVICE_EC2} --force-new-deployment --region ${AWS_REGION}"
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