# AI Document Assistant - Terraform Infrastructure

This directory contains Terraform configurations for deploying the AI Document Assistant to AWS.

## Architecture

The infrastructure includes:

- **VPC**: Custom VPC with public and private subnets across 2 availability zones
- **ECS Fargate**: Container orchestration for the backend application
- **RDS PostgreSQL**: Managed database with pgvector extension
- **Application Load Balancer**: HTTP/HTTPS traffic distribution
- **S3**: Document storage with encryption and lifecycle policies
- **Secrets Manager**: Secure storage for API keys and credentials
- **CloudWatch**: Logging and monitoring
- **Auto Scaling**: CPU-based scaling for ECS tasks

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.0 installed
3. Docker installed (for building container images)

## Setup

1. Copy the example variables file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

2. Edit `terraform.tfvars` with your configuration values

3. Set sensitive variables via environment variables:
```bash
export TF_VAR_openai_api_key="your-openai-key"
export TF_VAR_jwt_secret="your-jwt-secret"
```

4. Initialize Terraform:
```bash
terraform init
```

5. Review the plan:
```bash
terraform plan
```

6. Apply the configuration:
```bash
terraform apply
```

## Deployment Process

### 1. Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build the backend image
cd ../../backend
docker build -t ai-document-assistant-backend .

# Tag and push
docker tag ai-document-assistant-backend:latest <ecr-repository-url>:latest
docker push <ecr-repository-url>:latest
```

### 2. Deploy Infrastructure

```bash
terraform apply
```

### 3. Access the Application

After deployment, access the application using the ALB DNS name:
```bash
terraform output alb_url
```

## Secrets Management

All sensitive data is stored in AWS Secrets Manager:

- Database credentials (auto-generated)
- OpenAI API key
- JWT secret
- Application secrets

### Rotating Secrets

To rotate the OpenAI API key:

```bash
aws secretsmanager update-secret \
  --secret-id ai-document-assistant-app-secrets-dev \
  --secret-string '{"OPENAI_API_KEY":"new-key",...}'
```

Then restart the ECS service:

```bash
aws ecs update-service \
  --cluster ai-document-assistant-cluster-dev \
  --service ai-document-assistant-backend-dev \
  --force-new-deployment
```

## Scaling

### Manual Scaling

Update the `desired_count` in `ecs.tf` or use the AWS CLI:

```bash
aws ecs update-service \
  --cluster ai-document-assistant-cluster-dev \
  --service ai-document-assistant-backend-dev \
  --desired-count 3
```

### Auto Scaling

The configuration includes CPU-based auto-scaling:
- Target: 70% CPU utilization
- Min tasks: 1 (dev) / 2 (prod)
- Max tasks: 4

## Cost Optimization

For development environments:
- Use `db.t3.micro` RDS instances
- Set `desired_count = 1` for ECS services
- Enable S3 lifecycle policies
- Use shorter log retention periods

For production:
- Use `db.t3.small` or larger RDS instances
- Set `desired_count >= 2` for high availability
- Enable RDS Multi-AZ
- Increase backup retention

## Monitoring

CloudWatch dashboards and alarms are automatically configured for:
- ECS task health
- RDS performance metrics
- ALB target health
- Application logs

Access logs:
```bash
aws logs tail /ecs/ai-document-assistant-dev --follow
```

## Disaster Recovery

### Database Backups

- Automated backups: 7 days retention
- Backup window: 03:00-04:00 UTC
- Point-in-time recovery enabled

### Restore from Backup

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ai-document-assistant-db-restored \
  --db-snapshot-identifier <snapshot-id>
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data including databases and S3 buckets.

## Security Considerations

1. **Network Security**: All application resources are in private subnets
2. **Encryption**: Data at rest (RDS, S3) and in transit (TLS)
3. **IAM**: Least privilege access for all roles
4. **Secrets**: No hardcoded credentials
5. **Monitoring**: CloudWatch logs for audit trails

## Troubleshooting

### ECS Task Not Starting

Check CloudWatch logs:
```bash
aws logs tail /ecs/ai-document-assistant-dev --follow
```

### Database Connection Issues

Verify security group rules and endpoint:
```bash
terraform output rds_endpoint
```

### Cannot Pull ECR Image

Ensure the image is pushed and the task execution role has ECR permissions.
