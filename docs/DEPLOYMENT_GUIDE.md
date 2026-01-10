# Deployment Guide

## Local Development

### Using Docker Compose (Recommended)

1. **Clone and setup**:
```bash
git clone <repository-url>
cd ai-document-assistant
cp .env.example .env
```

2. **Configure environment variables**:
Edit `.env` file:
```bash
OPENAI_API_KEY=sk-your-key-here
JWT_SECRET=your-secure-secret-min-256-bits
```

3. **Start services**:
```bash
docker-compose up -d
```

4. **Verify deployment**:
```bash
# Check all services are running
docker-compose ps

# Check backend logs
docker-compose logs -f backend

# Test health endpoint
curl http://localhost:8080/actuator/health
```

5. **Access application**:
- Frontend: http://localhost:3000
- Backend: http://localhost:8080
- API Docs: http://localhost:8080/swagger-ui.html

### Manual Setup

See [docs/ARCHITECTURE.md](ARCHITECTURE.md) for detailed manual setup instructions.

## AWS Production Deployment

### Prerequisites

1. **AWS CLI** configured with credentials
2. **Terraform** >= 1.0 installed
3. **Docker** for building images
4. **OpenAI API key**

### Step-by-Step Deployment

#### 1. Configure Terraform

```bash
cd infrastructure/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
vim terraform.tfvars
```

Set these values:
```hcl
aws_region = "us-east-1"
environment = "prod"
project_name = "ai-document-assistant"

db_instance_class = "db.t3.small"
ecs_task_cpu = "1024"
ecs_task_memory = "2048"
```

#### 2. Set Secrets

```bash
# Set via environment variables (recommended)
export TF_VAR_openai_api_key="sk-your-key"
export TF_VAR_jwt_secret="your-secure-secret"

# Or use AWS Secrets Manager directly
aws secretsmanager create-secret \
  --name ai-assistant-openai-key \
  --secret-string "sk-your-key"
```

#### 3. Initialize Terraform

```bash
terraform init
```

#### 4. Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Review the plan carefully. Expected resources:
- VPC with public/private subnets
- RDS PostgreSQL instance
- ECS cluster and service
- Application Load Balancer
- S3 bucket for documents
- Secrets Manager secrets
- IAM roles and policies

#### 5. Apply Infrastructure

```bash
terraform apply tfplan
```

This will take 10-15 minutes. Note the outputs:
```
alb_url = "http://ai-assistant-alb-prod-123456789.us-east-1.elb.amazonaws.com"
ecr_repository_url = "123456789.dkr.ecr.us-east-1.amazonaws.com/ai-document-assistant-backend-prod"
```

#### 6. Build and Push Docker Image

```bash
# Get ECR repository URL from terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REPO

# Build backend image
cd ../../backend
docker build -t ai-document-assistant-backend .

# Tag and push
docker tag ai-document-assistant-backend:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
```

#### 7. Deploy to ECS

```bash
# Force new deployment with the new image
aws ecs update-service \
  --cluster ai-document-assistant-cluster-prod \
  --service ai-document-assistant-backend-prod \
  --force-new-deployment \
  --region us-east-1
```

#### 8. Verify Deployment

```bash
# Check service status
aws ecs describe-services \
  --cluster ai-document-assistant-cluster-prod \
  --services ai-document-assistant-backend-prod \
  --region us-east-1

# Check task logs
aws logs tail /ecs/ai-document-assistant-prod --follow

# Test health endpoint
ALB_URL=$(terraform output -raw alb_url)
curl $ALB_URL/actuator/health
```

#### 9. Configure DNS (Optional)

```bash
# Create Route53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.yourdomain.com",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "'$ALB_URL'"}]
      }
    }]
  }'
```

#### 10. Enable HTTPS (Optional)

```bash
# Request ACM certificate
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# Add HTTPS listener to ALB (requires Terraform update)
```

### Post-Deployment Tasks

#### 1. Initialize Database

```bash
# Connect to RDS instance (from bastion host or VPN)
psql -h your-rds-endpoint -U dbadmin -d aiassistant

# Run migrations if needed
\i backend/src/main/resources/db/init.sql
```

#### 2. Create First User

```bash
# Via API
curl -X POST $ALB_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "email": "admin@example.com",
    "password": "SecurePassword123!"
  }'
```

#### 3. Configure Monitoring

```bash
# Set up CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name ai-assistant-high-error-rate \
  --alarm-description "Error rate exceeds 5%" \
  --metric-name ErrorRate \
  --namespace AIAssistant \
  --statistic Average \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## CI/CD Pipeline (GitHub Actions Example)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Login to ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build and push backend
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: ai-document-assistant-backend-prod
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG backend/
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ai-document-assistant-cluster-prod \
            --service ai-document-assistant-backend-prod \
            --force-new-deployment
```

## Scaling

### Horizontal Scaling

Auto-scaling is configured by default (CPU-based). To manually scale:

```bash
aws ecs update-service \
  --cluster ai-document-assistant-cluster-prod \
  --service ai-document-assistant-backend-prod \
  --desired-count 4
```

### Vertical Scaling

Update Terraform variables:

```hcl
ecs_task_cpu = "2048"
ecs_task_memory = "4096"
```

Apply changes:
```bash
terraform apply
```

### Database Scaling

```bash
# Modify RDS instance class
aws rds modify-db-instance \
  --db-instance-identifier ai-document-assistant-db-prod \
  --db-instance-class db.t3.medium \
  --apply-immediately
```

## Monitoring

### CloudWatch Logs

```bash
# View logs
aws logs tail /ecs/ai-document-assistant-prod --follow

# Filter errors
aws logs filter-log-events \
  --log-group-name /ecs/ai-document-assistant-prod \
  --filter-pattern "ERROR"
```

### Metrics Dashboard

Access CloudWatch dashboard:
- https://console.aws.amazon.com/cloudwatch/

Key metrics to monitor:
- ECS service CPU/Memory utilization
- RDS connections and queries
- ALB request count and latency
- Custom AI metrics (cost, tokens, response time)

## Backup and Recovery

### Database Backups

```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-snapshot-identifier ai-assistant-manual-backup-$(date +%Y%m%d) \
  --db-instance-identifier ai-document-assistant-db-prod

# List snapshots
aws rds describe-db-snapshots \
  --db-instance-identifier ai-document-assistant-db-prod
```

### Restore from Backup

```bash
# Restore to new instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ai-document-assistant-db-restored \
  --db-snapshot-identifier your-snapshot-id

# Update application to point to new instance
```

## Troubleshooting

### ECS Task Fails to Start

```bash
# Check task logs
aws ecs describe-tasks \
  --cluster ai-document-assistant-cluster-prod \
  --tasks $(aws ecs list-tasks --cluster ai-document-assistant-cluster-prod --query 'taskArns[0]' --output text)

# Common issues:
# 1. Cannot pull ECR image → Check IAM permissions
# 2. Health check failing → Check application.yml configuration
# 3. Secrets not found → Verify Secrets Manager ARNs
```

### High Costs

```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --filter file://cost-filter.json

# Optimize:
# 1. Reduce ECS task count
# 2. Implement aggressive rate limiting
# 3. Use GPT-3.5 for simple queries
# 4. Enable response caching
```

### Database Connection Issues

```bash
# Test connectivity from ECS task
aws ecs execute-command \
  --cluster ai-document-assistant-cluster-prod \
  --task TASK_ID \
  --container backend \
  --interactive \
  --command "/bin/bash"

# Inside container:
telnet your-rds-endpoint 5432
```

## Cleanup

To destroy all AWS resources:

```bash
cd infrastructure/terraform
terraform destroy
```

**Warning**: This will permanently delete:
- All databases and backups
- All uploaded documents in S3
- All application logs
- All infrastructure

Always backup critical data before destroying resources.

## Security Best Practices

1. **Rotate secrets regularly** (every 90 days)
2. **Enable MFA** on AWS account
3. **Use least privilege** IAM policies
4. **Enable CloudTrail** for audit logs
5. **Enable VPC Flow Logs** for network monitoring
6. **Use AWS WAF** on ALB (optional)
7. **Enable RDS encryption** at rest
8. **Regular security patches** (use latest base images)
9. **Implement backup strategy** (daily automated backups)
10. **Set up alerting** for anomalous activity

## Cost Optimization

1. **Use Reserved Instances** for RDS (30-60% savings)
2. **Enable ECS Spot instances** for non-critical tasks
3. **Implement auto-scaling** policies
4. **Use S3 lifecycle policies** for old documents
5. **Optimize AI usage** (caching, GPT-3.5 for simple queries)
6. **Monitor and set budgets** in AWS Billing
7. **Review and remove unused resources** monthly

## Support

For issues or questions:
- Create an issue in the repository
- Check [docs/ARCHITECTURE.md](ARCHITECTURE.md) for design decisions
- Review [docs/AI_EVALUATION.md](AI_EVALUATION.md) for AI-specific guidance
