package com.aiassistant.controller;

import com.aiassistant.dto.QuestionRequest;
import com.aiassistant.model.User;
import com.aiassistant.security.UserPrincipal;
import com.aiassistant.service.StreamingAIService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

@RestController
@RequestMapping("/api/ai")
@RequiredArgsConstructor
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Streaming AI", description = "Streaming AI response endpoints")
@Slf4j
public class StreamingAIController {

    private final StreamingAIService streamingAIService;

    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    @Operation(summary = "Ask a question with streaming response")
    public Flux<String> streamQuestion(
            @Valid @RequestBody QuestionRequest request,
            @AuthenticationPrincipal UserPrincipal userPrincipal) {
        
        log.info("Streaming question for user: {}", userPrincipal.getId());
        User user = User.builder().id(userPrincipal.getId()).build();
        
        return streamingAIService.streamAnswer(
                request.getQuestion(),
                user,
                request.getConversationId(),
                request.getDocumentIds()
        );
    }
}
