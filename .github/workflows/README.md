# GitHub Actions Workflows

This directory will contain CI/CD workflows for automated testing and deployment.

## Future Workflows (Not yet implemented)

### ci.yml - Continuous Integration
- Run backend tests
- Run frontend linting
- Build Docker images
- Run security scans

### deploy.yml - Continuous Deployment
- Deploy to AWS ECS
- Update infrastructure with Terraform
- Run smoke tests

## Setup Instructions

To enable CI/CD, create workflow files here and configure GitHub Secrets:
- `OPENAI_API_KEY`
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `DOCKER_HUB_USERNAME` (optional)
- `DOCKER_HUB_TOKEN` (optional)
