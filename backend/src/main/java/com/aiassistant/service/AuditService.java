package com.aiassistant.service;

import com.aiassistant.model.AuditLog;
import com.aiassistant.model.User;
import com.aiassistant.repository.AuditLogRepository;
import com.aiassistant.service.ai.AIResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuditService {

    private final AuditLogRepository auditLogRepository;

    @Transactional
    public void logAIInteraction(User user, String action, AIResponse response, String input) {
        try {
            AuditLog auditLog = AuditLog.builder()
                    .userId(user.getId())
                    .action(action)
                    .entityType("AI_INTERACTION")
                    .inputHash(hashInput(input))
                    .tokenCount(response.getInputTokens() + response.getOutputTokens())
                    .cost(response.getCost())
                    .modelUsed(response.getModel())
                    .promptVersion("v1")
                    .responseTimeMs(response.getResponseTimeMs())
                    .success(true)
                    .build();

            auditLogRepository.save(auditLog);
        } catch (Exception e) {
            log.error("Failed to create audit log", e);
        }
    }

    @Transactional
    public void logAction(User user, String action, String entityType, Long entityId, boolean success, String errorMessage) {
        try {
            AuditLog auditLog = AuditLog.builder()
                    .userId(user != null ? user.getId() : null)
                    .action(action)
                    .entityType(entityType)
                    .entityId(entityId)
                    .success(success)
                    .errorMessage(errorMessage)
                    .build();

            auditLogRepository.save(auditLog);
        } catch (Exception e) {
            log.error("Failed to create audit log", e);
        }
    }

    private String hashInput(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            log.error("Failed to hash input", e);
            return "";
        }
    }
}
