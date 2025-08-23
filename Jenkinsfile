pipeline {
    agent any
    environment {
        AWS_REGION              = 'us-east-1'
        ECR_REPOSITORY          = '975049911685.dkr.ecr.us-east-1.amazonaws.com/my-app'
        ECS_CLUSTER_FARGATE     = 'my-app-fargate-cluster'
        ECS_SERVICE_FARGATE     = 'my-app-fargate-service'
        ECS_CLUSTER_EC2         = 'my-app-ec2-cluster'
        ECS_SERVICE_EC2         = 'my-app-ec2-service'
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/ClintonChe/test-repo.git'
            }
        }
        stage('Build Application') {
            steps {
                script {
                    sh 'echo "Building application..."'
                }
            }
        }
        stage('Run Tests') {
            steps {
                script {
                    sh 'echo "Running tests..."'
                }
            }
        }
        stage('Build & Tag Docker Image') {
            steps {
                script {
                    def imageTag = "${env.BUILD_NUMBER}"
                    sh "docker build -t ${ECR_REPOSITORY}:${imageTag} ."
                    sh "docker tag ${ECR_REPOSITORY}:${imageTag} ${ECR_REPOSITORY}:latest"
                }
            }
        }
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPOSITORY}
                        docker push ${ECR_REPOSITORY}:${env.BUILD_NUMBER}
                        docker push ${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        stage('Deploy to Staging (Fargate)') {
            steps {
                script {
                    sh """
                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER_FARGATE} \
                            --service ${ECS_SERVICE_FARGATE} \
                            --force-new-deployment \
                            --region ${AWS_REGION}
                    """
                }
            }
        }
        stage('Deploy to Production (EC2)') {
            when {
                branch 'main'
            }
            steps {
                input message: 'Deploy to production (EC2)?', ok: 'Deploy'
                script {
                    sh """
                        aws ecs update-service \
                            --cluster ${ECS_CLUSTER_EC2} \
                            --service ${ECS_SERVICE_EC2} \
                            --force-new-deployment \
                            --region ${AWS_REGION}
                    """
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
