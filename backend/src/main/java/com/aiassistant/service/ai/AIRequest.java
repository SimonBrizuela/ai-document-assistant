package com.aiassistant.service.ai;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AIRequest {
    
    private String systemPrompt;
    private String userPrompt;
    private List<ChatMessage> messages;
    private String model;
    private Integer maxTokens;
    private Double temperature;
    private Integer topK;
    private Double topP;
    private List<String> stopSequences;
    
    @Data
    @Builder
    public static class ChatMessage {
        private String role;
        private String content;
    }
}
