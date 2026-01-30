package com.aiassistant.controller;

import com.aiassistant.dto.ApiResponse;
import com.aiassistant.dto.ConversationResponse;
import com.aiassistant.dto.QuestionRequest;
import com.aiassistant.dto.QuestionResponse;
import com.aiassistant.model.Conversation;
import com.aiassistant.model.User;
import com.aiassistant.security.UserPrincipal;
import com.aiassistant.service.AIAssistantService;
import com.aiassistant.service.ai.AIResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "AI Assistant", description = "AI-powered question answering endpoints")
public class AIController {

    private final AIAssistantService aiAssistantService;

    @PostMapping("/ask")
    @Operation(summary = "Ask a question about documents")
    public ResponseEntity<QuestionResponse> askQuestion(
            @Valid @RequestBody QuestionRequest request,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        try {
            User user = User.builder().id(userPrincipal.getId()).build();
            AIResponse aiResponse = aiAssistantService.askQuestion(
                    request.getQuestion(),
                    user,
                    request.getConversationId(),
                    request.getDocumentIds()
            );

            QuestionResponse response = QuestionResponse.builder()
                    .answer(aiResponse.getContent())
                    .conversationId(request.getConversationId())
                    .model(aiResponse.getModel())
                    .tokensUsed(aiResponse.getInputTokens() + aiResponse.getOutputTokens())
                    .cost(aiResponse.getCost())
                    .responseTimeMs(aiResponse.getResponseTimeMs())
                    .build();

            return ResponseEntity.ok(response);
        } catch (Exception e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @GetMapping("/conversations")
    @Operation(summary = "Get user's conversations")
    public ResponseEntity<List<ConversationResponse>> getConversations(
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        User user = User.builder().id(userPrincipal.getId()).build();
        List<Conversation> conversations = aiAssistantService.getUserConversations(user);
        List<ConversationResponse> response = conversations.stream()
                .map(ConversationResponse::fromEntity)
                .collect(Collectors.toList());
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/conversations/{id}")
    @Operation(summary = "Get conversation by ID")
    public ResponseEntity<ConversationResponse> getConversation(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        User user = User.builder().id(userPrincipal.getId()).build();
        Conversation conversation = aiAssistantService.getConversation(id, user);
        ConversationResponse response = ConversationResponse.fromEntity(conversation);
        
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/conversations/{id}")
    @Operation(summary = "Delete a conversation")
    public ResponseEntity<ApiResponse> deleteConversation(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        try {
            User user = User.builder().id(userPrincipal.getId()).build();
            aiAssistantService.deleteConversation(id, user);
            return ResponseEntity.ok(ApiResponse.success("Conversation deleted successfully"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(ApiResponse.error("Failed to delete conversation"));
        }
    }
}
