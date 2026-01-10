package com.aiassistant.service;

import com.aiassistant.model.*;
import com.aiassistant.repository.ConversationRepository;
import com.aiassistant.repository.MessageRepository;
import com.aiassistant.service.ai.AIProvider;
import com.aiassistant.service.ai.AIRequest;
import com.aiassistant.service.ai.PromptService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class StreamingAIService {

    private final AIProvider aiProvider;
    private final PromptService promptService;
    private final DocumentService documentService;
    private final ConversationRepository conversationRepository;
    private final MessageRepository messageRepository;
    private final AuditService auditService;
    private final InputSanitizationService sanitizationService;

    public Flux<String> streamAnswer(String question, User user, Long conversationId, List<Long> documentIds) {
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

        final Conversation finalConversation = conversation;
        final String sanitizedQuestion = question;

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

        StringBuilder fullResponse = new StringBuilder();
        long startTime = System.currentTimeMillis();

        return aiProvider.streamCompletion(request)
                .doOnNext(chunk -> {
                    fullResponse.append(chunk.getContent());
                    log.debug("Streaming chunk: {}", chunk.getContent());
                })
                .map(chunk -> "data: " + chunk.getContent() + "\n\n")
                .doOnComplete(() -> {
                    long responseTime = System.currentTimeMillis() - startTime;
                    
                    Message userMessage = Message.builder()
                            .conversation(finalConversation)
                            .role(Message.MessageRole.USER)
                            .content(sanitizedQuestion)
                            .tokenCount(aiProvider.estimateTokens(sanitizedQuestion))
                            .build();
                    messageRepository.save(userMessage);

                    Message assistantMessage = Message.builder()
                            .conversation(finalConversation)
                            .role(Message.MessageRole.ASSISTANT)
                            .content(fullResponse.toString())
                            .tokenCount(aiProvider.estimateTokens(fullResponse.toString()))
                            .processingTimeMs(responseTime)
                            .build();
                    messageRepository.save(assistantMessage);

                    log.info("Completed streaming response for user {} in conversation {}", 
                            user.getId(), finalConversation.getId());
                })
                .doOnError(error -> {
                    log.error("Error during streaming: ", error);
                });
    }
}
