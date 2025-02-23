# Tutorial Script

## Create Next.js Project

```bash
npx create-next-app@latest
```

## Create Dockerfile

**`./Dockerfile`**

```Docker
# Build Stage
## Use Node.js 22 as the base image
FROM node:22 AS builder
## Set working directory inside the container
WORKDIR /app
## Copy package.json first for caching efficiency
COPY package.json ./
## Install dependencies
RUN npm install
## Copy all source code into container
COPY . .
## Run build
RUN npm run build

# Production Stage
## Use Node.js 22 as the base image
FROM node:22
## Set working directory inside the container
WORKDIR /app
## Copy app directory from builder stage
COPY --from=builder /app ./
# Expose the port
EXPOSE 3000
# Run the application when the container starts
CMD [ "npm", "start" ]
```

**`./.dockerignore`**

```
node_modules
.git
.env
```

Build and run locally:

```bash
docker build -t nextapp_cicd_k8s .
docker run -p 3000:3000 nextapp_cicd_k8s
```

## Create ECR Repository & Push Docker Image

### Create AWS Policy with ECR

- Allow authentication and repository creation
- Push and pull container images
- List images and view repository details

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ecr:GetAuthorizationToken", "ecr:CreateRepository"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage",
        "ecr:DeleteRepository"
      ],
      "Resource": "arn:aws:ecr:<region>:<account-id>:repository/<repo-name>"
    }
  ]
}
```

### Push image to AWS ECR

1. Authenticate Docker with AWS ECR

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

2. Create repository in AWS ECR (returns JSON with repo URL)

```bash
aws ecr create-repository --repository-name <repo-name> --region <region>
```

3. Tag Your Docker Image

```bash
docker tag <repo-name>:latest <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:latest
```

4. Push Docker Image to AWS ECR

```bash
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:latest
```

## Create EKS Cluster

### Installing eksctl Using Git Bash

```bash
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=windows_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.zip"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

unzip eksctl_$PLATFORM.zip -d $HOME/bin

rm eksctl_$PLATFORM.zip
```

### Create an EKS Cluster

```bash
eksctl create cluster --name <cluster-name> --region <region> --nodegroup-name <nodegroup-name> --node-type t3.medium --nodes 2
```

### Create AWS IAM Policy for eksctl

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ec2:*",
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "elasticloadbalancing:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "cloudwatch:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "autoscaling:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": [
            "autoscaling.amazonaws.com",
            "ec2scheduled.amazonaws.com",
            "elasticloadbalancing.amazonaws.com",
            "spot.amazonaws.com",
            "spotfleet.amazonaws.com",
            "transitgateway.amazonaws.com"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": ["cloudformation:*"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "eks:*",
      "Resource": "*"
    },
    {
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": ["arn:aws:ssm:*:432575282858:parameter/aws/*", "arn:aws:ssm:*::parameter/aws/*"],
      "Effect": "Allow"
    },
    {
      "Action": ["kms:CreateGrant", "kms:DescribeKey"],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": ["logs:PutRetentionPolicy"],
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:GetInstanceProfile",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:AttachRolePolicy",
        "iam:PutRolePolicy",
        "iam:UpdateAssumeRolePolicy",
        "iam:AddRoleToInstanceProfile",
        "iam:ListInstanceProfilesForRole",
        "iam:PassRole",
        "iam:DetachRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:GetOpenIDConnectProvider",
        "iam:CreateOpenIDConnectProvider",
        "iam:DeleteOpenIDConnectProvider",
        "iam:TagOpenIDConnectProvider",
        "iam:ListAttachedRolePolicies",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:GetPolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:ListPolicyVersions"
      ],
      "Resource": [
        "arn:aws:iam::432575282858:instance-profile/eksctl-*",
        "arn:aws:iam::432575282858:role/eksctl-*",
        "arn:aws:iam::432575282858:policy/eksctl-*",
        "arn:aws:iam::432575282858:oidc-provider/*",
        "arn:aws:iam::432575282858:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
        "arn:aws:iam::432575282858:role/eksctl-managed-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["iam:GetRole", "iam:GetUser"],
      "Resource": ["arn:aws:iam::432575282858:role/*", "arn:aws:iam::432575282858:user/*"]
    },
    {
      "Effect": "Allow",
      "Action": ["iam:CreateServiceLinkedRole"],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "iam:AWSServiceName": ["eks.amazonaws.com", "eks-nodegroup.amazonaws.com", "eks-fargate.amazonaws.com"]
        }
      }
    }
  ]
}
```

### Configure kubectl for EKS

```bash
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

```bash
kubectl get nodes
```

### Create Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>-deployment
  labels:
    app: <app-name>
spec:
  replicas: 2
  selector:
    matchLabels:
      app: <app-name>
  template:
    metadata:
      labels:
        app: <app-name>
    spec:
      containers:
        - name: <app-name>
          image: <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com/<app-name>-repo:latest
          ports:
            - containerPort: 80
          imagePullPolicy: Always
      imagePullSecrets:
        - name: ecr-secret
```

### Create Image Pull Secret for AWS ECR

```bash
kubectl create secret docker-registry ecr-secret \
  --docker-server=<your-aws-account-id>.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1)
```

### Deploy the Web App

Apply the deployment:

```bash
kubectl apply -f deployment.yaml
```

Verify the deployment:

```bash
kubectl get deployments
```

### Expose the Application

Create Service to expose it:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app-name>-service
spec:
  type: LoadBalancer
  selector:
    app: <app-name>
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

Apply the service:

```
kubectl apply -f service.yaml
```

Get external IP address:

```
kubectl get svc <app-name>-service
```

Once the LoadBalancer is ready, the EXTERNAL-IP will show up, and you can access your app in the browser!

![alt text](./images/image.png)

## Automate EKS Deployment with GitHub Actions

### Step 1: Create AWS IAM User & Attach Permissions

1. Go to **AWS IAM Console** → **Users** → **Create User**
2. Name it **`GitHubActionsEKS`** or whatever you prefer
3. Attach the following **managed policies**:
   - `AmazonEKSClusterPolicy`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonEKSWorkerNodePolicy`
   - `AmazonEKSServicePolicy`
   - `IAMFullAccess` (Needed to interact with IAM roles)
   - `AmazonS3FullAccess` (Optional for storing artifacts)
4. **Generate & save** the AWS Access Key and Secret Key.

---

### Step 2: Store AWS Credentials in GitHub Secrets

Go to your **GitHub Repository** → **Settings** → **Secrets and Variables** → **Actions** → **New Repository Secret**  
Add the following secrets:

- `AWS_ACCESS_KEY_ID` → **Your IAM Access Key**
- `AWS_SECRET_ACCESS_KEY` → **Your IAM Secret Key**
- `AWS_REGION` → **e.g., us-east-1**
- `ECR_REGISTRY` → **`<your-aws-account-id>.dkr.ecr.us-east-1.amazonaws.com`**
- `ECR_REPOSITORY` → **Your ECR repository name (e.g., `webapp-repo`)**
- `EKS_CLUSTER_NAME` → **Your EKS cluster name (e.g., `my-eks-cluster`)**

---

## Step 3: Create a GitHub Actions Workflow

Inside your repository, create the GitHub Actions workflow file:

**`.github/workflows/deploy.yml`**

```yaml
name: Deploy to Amazon EKS with Rollback

on:
  push:
    branches:
      - main

jobs:
  deploy:
    name: Deploy to EKS
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Authenticate with AWS ECR
        run: |
          aws ecr get-login-password --region ${{ secrets.AWS_REGION }} | \
          docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}

      - name: Build and Push Docker Image
        run: |
          IMAGE_TAG=$(echo $GITHUB_SHA | cut -c1-7)
          docker build -t ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY }}:$IMAGE_TAG .
          docker push ${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY }}:$IMAGE_TAG
          echo "IMAGE_TAG=$IMAGE_TAG" >> $GITHUB_ENV

      - name: Update kubeconfig for EKS
        run: |
          aws eks --region ${{ secrets.AWS_REGION }} update-kubeconfig --name ${{ secrets.EKS_CLUSTER_NAME }}

      - name: Get Previous Image Tag (For Rollback)
        id: get-prev-image
        run: |
          PREV_IMAGE=$(kubectl get deployment <deployment-name> -o=jsonpath='{.spec.template.spec.containers[0].image}')
          echo "PREV_IMAGE=$PREV_IMAGE" >> $GITHUB_ENV

      - name: Deploy to Kubernetes
        id: deploy
        run: |
          kubectl set image deployment/<deployment-name> webapp=${{ secrets.ECR_REGISTRY }}/${{ secrets.ECR_REPOSITORY }}:$IMAGE_TAG
          kubectl rollout status deployment/<deployment-name> || exit 1

      - name: Rollback on Failure
        if: failure()
        run: |
          echo "Deployment failed! Rolling back to previous stable image..."
          kubectl set image deployment/<deployment-name> webapp=$PREV_IMAGE
          kubectl rollout status deployment/<deployment-name>
```

## Clean Up AWS Resources to Avoid Incurred Costs

1. Delete EKS Cluster

```
eksctl delete cluster --region=<region> --name=<cluster-name>
```

2. Delete ECR Repository

```
aws ecr delete-repository --repository-name <repo-name> --region <region> --force
```
