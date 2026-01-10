package com.aiassistant.dto;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class QuestionResponse {
    private String answer;
    private Long conversationId;
    private String model;
    private Integer tokensUsed;
    private Double cost;
    private Long responseTimeMs;
}
