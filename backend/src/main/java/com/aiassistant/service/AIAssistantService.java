package com.aiassistant.service;

import com.aiassistant.model.*;
import com.aiassistant.repository.ConversationRepository;
import com.aiassistant.repository.MessageRepository;
import com.aiassistant.service.ai.AIProvider;
import com.aiassistant.service.ai.AIRequest;
import com.aiassistant.service.ai.AIResponse;
import com.aiassistant.service.ai.PromptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AIAssistantService {

    private final AIProvider aiProvider;
    private final PromptService promptService;
    private final DocumentService documentService;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final AuditService auditService;
    private final InputSanitizationService sanitizationService;

    @Transactional
    public AIResponse askQuestion(String question, User user, Long conversationId, List<Long> documentIds) {
        question = sanitizationService.sanitize(question);
        
        Conversation conversation;
        if (conversationId != null) {
            conversation = conversationRepository.findByIdAndUser(conversationId, user)
                    .orElseThrow(() -> new RuntimeException("Conversation not found"));
        } else {
            conversation = Conversation.builder()
                    .title(question.substring(0, Math.min(50, question.length())) + "...")
                    .user(user)
                    .messages(new ArrayList<>())
                    .build();
            conversation = conversationRepository.save(conversation);
        }

        List<DocumentChunk> relevantChunks = documentService.findSimilarChunks(question, user, 5);
        
        String context = relevantChunks.stream()
                .map(DocumentChunk::getContent)
                .collect(Collectors.joining("\n\n---\n\n"));

        String systemPrompt = promptService.renderPrompt("system", Map.of());
        String userPrompt = promptService.renderPrompt("question_answering", 
                Map.of("context", context, "question", question));

        List<AIRequest.ChatMessage> chatMessages = new ArrayList<>();
        List<Message> previousMessages = messageRepository.findRecentByConversation(conversation)
                .stream().limit(5).collect(Collectors.toList());
        
        for (Message msg : previousMessages) {
            chatMessages.add(AIRequest.ChatMessage.builder()
                    .role(msg.getRole().name().toLowerCase())
                    .content(msg.getContent())
                    .build());
        }

        AIRequest request = AIRequest.builder()
                .systemPrompt(systemPrompt)
                .messages(chatMessages)
                .userPrompt(userPrompt)
                .build();

        AIResponse response = aiProvider.generateCompletion(request);

        Message userMessage = Message.builder()
                .conversation(conversation)
                .role(Message.MessageRole.USER)
                .content(question)
                .tokenCount(aiProvider.estimateTokens(question))
                .build();
        messageRepository.save(userMessage);

        Message assistantMessage = Message.builder()
                .conversation(conversation)
                .role(Message.MessageRole.ASSISTANT)
                .content(response.getContent())
                .tokenCount(response.getOutputTokens())
                .modelUsed(response.getModel())
                .processingTimeMs(response.getResponseTimeMs())
                .build();
        messageRepository.save(assistantMessage);

        auditService.logAIInteraction(user, "AI_QUESTION", response, question);

        log.info("Answered question for user {} in conversation {}", user.getId(), conversation.getId());
        return response;
    }

    @Transactional(readOnly = true)
    public List<Conversation> getUserConversations(User user) {
        return conversationRepository.findByUserOrderByUpdatedAtDesc(user, 
                org.springframework.data.domain.PageRequest.of(0, 20)).getContent();
    }

    @Transactional(readOnly = true)
    public Conversation getConversation(Long id, User user) {
        return conversationRepository.findByIdAndUserWithMessages(id, user)
                .orElseThrow(() -> new RuntimeException("Conversation not found"));
    }

    @Transactional
    public void deleteConversation(Long id, User user) {
        Conversation conversation = conversationRepository.findByIdAndUser(id, user)
                .orElseThrow(() -> new RuntimeException("Conversation not found"));
        conversationRepository.delete(conversation);
    }
}
