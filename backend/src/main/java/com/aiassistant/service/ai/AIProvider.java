package com.aiassistant.service.ai;

import reactor.core.publisher.Flux;
import java.util.List;

public interface AIProvider {
    
    AIResponse generateCompletion(AIRequest request);
    
    Flux<AIStreamResponse> streamCompletion(AIRequest request);
    
    List<Double> generateEmbedding(String text);
    
    String getProviderName();
    
    int estimateTokens(String text);
    
    double estimateCost(int inputTokens, int outputTokens);
}
