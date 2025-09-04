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

// This block runs on the Jenkins controller before the agent is allocated
// It prepares the environment variables needed to define the agent
pipeline {
    agent none // The pipeline itself doesn't use an agent yet
    stages {
        stage('Prepare Environment') {
            steps {
                script {
                    // Get essential AWS account and VPC info
                    AWS_ACCOUNT_ID = sh(returnStdout: true, script: 'aws sts get-caller-identity --query Account --output text').trim()
                    ECR_REPOSITORY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_NAME}"
                    VPC_ID = sh(returnStdout: true, script: "aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=${APP_NAME}-vpc' --query 'Vpcs[0].VpcId' --output text").trim()

                    // Dynamically look up the private subnet IDs based on tags
                    PRIVATE_SUBNET_IDS = sh(
                        returnStdout: true,
                        script: """
                        aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${APP_NAME}-private-*" --query 'Subnets[].SubnetId' --output text | tr '\\t' ','
                        """
                    ).trim()

                    // Dynamically look up the security group for the agent
                    AGENT_SECURITY_GROUP_ID = sh(
                        returnStdout: true,
                        script: "aws ec2 describe-security-groups --filters 'Name=vpc-id,Values=${VPC_ID}' 'Name=group-name,Values=jenkins-sg' --query 'SecurityGroups[0].GroupId' --output text"
                    ).trim()
                    
                    // Print the discovered values for debugging
                    echo "Found Subnets: ${PRIVATE_SUBNET_IDS}"
                    echo "Found Security Group: ${AGENT_SECURITY_GROUP_ID}"
                }
            }
        }

        // This stage runs on the dynamically provisioned ECS agent
        stage('Build and Deploy') {
            agent {
                ecs {
                    cloud 'aws-ecs'
                    label 'ecs-agent'
                    launchType 'FARGATE'
                    taskDefinition 'jenkins-agent:1'
                    // Use the variables discovered in the previous stage
                    subnets PRIVATE_SUBNET_IDS
                    securityGroups AGENT_SECURITY_GROUP_ID
                    taskrole "arn:aws:iam::${AWS_ACCOUNT_ID}:role/JenkinsAgentECSTaskRole"
                    privileged true
                }
            }
            
            environment {
                // Set environment variables for use inside the agent container
                AWS_ACCOUNT_ID      = AWS_ACCOUNT_ID
                AWS_REGION          = AWS_REGION
                ECR_REPOSITORY      = ECR_REPOSITORY
                ECS_CLUSTER_FARGATE = "${APP_NAME}-fargate-cluster"
                ECS_SERVICE_FARGATE = "${APP_NAME}-fargate-service"
                ECS_CLUSTER_EC2     = "${APP_NAME}-ec2-cluster"
                ECS_SERVICE_EC2     = "${APP_NAME}-ec2-service"
            }

            stages {
                stage('Checkout') {
                    steps {
                        // ✏️ Replace with your repository URL
                        git branch: params.GIT_BRANCH, url: 'https://github.com/ClintonChe/test-repo.git'
                    }
                }
                stage('Build & Tag Docker Image') {
                    steps {
                        sh "docker build -t ${ECR_REPOSITORY}:${env.BUILD_NUMBER} ."
                        sh "docker tag ${ECR_REPOSITORY}:${env.BUILD_NUMBER} ${ECR_REPOSITORY}:latest"
                    }
                }
                stage('Push to ECR') {
                    steps {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                            docker push ${ECR_REPOSITORY}:${env.BUILD_NUMBER}
                            docker push ${ECR_REPOSITORY}:latest
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
