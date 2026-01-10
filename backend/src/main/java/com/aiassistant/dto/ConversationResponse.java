package com.aiassistant.dto;

import com.aiassistant.model.Conversation;
import com.aiassistant.model.Message;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Data
@Builder
public class ConversationResponse {
    private Long id;
    private String title;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<MessageResponse> messages;

    public static ConversationResponse fromEntity(Conversation conversation) {
        return ConversationResponse.builder()
                .id(conversation.getId())
                .title(conversation.getTitle())
                .createdAt(conversation.getCreatedAt())
                .updatedAt(conversation.getUpdatedAt())
                .messages(conversation.getMessages().stream()
                        .map(MessageResponse::fromEntity)
                        .collect(Collectors.toList()))
                .build();
    }

    @Data
    @Builder
    public static class MessageResponse {
        private Long id;
        private String role;
        private String content;
        private Integer tokenCount;
        private String modelUsed;
        private Long processingTimeMs;
        private LocalDateTime createdAt;

        public static MessageResponse fromEntity(Message message) {
            return MessageResponse.builder()
                    .id(message.getId())
                    .role(message.getRole().name())
                    .content(message.getContent())
                    .tokenCount(message.getTokenCount())
                    .modelUsed(message.getModelUsed())
                    .processingTimeMs(message.getProcessingTimeMs())
                    .createdAt(message.getCreatedAt())
                    .build();
        }
    }
}
