package com.aiassistant.service.ai;

import lombok.Builder;
import lombok.Data;
import reactor.core.publisher.Flux;

@Data
@Builder
public class AIStreamResponse {
    
    private Flux<String> contentStream;
    private String model;
    private int estimatedTokens;
}
