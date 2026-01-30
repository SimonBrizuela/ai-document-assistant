# AI Document Assistant

> A production-grade, AI-powered document Q&A system using Retrieval-Augmented Generation (RAG)

[![Java](https://img.shields.io/badge/Java-17-orange.svg)](https://www.oracle.com/java/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.2.1-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![React](https://img.shields.io/badge/React-18-blue.svg)](https://reactjs.org/)
[![Next.js](https://img.shields.io/badge/Next.js-14-black.svg)](https://nextjs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![AWS](https://img.shields.io/badge/AWS-Deployed-orange.svg)](https://aws.amazon.com/)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [AI Design Choices](#ai-design-choices)
- [Security](#security)
- [Cost Estimation](#cost-estimation)
- [Documentation](#documentation)
- [License](#license)

## 🎯 Overview

AI Document Assistant allows users to upload documents (PDF, TXT, DOCX) and ask questions about their content. The system uses OpenAI's GPT-4 with Retrieval-Augmented Generation (RAG) to provide accurate, context-aware answers backed by the actual document content.

**Key Capabilities:**
- Upload and process documents with automatic text extraction
- Ask questions in natural language
- Get AI-powered answers with source citations
- Stream responses in real-time
- Maintain conversation history
- Track usage and costs

## ✨ Features

### Core Features
- ✅ **Document Upload & Processing**: PDF, TXT, DOCX support with automatic chunking
- ✅ **AI-Powered Q&A**: GPT-4 integration with RAG pattern
- ✅ **Real-time Streaming**: Server-Sent Events for token-by-token responses
- ✅ **Conversation Management**: Persistent chat history with context
- ✅ **User Authentication**: JWT-based secure authentication
- ✅ **Document Management**: Upload, view, delete documents

### AI-Specific Features
- ✅ **Provider Abstraction**: Easy switching between OpenAI, Anthropic, etc.
- ✅ **Prompt Versioning**: Version-controlled prompt templates
- ✅ **Vector Search**: pgvector for semantic similarity search
- ✅ **Input Sanitization**: Prompt injection prevention
- ✅ **Cost Tracking**: Token usage and cost monitoring
- ✅ **Rate Limiting**: Per-user request throttling

### Production Features
- ✅ **Infrastructure as Code**: Complete Terraform setup for AWS
- ✅ **Container Deployment**: Docker + ECS Fargate
- ✅ **Auto-scaling**: CPU-based horizontal scaling
- ✅ **Monitoring**: CloudWatch logs and metrics
- ✅ **Secrets Management**: AWS Secrets Manager integration
- ✅ **High Availability**: Multi-AZ deployment (production)

## 🏗️ Architecture

A production-ready AI-powered full-stack application that enables users to upload documents and interact with an AI assistant to ask questions about their content using Retrieval-Augmented Generation (RAG).

## Architecture Overview

### Technology Stack

**Backend:**
- Java 17 with Spring Boot 3.2
- PostgreSQL for structured data
- Vector store integration for embeddings (pgvector)
- JWT authentication
- OpenAPI/Swagger documentation

**Frontend:**
- React with Next.js 14
- TypeScript
- Tailwind CSS for styling
- React Query for data fetching

**Infrastructure:**
- AWS (ECS, RDS, S3, Secrets Manager)
- Terraform for IaC
- Docker containerization

### Key Features

1. **Document Management**
   - Upload documents (PDF, TXT, DOCX)
   - Store in S3 with metadata in PostgreSQL
   - Automatic text extraction and chunking

2. **AI-Powered Q&A**
   - RAG-based question answering
   - Context-aware responses
   - Streaming responses for better UX
   - Conversation history tracking

3. **Security**
   - JWT-based authentication
   - Input sanitization and validation
   - Prompt injection prevention
   - Rate limiting per user

4. **Production-Ready**
   - Comprehensive error handling
   - Logging and auditability
   - Cost tracking and monitoring
   - Scalable architecture

## AI Design Decisions

### 1. Provider Abstraction
The AI service layer abstracts LLM providers through the `AIProvider` interface, allowing seamless switching between OpenAI, Anthropic, AWS Bedrock, or others without changing business logic.

### 2. Prompt Management
- Prompts are versioned and stored separately from code
- Template-based system with variable substitution
- Version tracking for A/B testing and rollback

### 3. Security Measures
- Input sanitization before prompt construction
- Maximum token limits to prevent abuse
- Content filtering for harmful requests
- Audit logging of all AI interactions

### 4. Cost Control
- Token counting before API calls
- Per-user rate limiting (configurable)
- Caching of common queries
- Budget alerts via CloudWatch

### 5. RAG Implementation
- Documents chunked into semantic segments
- Embeddings stored in pgvector
- Similarity search for relevant context
- Reranking for optimal results

## Project Structure

```
.
├── backend/                    # Spring Boot application
│   ├── src/main/java/com/aiassistant/
│   │   ├── config/            # Configuration classes
│   │   ├── controller/        # REST API controllers
│   │   ├── service/           # Business logic
│   │   │   ├── ai/           # AI service abstraction
│   │   │   ├── document/     # Document processing
│   │   │   └── auth/         # Authentication
│   │   ├── repository/        # Data access layer
│   │   ├── model/            # Domain models
│   │   ├── dto/              # Data transfer objects
│   │   └── security/         # Security configuration
│   ├── src/main/resources/
│   │   ├── prompts/          # Prompt templates
│   │   └── application.yml    # Configuration
│   └── Dockerfile
├── frontend/                   # Next.js application
│   ├── src/
│   │   ├── app/              # App router pages
│   │   ├── components/       # React components
│   │   ├── hooks/            # Custom hooks
│   │   ├── lib/              # Utilities
│   │   └── types/            # TypeScript types
│   ├── public/
│   └── Dockerfile
├── infrastructure/             # Terraform IaC
│   ├── modules/
│   │   ├── networking/
│   │   ├── compute/
│   │   ├── database/
│   │   └── storage/
│   └── environments/
│       ├── dev/
│       └── prod/
└── docs/                      # Documentation
    ├── ARCHITECTURE.md
    ├── AI_DESIGN.md
    ├── DEPLOYMENT.md
    └── API.md
```

## Local Development Setup

### Prerequisites
- Java 17+
- Node.js 18+
- Docker and Docker Compose
- PostgreSQL 15+ (or use Docker)
- AWS CLI (for deployment)

### Environment Variables

Create `.env` files in backend and frontend directories:

**Backend (.env):**
```env
# Database
DATABASE_URL=jdbc:postgresql://localhost:5432/aiassistant
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=your_password

# AI Provider
AI_PROVIDER=openai
OPENAI_API_KEY=sk-your-key-here

# JWT
JWT_SECRET=your-secret-key-here
JWT_EXPIRATION=86400000

# AWS (for production)
AWS_REGION=us-east-1
AWS_S3_BUCKET=ai-assistant-documents
```

**Frontend (.env.local):**
```env
NEXT_PUBLIC_API_URL=http://localhost:8080/api
```

### Running with Docker Compose

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Running Manually

**Backend:**
```bash
cd backend
./mvnw spring-boot:run
```

**Frontend:**
```bash
cd frontend
npm install
npm run dev
```

**Database:**
```bash
# Using Docker
docker run -d \
  --name postgres-ai \
  -e POSTGRES_DB=aiassistant \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  pgvector/pgvector:pg15
```

## API Documentation

Once running, access Swagger UI at: `http://localhost:8080/swagger-ui.html`

### Key Endpoints

**Authentication:**
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login and get JWT token

**Documents:**
- `POST /api/documents/upload` - Upload a document
- `GET /api/documents` - List user's documents
- `GET /api/documents/{id}` - Get document details
- `DELETE /api/documents/{id}` - Delete document

**AI Assistant:**
- `POST /api/ai/ask` - Ask question about documents
- `GET /api/ai/conversations` - Get conversation history
- `GET /api/ai/stream` - Server-Sent Events for streaming

## Data & Privacy

### Data Storage

**What We Store:**
- User credentials (hashed)
- Document metadata (filename, size, upload date)
- Document embeddings (vectors)
- Conversation history (questions and answers)
- Usage metrics (tokens, cost per request)

**What We Don't Store:**
- Raw AI API responses (only processed outputs)
- Temporary processing data
- User session data beyond JWT

### Data Retention

- Documents: Until user deletion
- Conversations: 90 days (configurable)
- Audit logs: 1 year
- Metrics: 30 days detailed, 1 year aggregated

### PII Handling

1. **Detection:** Regex-based PII detection before AI processing
2. **Redaction:** Automatic masking of sensitive data
3. **Logging:** PII excluded from logs
4. **Compliance:** GDPR-ready with data export/deletion

### Auditability

All AI interactions logged with:
- User ID
- Timestamp
- Input hash (not raw content)
- Model and version used
- Token count and cost
- Response time

## AI Evaluation & Reliability

### Quality Measurement

1. **Automated Metrics:**
   - Response relevance score (cosine similarity)
   - Answer completeness (keyword coverage)
   - Response time tracking
   - Token efficiency ratio

2. **Human Evaluation:**
   - Thumbs up/down feedback
   - Report incorrect answers
   - User satisfaction surveys

### Regression Detection

1. **Prompt Versioning:**
   - Each prompt change gets a version tag
   - A/B testing framework included
   - Automatic rollback on quality degradation

2. **Monitoring:**
   - Quality metrics tracked per prompt version
   - Alerts on >10% quality drop
   - Daily summary reports

3. **Testing:**
   - Golden dataset for regression testing
   - Automated evaluation on prompt changes
   - Compare outputs across versions

### Handling Wrong Answers

**Prevention:**
- Include confidence scores in responses
- "I don't know" threshold tuning
- Cite sources from documents

**Detection:**
- User feedback collection
- Anomaly detection on metrics
- Periodic human review

**Response:**
1. Flag for review
2. Add to test dataset
3. Adjust prompts/parameters
4. Notify affected users if critical

## Infrastructure & Deployment

### AWS Architecture

```
Internet
    |
    v
[CloudFront] --> [S3 Static Frontend]
    |
    v
[Application Load Balancer]
    |
    v
[ECS Fargate Cluster]
    |
    +-- [Backend Tasks] --> [RDS PostgreSQL]
    |                   --> [S3 Documents]
    |                   --> [Secrets Manager]
    |                   --> [CloudWatch]
    |
    v
[OpenAI API / AWS Bedrock]
```

### Secret Management

**Development:**
- Local `.env` files (gitignored)
- Docker secrets for compose

**Production:**
- AWS Secrets Manager for API keys
- IAM roles for service authentication
- Automatic rotation for DB credentials
- KMS encryption at rest

**Key Rotation:**
1. Store new key in Secrets Manager
2. Update without downtime (dual-key support)
3. Monitor for usage of old key
4. Deprecate old key after 24h

### Scaling Strategy

**API Scaling:**
- ECS auto-scaling based on CPU/memory
- Target: 70% utilization
- Min: 2 tasks, Max: 20 tasks

**AI Workload Specific:**
- Separate task definition for AI endpoints
- Higher memory allocation (2GB vs 512MB)
- Longer timeout (60s vs 30s)
- Queue-based async processing for heavy tasks

**Database:**
- RDS with read replicas
- Connection pooling (HikariCP)
- pgvector index optimization

**Bursty Traffic:**
- SQS queue for non-urgent AI tasks
- Lambda for document preprocessing
- CloudFront caching for static content

## Deployment Instructions

### Terraform Setup

```bash
cd infrastructure/environments/dev

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply infrastructure
terraform apply

# Get outputs
terraform output
```

### Docker Deployment

```bash
# Build images
docker build -t ai-assistant-backend ./backend
docker build -t ai-assistant-frontend ./frontend

# Tag for ECR
docker tag ai-assistant-backend:latest \
  123456789.dkr.ecr.us-east-1.amazonaws.com/ai-assistant-backend:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789.dkr.ecr.us-east-1.amazonaws.com

docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/ai-assistant-backend:latest
```

## Cost Estimation

### Per Request Breakdown

**Small Document Query (1K tokens):**
- OpenAI GPT-4: $0.03
- Anthropic Claude: $0.024
- AWS Bedrock: $0.012

**Average Costs:**
- 1K requests/month: $30-50
- 10K requests/month: $300-500
- 100K requests/month: $3,000-5,000

**Infrastructure (AWS):**
- ECS: ~$50/month (2 tasks)
- RDS: ~$100/month (db.t3.medium)
- S3: ~$10/month (100GB)
- Data transfer: ~$20/month

**Total Monthly Cost:**
- 1K users: ~$200-300
- 10K users: ~$600-800
- 100K users: ~$3,500-5,500

### Optimization Strategies

1. Semantic caching (30% reduction)
2. Cheaper models for simple queries
3. Batch processing
4. Response streaming (better UX, same cost)

## Trade-offs & Limitations

### Current Limitations

1. **Document Size:** Max 10MB per document
2. **Concurrent Users:** Optimized for <1000 simultaneous
3. **Languages:** Primarily English (expandable)
4. **File Types:** PDF, TXT, DOCX only

### Design Trade-offs

1. **PostgreSQL with pgvector vs Dedicated Vector DB:**
   - Chosen: PostgreSQL (simpler ops, good enough for <1M docs)
   - Trade-off: Slightly slower for huge scale

2. **Synchronous vs Async AI Calls:**
   - Chosen: Sync with streaming (better UX)
   - Trade-off: Higher memory per request

3. **Monorepo vs Separate Repos:**
   - Chosen: Monorepo (easier to maintain for small team)
   - Trade-off: Larger CI/CD pipelines

4. **Spring Boot vs Node.js:**
   - Chosen: Spring Boot (better for enterprise, type safety)
   - Trade-off: Higher memory footprint

### Known Issues

- Vector similarity search needs optimization for >100K documents
- No multi-tenancy isolation (single database)
- Rate limiting is per-user, not per-organization

## Testing

```bash
# Backend tests
cd backend
./mvnw test

# Frontend tests
cd frontend
npm test

# Integration tests
docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

## Contributing

See CONTRIBUTING.md for development workflow.

## License

MIT License - see LICENSE file.
