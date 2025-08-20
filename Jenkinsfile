pipeline {
    agent any
    
    environment {
        // These values are pre-filled from your setup
        AWS_REGION              = 'us-east-1'
        ECR_REPOSITORY          = '992382425597.dkr.ecr.us-east-1.amazonaws.com/my-app'
        ECS_CLUSTER_FARGATE     = 'my-app-fargate-cluster'
        ECS_SERVICE_FARGATE     = 'my-app-fargate-service'
        ECS_CLUSTER_EC2         = 'my-app-ec2-cluster'
        ECS_SERVICE_EC2         = 'my-app-ec2-service'
    }
    
    stages {
        stage('Checkout') {
            steps {
                // This now points to your repository
                git branch: 'main', url: 'https://github.com/ClintonChe/test-repo.git'
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    // Example for a Node.js app. Change for your project (e.g., 'mvn clean package', 'go build')
                    sh 'echo "Building application..."'
                    // sh 'npm install'
                    // sh 'npm run build'
                }
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    // Example for a Node.js app. Change for your project (e.g., 'mvn test', 'go test')
                    sh 'echo "Running tests..."'
                    // sh 'npm test'
                }
            }
        }
        
        stage('Build & Tag Docker Image') {
            steps {
                script {
                    // You must have a 'Dockerfile' in your repository for this step to work.
                    // Use the Jenkins build number as the image tag
                    def imageTag = "${env.BUILD_NUMBER}"
                    
                    // Build the Docker image
                    sh "docker build -t ${ECR_REPOSITORY}:${imageTag} ."
                    
                    // Tag the same image as 'latest'
                    sh "docker tag ${ECR_REPOSITORY}:${imageTag} ${ECR_REPOSITORY}:latest"
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    // Login to ECR and push both tags
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
                    // Force a new deployment of the service. ECS will pull the 'latest' image.
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
                // This stage will only run for builds on the 'main' branch
                branch 'main'
            }
            steps {
                // This adds a manual approval step before deploying to production
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
            // Clean up the workspace after every build
            cleanWs()
        }
    }
}
