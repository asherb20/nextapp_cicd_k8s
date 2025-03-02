# Tutorial Script

## Task 1. Create Next.js Project

### Step 1. Create Next App

```bash
npx create-next-app@latest
```

## Task 2. Create Dockerfile

### Step 1. Create Dockerfile

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

### Step 2. Create dockerignore file

**`./.dockerignore`**

```
node_modules
.git
.env
```

### Step 3. Build and Run Docker Locally

```bash
docker build -t <image_name> .
docker run -p 3000:3000 <image_name>
```

## Task 3. Create ECR Repository & Push Docker Image

### Step 1. Create AWS Policy with ECR

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

### Step 2. Push image to AWS ECR

1. Authenticate Docker with AWS ECR

```bash
aws ecr get-login-password --region <aws-region> | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com
```

2. Create repository in AWS ECR (returns JSON with repo URL)

```bash
aws ecr create-repository --repository-name <repo-name> --region <aws-region>
```

3. Tag Your Docker Image

```bash
docker tag <repo-name>:latest <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com/<repo-name>:latest
```

4. Push Docker Image to AWS ECR

```bash
docker push <aws-account-id>.dkr.ecr.<aws-region>.amazonaws.com/<repo-name>:latest
```

## Task 4. Create EKS Cluster

### Step 1. Install eksctl

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

### Step 2. Create an EKS Cluster

```bash
eksctl create cluster --name <cluster-name> --region <aws-region> --nodegroup-name <nodegroup-name> --node-type t3.medium --nodes 2
```

### Step 3. Configure AWS IAM Policies

1. Navigate to **IAM** and then to **Policies**
2. Create a new policy named `EksAllAccess` with the following JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "eks:*",
      "Resource": "*"
    },
    {
      "Action": ["ssm:GetParameter", "ssm:GetParameters"],
      "Resource": ["arn:aws:ssm:*:<account_id>:parameter/aws/*", "arn:aws:ssm:*::parameter/aws/*"],
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
    }
  ]
}
```

3. Create another policy named `IAMLimitedAccess` with the following JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
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
        "arn:aws:iam::<account_id>:instance-profile/eksctl-*",
        "arn:aws:iam::<account_id>:role/eksctl-*",
        "arn:aws:iam::<account_id>:policy/eksctl-*",
        "arn:aws:iam::<account_id>:oidc-provider/*",
        "arn:aws:iam::<account_id>:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup",
        "arn:aws:iam::<account_id>:role/eksctl-managed-*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["iam:GetRole", "iam:GetUser"],
      "Resource": ["arn:aws:iam::<account_id>:role/*", "arn:aws:iam::<account_id>:user/*"]
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

4. Navigate to the AWS IAM role you are authenticated with locally
5. Add the following AWS managed IAM policies plus the custom policies you just created:

   - `AmazonEC2FullAccess`
   - `AWSCloudFormationFullAccess`
   - `EksAllAccess`
   - `IAMLimitedAccess`

### Task 5. Configure kubectl for EKS

1. Update EKS cluster configuration

```bash
aws eks --region <region> update-kubeconfig --name <cluster-name>
```

2. Get cluster nodes

```bash
kubectl get nodes
```

3. Create Kubernetes Deployment file

**`./deployment.yaml`**

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

4. Create Image Pull Secret for AWS ECR

```bash
kubectl create secret docker-registry ecr-secret --docker-server=<your-aws-account-id>.dkr.ecr.<region>.amazonaws.com --docker-username=AWS --docker-password=$(aws ecr get-login-password --region <region>)
```

5. Apply the deployment

```bash
kubectl apply -f deployment.yaml
```

6. Verify the deployment

```bash
kubectl get deployments
```

7. Create service file to expose the app

**`./service.yaml`**

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

8. Apply the service

```bash
kubectl apply -f service.yaml
```

9. Get external IP address

```bash
kubectl get svc <app-name>-service
```

10. Once the LoadBalancer is ready, the EXTERNAL-IP will show up, and you can access your app in the browser!

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

### Step 3: Create a GitHub Actions Workflow

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

      - name: Update kubeconfig for EKS and create ECR secret
        run: |
          aws eks --region ${{ secrets.AWS_REGION }} update-kubeconfig --name ${{ secrets.EKS_CLUSTER_NAME }}
					kubectl create secret docker-registry ecr-secret --docker-server=${{ secrets.ECR_REPOSITORY }} --docker-username=AWS --docker-password=$(aws ecr get-login-password --region ${{ secrets.AWS_REGION }})

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

### (Optional) Step 4. Map GitHubActionsEKS IAM Identity to EKS Cluster

**This step is only necessary if the IAM profile used to create the cluster is different than the GitHubActionsEKS profile.**

- Check cluster IAM identity mapping:

```bash
eksctl get iamidentitymapping --cluster <cluster-name>
```

- Create IAM identity mapping:

```bash
eksctl create iamidentitymapping --cluster <cluster-name> --region <region> --arn arn:aws:iam::<aws-account-id>:user/<aws-iam-username> --group system:masters --no-duplicate-arns --username <aws-iam-username>
```

- Update the **kubeconfig** file:

```bash
aws eks update-kubeconfig --name <eks-cluster-name> --region <aws-region>
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
