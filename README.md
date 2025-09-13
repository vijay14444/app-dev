🚀 Step 1: Get Ready
You need an AWS account.


You need a computer with Ubuntu (Linux).
 It should have at least:


4 CPUs 🖥️


16 GB Memory 💾


Internet 🌍


Install some tools:


Docker


AWS CLI


kubectl


eksctl


Node.js


Git



🐳 Step 2: Install Tools
Run these commands one by one in terminal:
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl unzip git build-essential




curl --version

unzip -v

git --version






Install Docker:
sudo apt install docker.io -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

Check:
docker --version




Install AWS CLI:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install



aws --version


Set AWS keys:
aws configure


aws sts get-caller-identity





Install kubectl:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

kubectl version --client




Install eksctl:
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

eksctl version



Install Node.js:
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

node -v
npm -v



📦 Step 3: Get App Code
git clone https://github.com/Vennilavan12/Brain-Tasks-App.git
cd Brain-Tasks-App

Run it locally:
npm install serve
npx serve -s dist -l 3000

👉 Open browser: http://localhost:3000 🎉






🐳 Step 4: Put App in a (Docker)
Create a file called Dockerfile:
FROM public.ecr.aws/nginx/nginx:alpine
RUN rm -rf /usr/share/nginx/html/*
COPY ./Brain-Tasks-App/dist /usr/share/nginx/html
RUN rm /etc/nginx/conf.d/default.conf
RUN echo 'server { listen 3000; server_name localhost; root /usr/share/nginx/html; index index.html index.htm; location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]

Build Docker image:
docker build -t brain-tasks-app .



Run Docker:
docker run -d --name test-app -p 3001:3000 brain-tasks-app



Check in browser: http://localhost:3001 ✅




☸️ Step 5: Send App to AWS
Make a place to store images (ECR):

 aws ecr create-repository --repository-name brain-tasks-app --region us-east-1





Login to ECR:

 aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com



Tag and push image:

 docker tag brain-tasks-app:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest




☸️ Step 6: Make Kubernetes Cluster
eksctl create cluster \
  --name brain-tasks-cluster \
  --region us-east-1 \
  --nodegroup-name brain-tasks-nodes \
  --node-type t3.medium \
  --nodes 2

Check:
kubectl get nodes




☸️ Step 7: Deploy App on Kubernetes
Make file k8s/deployment.yaml (pods):
apiVersion: apps/v1
kind: Deployment
metadata:
  name: brain-tasks-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: brain-tasks-app
  template:
    metadata:
      labels:
        app: brain-tasks-app
    spec:
      containers:
      - name: brain-tasks-app
        image: <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest
        ports:
        - containerPort: 3000

Make file k8s/service.yaml (load balancer):
apiVersion: v1
kind: Service
metadata:
  name: brain-tasks-service
spec:
  selector:
    app: brain-tasks-app
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer

Apply:
kubectl apply -f k8s/deployment.yaml


kubectl apply -f k8s/service.yaml


Check:
kubectl get services

🔄 Step 8: Make Auto Deploy (CI/CD)

 👉 You change code on GitHub → Pipeline sees it → Builds Docker → Pushes to ECR → Deploys to EKS automatically.

👮 Step 8.1: Create IAM Roles (Permissions)
AWS needs "keys" to let CodePipeline, CodeBuild, and Lambda do their jobs.
📌 Role for CodePipeline
# Make trust policy
cat > codepipeline-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "codepipeline.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name CodePipelineServiceRole \
  --assume-role-policy-document file://codepipeline-trust-policy.json

Now give it power:
aws iam attach-role-policy \
  --role-name CodePipelineServiceRole \
  --policy-arn arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess


📌 Role for CodeBuild
# Trust policy
cat > codebuild-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "codebuild.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
  --role-name CodeBuildServiceRole \
  --assume-role-policy-document file://codebuild-trust-policy.json

Give it power:
aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
aws iam attach-role-policy \
  --role-name CodeBuildServiceRole \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess


📌 Role for Lambda (to deploy on EKS)
cat > lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name LambdaEKSDeployRole \
  --assume-role-policy-document file://lambda-trust-policy.json

Give it permissions:
aws iam attach-role-policy \
  --role-name LambdaEKSDeployRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole


🏗️ Step 8.2: Create CodeBuild Project
CodeBuild is like a robot chef 👩‍🍳 that cooks Docker images.
aws codebuild create-project \
  --name brain-tasks-build \
  --source type=CODEPIPELINE \
  --artifacts type=CODEPIPELINE \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_MEDIUM,privilegedMode=true \
  --service-role arn:aws:iam::<ACCOUNT_ID>:role/CodeBuildServiceRole



📝 Step 8.3: Add Buildspec File
In project root, make file buildspec.yml:
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
      - aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
  build:
    commands:
      - echo Building Docker image...
      - docker build -t brain-tasks-app:latest .
  post_build:
    commands:
      - echo Pushing Docker image...
      - docker tag brain-tasks-app:latest $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest
      - docker push $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest
      - echo Creating imagedefinitions.json...
      - printf '[{"name":"brain-tasks-app","imageUri":"%s"}]' $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/brain-tasks-app:latest > imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
    - k8s/*.yaml



🐍 Step 8.4: Make Lambda Deploy Function
This small Python code tells EKS to use the new Docker image.
Make a folder:

 mkdir lambda-deploy && cd lambda-deploy

Create lambda_function.py


Install dependencies:

 pip install boto3 kubernetes -t .
zip -r brain-tasks-deploy.zip .



Upload to AWS Lambda:

 aws lambda create-function \
  	--function-name brain-tasks-deploy \
  	--runtime python3.9 \
  	--role arn:aws:iam::<ACCOUNT_ID>:role/LambdaEKSDeployRole \
  	--handler lambda_function.lambda_handler \
  	--zip-file fileb://brain-tasks-deploy.zip \
  	--timeout 300 \
  	--memory-size 512


🔄 Step 8.5: Create CodePipeline
Make S3 bucket for pipeline files:

 aws s3 mb s3://brain-tasks-pipeline-artifacts-$(date +%s) --region us-east-1



Connect to GitHub (in AWS Console → CodePipeline → Connections).


Create pipeline JSON (pipeline-config.json):

 {
  "pipeline": {
    "name": "brain-tasks-pipeline",
    "roleArn": "arn:aws:iam::<ACCOUNT_ID>:role/CodePipelineServiceRole",
    "artifactStore": {
      "type": "S3",
      "location": "brain-tasks-pipeline-artifacts-123456789"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [{
          "name": "SourceAction",
          "actionTypeId": {
            "category": "Source",
            "owner": "AWS",
            "provider": "CodeStarSourceConnection",
            "version": "1"
          },
          "configuration": {
            "ConnectionArn": "<GITHUB_CONNECTION_ARN>",
            "FullRepositoryId": "Vennilavan12/Brain-Tasks-App",
            "BranchName": "main"
          },
          "outputArtifacts": [{"name": "SourceOutput"}]
        }]
      },
      {
        "name": "Build",
        "actions": [{
          "name": "BuildAction",
          "actionTypeId": {
            "category": "Build",
            "owner": "AWS",
            "provider": "CodeBuild",
            "version": "1"
          },
          "configuration": {
            "ProjectName": "brain-tasks-build"
          },
          "inputArtifacts": [{"name": "SourceOutput"}],
          "outputArtifacts": [{"name": "BuildOutput"}]
        }]
      },
      {
        "name": "Deploy",
        "actions": [{
          "name": "DeployAction",
          "actionTypeId": {
            "category": "Invoke",
            "owner": "AWS",
            "provider": "Lambda",
            "version": "1"
          },
          "configuration": {
            "FunctionName": "brain-tasks-deploy"
          },
          "inputArtifacts": [{"name": "BuildOutput"}]
        }]
      }
    ]
  }
}

Create pipeline:

 aws codepipeline create-pipeline --cli-input-json file://pipeline-config.json


✅ Now:
Push new code → Pipeline runs → Docker built → ECR updated → Lambda deploys → App live on EKS 🎉

🔍 Step 9: Testing and Monitoring

🧪 Step 9.1: Test the Pipeline
First, run the pipeline by hand:
aws codepipeline start-pipeline-execution --name brain-tasks-pipeline



👉 This tells AWS: “Start my pipeline now.”
Check status:
aws codepipeline get-pipeline-state --name brain-tasks-pipeline



If you want details:
EXECUTION_ID=$(aws codepipeline list-pipeline-executions \
  --pipeline-name brain-tasks-pipeline \
  --query 'pipelineExecutionSummaries[0].pipelineExecutionId' \
  --output text)

aws codepipeline get-pipeline-execution \
  --pipeline-name brain-tasks-pipeline \
  --pipeline-execution-id $EXECUTION_ID

✅ If it says "Succeeded" → Yay, pipeline is working 🎉



🏥 Step 9.2: Check App Health
See if Kubernetes pods are healthy:
kubectl get deployments
kubectl get services
kubectl get pods -l app=brain-tasks-app



Check if LoadBalancer URL works:
kubectl get service brain-tasks-service --watch



http://ac27429c15cba47fd8947e17ad8df5ea-401160232.us-east-1.elb.amazonaws.com/






🧑‍🔧 Step 9.3: Test Full End-to-End Flow
Make a small change in your GitHub repo:
echo "# Test change $(date)" >> README.md
git add .
git commit -m "Testing pipeline trigger $(date)"
git push origin main

Now pipeline will start automatically → build new image → push → deploy.
 Wait ~5 minutes ⏳ then refresh app URL → you should see changes 🎉

📊 Step 9.4: Setup Monitoring in CloudWatch
Think of CloudWatch as a security camera 👀 watching your app.
Create Log Groups
aws logs create-log-group --log-group-name /aws/codebuild/brain-tasks-build
aws logs create-log-group --log-group-name /aws/codepipeline/brain-tasks-pipeline
aws logs create-log-group --log-group-name /aws/lambda/brain-tasks-deploy
aws logs create-log-group --log-group-name /aws/eks/brain-tasks-app

Set logs to delete after 30 days (so they don’t cost too much):
aws logs put-retention-policy --log-group-name /aws/codebuild/brain-tasks-build --retention-in-days 30
aws logs put-retention-policy --log-group-name /aws/codepipeline/brain-tasks-pipeline --retention-in-days 30
aws logs put-retention-policy --log-group-name /aws/lambda/brain-tasks-deploy --retention-in-days 30
aws logs put-retention-policy --log-group-name /aws/eks/brain-tasks-app --retention-in-days 7


🚨 Step 9.5: Create Alarms
So AWS can shout at you 🔔 if something is wrong.
Example: If pipeline fails
aws cloudwatch put-metric-alarm \
  --alarm-name "BrainTasks-PipelineFailure" \
  --alarm-description "Alert when pipeline fails" \
  --metric-name ExecutionFailed \
  --namespace AWS/CodePipeline \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=PipelineName,Value=brain-tasks-pipeline \
  --evaluation-periods 1





📊 Step 9.6: Create Dashboard
One screen to see everything.
aws cloudwatch put-dashboard \
  --dashboard-name "BrainTasksApp-Pipeline" \
  --dashboard-body file://dashboard-config.json

Now open AWS Console → CloudWatch → Dashboards → “BrainTasksApp-Pipeline”
 👉 You’ll see pipeline status, build success/fail, and logs.






