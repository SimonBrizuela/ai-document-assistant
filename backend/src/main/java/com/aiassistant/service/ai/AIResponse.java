package com.aiassistant.service.ai;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class AIResponse {
    
    private String content;
    private String model;
    private int inputTokens;
    private int outputTokens;
    private double cost;
    private long responseTimeMs;
    private String finishReason;
    private Double confidenceScore;
}
