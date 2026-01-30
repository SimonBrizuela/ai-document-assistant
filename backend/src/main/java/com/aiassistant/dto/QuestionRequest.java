package com.aiassistant.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

@Data
public class QuestionRequest {
    
    @NotBlank(message = "Question is required")
    private String question;
    
    private Long conversationId;
    private List<Long> documentIds;
}
