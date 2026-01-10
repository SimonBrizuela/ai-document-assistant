package com.aiassistant.dto;

import com.aiassistant.model.Document;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class DocumentResponse {
    private Long id;
    private String filename;
    private String originalFilename;
    private String contentType;
    private Long fileSize;
    private String processingStatus;
    private String processingError;
    private LocalDateTime createdAt;
    private LocalDateTime processedAt;
    private Integer chunkCount;

    public static DocumentResponse fromEntity(Document document) {
        return DocumentResponse.builder()
                .id(document.getId())
                .filename(document.getFilename())
                .originalFilename(document.getOriginalFilename())
                .contentType(document.getContentType())
                .fileSize(document.getFileSize())
                .processingStatus(document.getProcessingStatus().name())
                .processingError(document.getProcessingError())
                .createdAt(document.getCreatedAt())
                .processedAt(document.getProcessedAt())
                .chunkCount(document.getChunks().size())
                .build();
    }
}
