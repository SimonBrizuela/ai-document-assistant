# AI Design Decisions and Trade-offs

## Problem Statement

Build an AI-assisted application that allows users to submit content (documents) and interact with an AI assistant over that content, with structured outputs.

## Chosen Approach: Retrieval-Augmented Generation (RAG)

### Decision
Use RAG pattern instead of:
- Fine-tuning a model
- Using raw LLM without context
- Building a custom model

### Rationale

**Advantages of RAG:**
1. **Dynamic Content**: Documents change frequently; no retraining needed
2. **Cost-Effective**: No training costs ($1000s saved vs fine-tuning)
3. **Transparency**: Can trace answers to source documents
4. **Up-to-date**: Always uses latest document versions
5. **Accuracy**: Grounded in actual document content
6. **Flexibility**: Can be applied to any domain without specialized training

**Trade-offs Accepted:**
- Slightly higher latency (retrieval + generation vs generation only)
- Token costs for context (mitigated by chunking strategy)
- Complexity of vector database management

### Alternative Considered: Fine-tuning

**Rejected because:**
- High upfront cost ($2000+ for GPT-3.5 fine-tuning)
- Static knowledge (requires retraining for updates)
- Still needs RAG for citing sources
- Not suitable for frequently changing documents

## AI Provider Abstraction

### Decision
Create `AIProvider` interface with multiple implementations

```java
public interface AIProvider {
    AIResponse generateCompletion(AIRequest request);
    Flux<AIStreamResponse> streamCompletion(AIRequest request);
    List<Double> generateEmbedding(String text);
    String getProviderName();
}
```

### Rationale

**Benefits:**
1. **Vendor Independence**: Easy to switch from OpenAI to Anthropic/Azure
2. **Cost Optimization**: Route simple queries to cheaper models
3. **Resilience**: Automatic fallback to alternative providers
4. **Testing**: Mock AI calls without API costs

**Implementation:**
- `OpenAIProvider` for production (GPT-4, GPT-3.5)
- Future: `AnthropicProvider`, `AzureOpenAIProvider`
- Factory pattern for provider selection

### Trade-offs
- Additional abstraction layer (minimal overhead)
- Need to handle provider-specific features carefully

## Prompt Engineering Strategy

### Decision: Version-controlled prompt templates

**Structure:**
```
prompts/
  system_v1.txt           # System role instructions
  question_answering_v1.txt  # Q&A template
  document_summary_v1.txt    # Summarization template
```

### Rationale

**Benefits:**
1. **A/B Testing**: Run multiple versions simultaneously
2. **Rollback**: Quickly revert problematic prompts
3. **Non-technical Editing**: Product managers can update prompts
4. **Audit Trail**: Git history tracks all changes
5. **Version Management**: Explicit versioning (v1, v2, etc.)

**Implementation:**
```java
@Service
public class PromptService {
    public String renderPrompt(String templateName, Map<String, String> variables) {
        PromptTemplate template = templates.get(templateName);
        return template.render(variables);
    }
}
```

### Trade-offs
- File system dependency (mitigated by resource loading)
- Need to restart service for prompt updates (future: database storage)

## Chunking Strategy

### Decision: Fixed-size chunks with overlap

**Parameters:**
- Chunk size: 1,000 characters
- Overlap: 200 characters (20%)
- Max chunks per query: 5

### Rationale

**Why fixed-size:**
- Predictable token usage
- Consistent performance
- Simple implementation

**Why 1,000 characters:**
- ~250 tokens per chunk (GPT-4 tokenizer)
- 5 chunks = ~1,250 tokens (leaves room for prompt + response)
- Balance between context and specificity

**Why 200-character overlap:**
- Preserves context across boundaries
- Captures split sentences/paragraphs
- Minimal additional cost (20% overhead)

### Alternatives Considered

**Semantic chunking:**
- Split by sentences/paragraphs
- **Rejected**: Variable token counts complicate cost estimation

**Larger chunks (2000+ chars):**
- More context per chunk
- **Rejected**: Reduces retrieval precision, higher token costs

**No overlap:**
- Lower storage costs
- **Rejected**: Loses important context at boundaries

## Streaming vs Batch Responses

### Decision: Implement both

**Batch endpoint** (`/api/ai/ask`):
- Returns complete response
- Simpler implementation
- Use for programmatic access

**Streaming endpoint** (`/api/ai/stream`):
- Server-Sent Events (SSE)
- Token-by-token delivery
- Better user experience

### Rationale

**Why streaming:**
- Perceived performance (users see response immediately)
- Engagement (keeps users interested during 5-10s responses)
- Modern UX standard

**Why keep batch:**
- API integrations prefer complete responses
- Simpler error handling
- Easier to implement caching

### Implementation
```java
public Flux<AIStreamResponse> streamCompletion(AIRequest request) {
    return openAiService.streamChatCompletion(request)
        .map(chunk -> AIStreamResponse.builder()
            .content(chunk.getContent())
            .done(false)
            .build());
}
```

## Security: Prompt Injection Prevention

### Decision: Multi-layer defense

**Layer 1: Input sanitization**
```java
private static final Pattern INJECTION_PATTERN = Pattern.compile(
    "(ignore previous|forget everything|system:|<\\|im_start\\||...)",
    Pattern.CASE_INSENSITIVE
);
```

**Layer 2: Input length limits**
- Max 10,000 characters per query
- Prevents token flooding attacks

**Layer 3: Rate limiting**
- 10 requests per minute per user
- Prevents abuse and cost overruns

**Layer 4: Audit logging**
- All AI interactions logged
- Suspicious patterns detected

### Rationale

**Defense in depth:**
- No single point of failure
- Multiple chances to catch attacks

**Pattern-based detection:**
- Catches common injection attempts
- Low false positive rate
- Easy to update patterns

### Trade-offs
- May block legitimate queries (rare)
- Needs ongoing pattern updates
- Cannot catch all sophisticated attacks

## Cost Control Strategy

### Decision: Multi-faceted approach

**1. Token tracking:**
```java
public void trackAIUsage(AIResponse response) {
    double cost = response.getCost();
    costRepository.save(CostEntry.builder()
        .cost(cost)
        .tokensUsed(response.getInputTokens() + response.getOutputTokens())
        .build());
}
```

**2. Rate limiting:**
- Prevent runaway costs from abuse
- 10 requests/minute = max $28.80/user/day

**3. Model selection:**
- Use GPT-3.5 for simple queries (future)
- GPT-4 only for complex questions
- 4x cost savings

**4. Caching:**
- Cache identical questions
- Semantic cache for similar questions (future)
- 30-40% cache hit rate expected

### Trade-offs
- Rate limiting may frustrate power users (can be adjusted per tier)
- Caching adds complexity
- Model selection requires classification step

## Data Retention and Privacy

### Decision: Limited retention with user control

**Policies:**
- Conversations: 90 days
- Documents: User-controlled (no automatic deletion)
- Audit logs: 365 days
- PII: Not logged (configurable)

### Rationale

**Why 90-day conversations:**
- Balance between utility and privacy
- Reduces storage costs
- Complies with GDPR right to be forgotten

**Why user-controlled documents:**
- Users know when documents are no longer needed
- Automatic deletion risks data loss
- Storage cost is minimal (S3)

**Why 365-day audit logs:**
- Compliance requirements (SOC 2, ISO 27001)
- Security incident investigation
- Cost analysis and optimization

### Trade-offs
- Storage costs for audit logs
- Need cleanup jobs (future: Lambda)

## Vector Search: pgvector vs Specialized DB

### Decision: Use pgvector (PostgreSQL extension)

### Rationale

**Advantages:**
1. **Single database**: No separate vector DB to manage
2. **ACID compliance**: Transactions work across all data
3. **Cost-effective**: One RDS instance instead of two services
4. **Mature**: PostgreSQL is proven, pgvector is stable
5. **Simple ops**: One backup/restore process

**Performance:**
- Fast enough for <100K vectors (our scale)
- IVFFlat index for similarity search
- Sub-second query times

### Alternatives Considered

**Pinecone:**
- Pros: Purpose-built, scales to billions
- Cons: Additional service ($70+/month), data duplication
- **Rejected**: Overkill for our scale

**Weaviate/Milvus:**
- Pros: Open source, feature-rich
- Cons: Additional infrastructure, operational complexity
- **Rejected**: Not worth the overhead

### When to Reconsider

Move to specialized vector DB if:
- Vector count exceeds 1 million
- Query latency exceeds 1 second (p95)
- Need advanced features (hybrid search, filters)
- Scale justifies additional complexity

## Conversation History Management

### Decision: Store last 5 messages, send to LLM

**Storage:**
- All messages persisted in database
- Associated with conversation ID
- Includes token counts and metadata

**Context window:**
- Last 5 messages (user + assistant)
- ~500 tokens average
- Prevents context window overflow

### Rationale

**Why 5 messages:**
- Most conversations resolve in 2-3 turns
- 5 provides enough context
- Keeps token costs manageable

**Why not all messages:**
- GPT-4 has 8K token limit
- Context + response = 3-4K tokens
- Leaves room for 2-3K token history

### Trade-offs
- May lose context in long conversations
- Future: Implement conversation summarization

## Monitoring and Observability

### Decision: CloudWatch + Custom Metrics

**Built-in metrics:**
- ECS task metrics (CPU, memory)
- RDS metrics (connections, queries)
- ALB metrics (requests, latency)

**Custom metrics:**
```java
cloudWatch.putMetricData(
    namespace: "AIAssistant",
    metricName: "ResponseTime",
    value: responseTimeMs,
    unit: StandardUnit.MILLISECONDS
);
```

### Key Metrics
- AI response time (p50, p95, p99)
- Token usage (input, output)
- Cost per query
- Error rate by type
- User satisfaction (thumbs up/down)

### Trade-offs
- CloudWatch costs ($0.30 per metric/month)
- Need custom dashboards
- Alternative: Datadog ($15+/host/month) - more features but higher cost

## Deployment: ECS Fargate vs EKS vs Lambda

### Decision: ECS Fargate

### Rationale

**ECS Fargate advantages:**
1. **Simplicity**: Less complex than EKS
2. **Cost**: No EC2 management overhead
3. **Scaling**: Auto-scaling built-in
4. **Integration**: Native AWS service integration
5. **Suitable for**: Predictable workloads with <1 min cold start tolerance

**vs Lambda:**
- Lambda has 15min timeout (too short for document processing)
- Lambda cold starts not ideal for interactive queries
- ECS better for long-running processes

**vs EKS:**
- EKS more complex (K8s expertise needed)
- EKS better for multi-cloud or existing K8s infrastructure
- Not worth the complexity for our scale

### When to Reconsider

Switch to EKS if:
- Need multi-cloud portability
- Have existing Kubernetes infrastructure
- Require advanced orchestration features
- Scale exceeds ECS limits

## Summary of Key Trade-offs

| Decision | Chosen | Alternative | Trade-off |
|----------|--------|-------------|-----------|
| AI Pattern | RAG | Fine-tuning | Higher latency, lower cost |
| Vector DB | pgvector | Pinecone | Simpler, less scalable |
| Chunking | Fixed 1K chars | Semantic | Predictable, less intelligent |
| Streaming | Both batch + stream | Batch only | More complex, better UX |
| Orchestration | ECS Fargate | Lambda/EKS | Balanced simplicity vs features |
| Prompt Storage | Files | Database | Simpler, needs restart |
| LLM Provider | OpenAI | Self-hosted | Higher cost, better quality |
| Auth | JWT | Sessions | Stateless, token management |

## Conclusion

These design decisions prioritize:
1. **Production readiness** over bleeding-edge features
2. **Cost-effectiveness** over peak performance
3. **Simplicity** over maximum flexibility
4. **Transparency** over black-box solutions

The architecture is designed to scale from MVP to 100K+ users while maintaining code quality, observability, and cost efficiency.
