# AI Document Assistant - Architecture Documentation

## System Overview

The AI Document Assistant is a production-grade, full-stack application that enables users to upload documents and interact with an AI assistant to ask questions about their content. The system uses Retrieval-Augmented Generation (RAG) to provide accurate, context-aware answers.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (Next.js)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Login/Auth   │  │  Document    │  │   Chat UI    │         │
│  │     Page     │  │   Upload     │  │   (Q&A)      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/REST
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Application Load Balancer (AWS ALB)                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Backend (Spring Boot)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Security Layer                                           │  │
│  │  • JWT Authentication                                     │  │
│  │  • Rate Limiting (Bucket4j)                              │  │
│  │  • Input Sanitization                                     │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Controller Layer                                         │  │
│  │  • AuthController                                         │  │
│  │  • DocumentController                                     │  │
│  │  • AIController (sync)                                    │  │
│  │  • StreamingAIController (async)                         │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Service Layer                                            │  │
│  │  • DocumentService (upload, process, chunk)              │  │
│  │  • AIAssistantService (RAG orchestration)                │  │
│  │  • StreamingAIService (SSE responses)                    │  │
│  │  • PromptService (version management)                    │  │
│  │  • AuditService (logging, compliance)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  AI Provider Layer (Abstraction)                          │  │
│  │  • AIProvider Interface                                   │  │
│  │  • OpenAIProvider (GPT-4, embeddings)                    │  │
│  │  • [Future: AnthropicProvider, AzureProvider]            │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
           │                    │                    │
           ▼                    ▼                    ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│   PostgreSQL     │  │   AWS S3         │  │  OpenAI API      │
│   (pgvector)     │  │  (Documents)     │  │  (GPT-4)         │
│                  │  │                  │  │                  │
│  • Users         │  │  • Raw files     │  │  • Completions   │
│  • Documents     │  │  • Encrypted     │  │  • Embeddings    │
│  • Chunks        │  │  • Versioned     │  │  • Streaming     │
│  • Embeddings    │  │                  │  │                  │
│  • Conversations │  └──────────────────┘  └──────────────────┘
│  • Messages      │
│  • Audit Logs    │
└──────────────────┘
```

## Technology Stack

### Frontend
- **Framework**: Next.js 14 (React 18)
- **Language**: TypeScript
- **State Management**: Zustand
- **Styling**: Tailwind CSS
- **UI Components**: Lucide React icons
- **HTTP Client**: Fetch API
- **Notifications**: react-hot-toast

### Backend
- **Framework**: Spring Boot 3.2.1
- **Language**: Java 17
- **Build Tool**: Maven
- **Web Server**: Embedded Tomcat

### Database
- **Primary**: PostgreSQL 15 with pgvector extension
- **ORM**: Spring Data JPA (Hibernate)
- **Migrations**: Hibernate DDL + init.sql

### AI/ML
- **LLM Provider**: OpenAI (GPT-4 Turbo)
- **Embeddings**: text-embedding-3-small
- **Vector Search**: pgvector (PostgreSQL extension)

### Infrastructure
- **Cloud Provider**: AWS
- **Container Orchestration**: ECS Fargate
- **Load Balancer**: Application Load Balancer
- **Storage**: S3 (documents)
- **Secrets**: AWS Secrets Manager
- **Monitoring**: CloudWatch
- **IaC**: Terraform

### Security
- **Authentication**: JWT (JSON Web Tokens)
- **Password Hashing**: BCrypt
- **Rate Limiting**: Bucket4j
- **Input Validation**: Jakarta Validation + Custom sanitization
- **CORS**: Configured per environment

## Key Design Decisions

### 1. Retrieval-Augmented Generation (RAG)

**Decision**: Use RAG pattern instead of fine-tuning
**Rationale**:
- Dynamic content: Documents change frequently
- Cost-effective: No training costs
- Transparent: Can trace answers to source documents
- Up-to-date: Always uses latest document versions

**Implementation**:
1. Document upload → Text extraction → Chunking
2. Generate embeddings for each chunk → Store in pgvector
3. On query → Generate query embedding → Similarity search
4. Retrieve top-K chunks → Include in prompt context
5. LLM generates answer based on context

### 2. AI Provider Abstraction

**Decision**: Create `AIProvider` interface with multiple implementations
**Rationale**:
- **Vendor independence**: Easy to switch providers
- **Cost optimization**: Route simple queries to cheaper models
- **Resilience**: Fallback to alternative providers
- **Testing**: Mock AI calls in tests

```java
public interface AIProvider {
    AIResponse generateCompletion(AIRequest request);
    Flux<AIStreamResponse> streamCompletion(AIRequest request);
    List<Double> generateEmbedding(String text);
}
```

### 3. Prompt Versioning

**Decision**: Store prompts as versioned text files
**Rationale**:
- **A/B testing**: Run multiple prompt versions simultaneously
- **Rollback**: Quickly revert problematic prompts
- **Audit trail**: Track changes over time
- **Separation of concerns**: Non-developers can edit prompts

**Structure**:
```
prompts/
  system_v1.txt
  question_answering_v1.txt
  document_summary_v1.txt
```

### 4. Streaming Responses

**Decision**: Implement Server-Sent Events (SSE) for AI responses
**Rationale**:
- **User experience**: Perceived performance improvement
- **Early feedback**: Users see response immediately
- **Engagement**: Keeps users engaged during long responses

**Implementation**: Spring WebFlux + Reactor for reactive streaming

### 5. Security-First Design

**Decision**: Multiple layers of security controls
**Rationale**:
- **Defense in depth**: Multiple barriers to attacks
- **Compliance**: Meets enterprise security requirements
- **Cost control**: Rate limiting prevents abuse

**Layers**:
1. JWT authentication
2. Input sanitization (prompt injection prevention)
3. Rate limiting (10 requests/minute per user)
4. Audit logging (all AI interactions)
5. Secrets management (AWS Secrets Manager)

### 6. Chunking Strategy

**Decision**: Fixed-size chunks with overlap
**Rationale**:
- **Balance**: Trade-off between context and token limits
- **Continuity**: Overlap preserves context across boundaries
- **Consistency**: Predictable token usage

**Parameters**:
- Chunk size: 1,000 characters
- Overlap: 200 characters
- Max chunks per query: 5

### 7. Cost Tracking

**Decision**: Track all AI API calls with cost calculation
**Rationale**:
- **Budget control**: Prevent runaway costs
- **User attribution**: Charge enterprise customers accurately
- **Optimization**: Identify expensive queries

**Tracked Metrics**:
- Input/output tokens
- Model used
- Response time
- Calculated cost
- User ID

### 8. Database Choice: PostgreSQL with pgvector

**Decision**: Single database for all data including vectors
**Rationale**:
- **Simplicity**: No separate vector database to manage
- **ACID compliance**: Transactional consistency
- **Cost-effective**: One database instead of two
- **Performance**: pgvector is mature and fast for our scale

**Alternative considered**: Pinecone, Weaviate
**Trade-off**: Specialized vector DBs scale better, but add complexity

### 9. Stateless Backend

**Decision**: JWT-based authentication, no server-side sessions
**Rationale**:
- **Scalability**: Horizontal scaling without session replication
- **Cloud-native**: Works well with ECS Fargate auto-scaling
- **Performance**: No session lookup overhead

### 10. Infrastructure as Code

**Decision**: Use Terraform for all AWS resources
**Rationale**:
- **Reproducibility**: Identical environments (dev/staging/prod)
- **Version control**: Infrastructure changes tracked in Git
- **Disaster recovery**: Rebuild infrastructure quickly
- **Documentation**: IaC serves as documentation

## Data Flow

### Document Upload Flow
```
1. User uploads file (PDF/TXT/DOCX) → Frontend
2. POST /api/documents/upload → Backend
3. Validate file type and size
4. Upload to S3 (with encryption)
5. Extract text (PDFBox/POI)
6. Split into chunks (1000 chars, 200 overlap)
7. Generate embeddings for each chunk → OpenAI API
8. Store document + chunks + embeddings → PostgreSQL
9. Return document metadata → Frontend
```

### Question Answering Flow
```
1. User asks question → Frontend
2. POST /api/ai/ask → Backend
3. Sanitize input (prevent prompt injection)
4. Check rate limit (Bucket4j)
5. Generate question embedding → OpenAI API
6. Vector similarity search → PostgreSQL (pgvector)
7. Retrieve top-5 relevant chunks
8. Build prompt: system + context + history + question
9. Generate completion → OpenAI API (GPT-4)
10. Store user message + AI message → PostgreSQL
11. Log audit trail
12. Return answer + metadata → Frontend
```

### Streaming Flow
```
1. User asks question → Frontend
2. POST /api/ai/stream → Backend (SSE endpoint)
3. Same steps 3-8 as above
4. Stream completion → OpenAI API
5. For each token chunk:
   - Format as SSE: "data: {chunk}\n\n"
   - Send to client → Frontend
   - Display incrementally
6. On complete: Store messages + audit log
```

## Security Considerations

### 1. Prompt Injection Prevention

**Threat**: User input that manipulates the AI to ignore instructions
**Mitigation**:
```java
private static final Pattern INJECTION_PATTERN = Pattern.compile(
    "(ignore previous|forget everything|system:|<\\|im_start\\||<\\|im_end\\||\\[INST\\]|\\[\\/INST\\])",
    Pattern.CASE_INSENSITIVE
);
```
Blocks common injection patterns, truncates long inputs (10K chars).

### 2. PII Protection

**Approach**:
- No PII in logs (configurable via `app.audit.log-pii=false`)
- Document encryption at rest (S3)
- Minimal data retention (90-day conversation TTL)
- User can delete their data

### 3. API Key Rotation

**Process**:
1. Store keys in AWS Secrets Manager
2. Application reads on startup
3. To rotate:
   - Update secret in Secrets Manager
   - Trigger ECS service restart (zero-downtime)
4. Old key remains valid during transition

### 4. Rate Limiting

**Implementation**: Token bucket algorithm (Bucket4j)
- 10 requests per minute per user
- Prevents abuse and cost overruns
- Graceful degradation (429 status code)

## Scalability

### Horizontal Scaling
- **Backend**: ECS auto-scaling based on CPU (target: 70%)
- **Database**: Read replicas for query-heavy workloads
- **Frontend**: Static assets on CloudFront CDN

### Performance Optimizations
1. **Connection pooling**: HikariCP (10 connections)
2. **Batch operations**: Hibernate batch inserts (size: 20)
3. **Lazy loading**: Documents loaded without chunks by default
4. **Indexes**: pgvector IVFFlat index on embeddings

### Bottlenecks
- **OpenAI API**: Rate limits (10K RPM for GPT-4)
- **Embeddings**: 1M tokens/minute limit
- **Database**: Write-heavy during document processing

### Mitigation
- **Queue document processing**: Process async with SQS (future)
- **Cache embeddings**: Deduplicate identical chunks
- **Fallback models**: Use GPT-3.5 when GPT-4 is rate-limited

## Monitoring and Observability

### Application Metrics
- **CloudWatch Logs**: All application logs
- **Custom metrics**:
  - AI response time (p50, p95, p99)
  - Token usage (input/output)
  - Cost per query
  - Error rates by type

### Health Checks
- **Liveness**: `/actuator/health` (ECS health check)
- **Readiness**: Checks database connectivity
- **Deep health**: Checks OpenAI API availability

### Alerting
- **Critical**: Error rate > 5%
- **Warning**: Response time p95 > 10s
- **Budget**: Daily AI cost > $200

## Testing Strategy

### Unit Tests
- Service layer logic
- Prompt rendering
- Cost calculation
- Input sanitization

### Integration Tests
- Database operations (test containers)
- API endpoints (MockMvc)
- JWT authentication flows

### AI Quality Tests
- Golden dataset (50+ Q&A pairs)
- Automated quality scoring
- Regression detection on prompt changes

## Future Enhancements

### Short-term (1-3 months)
- [ ] Frontend streaming implementation
- [ ] Document OCR support
- [ ] Multi-language support
- [ ] Conversation export (PDF/JSON)

### Medium-term (3-6 months)
- [ ] Function calling for complex queries
- [ ] Multi-modal support (images, tables)
- [ ] Fine-tuning on domain-specific data
- [ ] Background job queue (SQS + Lambda)

### Long-term (6+ months)
- [ ] Multi-tenant architecture
- [ ] Real-time collaboration
- [ ] Custom model deployment
- [ ] Advanced analytics dashboard

## Conclusion

This architecture balances production readiness with simplicity. Key strengths:
- **Scalable**: Handles 100K+ queries/month
- **Secure**: Enterprise-grade security controls
- **Cost-effective**: Optimized for <$5K/month at scale
- **Maintainable**: Clear separation of concerns
- **Extensible**: Easy to add new AI providers or features

The design prioritizes reliability, observability, and developer experience while maintaining flexibility for future enhancements.
