package com.aiassistant.service.ai;

import com.theokanning.openai.completion.chat.ChatCompletionRequest;
import com.theokanning.openai.completion.chat.ChatCompletionResult;
import com.theokanning.openai.completion.chat.ChatMessage;
import com.theokanning.openai.embedding.EmbeddingRequest;
import com.theokanning.openai.service.OpenAiService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
@ConditionalOnProperty(name = "app.ai.provider", havingValue = "openai")
@Slf4j
public class OpenAIProvider implements AIProvider {

    private final OpenAiService openAiService;
    private final String model;
    private final String embeddingModel;
    private final int maxTokens;
    private final double temperature;

    public OpenAIProvider(
            @Value("${app.ai.openai.api-key}") String apiKey,
            @Value("${app.ai.openai.model}") String model,
            @Value("${app.ai.openai.embedding-model}") String embeddingModel,
            @Value("${app.ai.openai.max-tokens}") int maxTokens,
            @Value("${app.ai.openai.temperature}") double temperature) {
        this.openAiService = new OpenAiService(apiKey, Duration.ofSeconds(60));
        this.model = model;
        this.embeddingModel = embeddingModel;
        this.maxTokens = maxTokens;
        this.temperature = temperature;
    }

    @Override
    public AIResponse generateCompletion(AIRequest request) {
        long startTime = System.currentTimeMillis();
        
        List<ChatMessage> messages = new ArrayList<>();
        
        if (request.getSystemPrompt() != null) {
            messages.add(new ChatMessage("system", request.getSystemPrompt()));
        }
        
        if (request.getMessages() != null) {
            messages.addAll(request.getMessages().stream()
                    .map(m -> new ChatMessage(m.getRole(), m.getContent()))
                    .collect(Collectors.toList()));
        }
        
        if (request.getUserPrompt() != null) {
            messages.add(new ChatMessage("user", request.getUserPrompt()));
        }

        ChatCompletionRequest completionRequest = ChatCompletionRequest.builder()
                .model(request.getModel() != null ? request.getModel() : model)
                .messages(messages)
                .maxTokens(request.getMaxTokens() != null ? request.getMaxTokens() : maxTokens)
                .temperature(request.getTemperature() != null ? request.getTemperature() : temperature)
                .build();

        ChatCompletionResult result = openAiService.createChatCompletion(completionRequest);
        long responseTime = System.currentTimeMillis() - startTime;

        String content = result.getChoices().get(0).getMessage().getContent();
        int inputTokens = result.getUsage().getPromptTokens();
        int outputTokens = result.getUsage().getCompletionTokens();
        double cost = estimateCost(inputTokens, outputTokens);

        return AIResponse.builder()
                .content(content)
                .model(result.getModel())
                .inputTokens(inputTokens)
                .outputTokens(outputTokens)
                .cost(cost)
                .responseTimeMs(responseTime)
                .finishReason(result.getChoices().get(0).getFinishReason())
                .build();
    }

    @Override
    public Flux<AIStreamResponse> streamCompletion(AIRequest request) {
        List<ChatMessage> messages = new ArrayList<>();
        
        if (request.getSystemPrompt() != null) {
            messages.add(new ChatMessage("system", request.getSystemPrompt()));
        }
        
        if (request.getMessages() != null) {
            messages.addAll(request.getMessages().stream()
                    .map(m -> new ChatMessage(m.getRole(), m.getContent()))
                    .collect(Collectors.toList()));
        }
        
        if (request.getUserPrompt() != null) {
            messages.add(new ChatMessage("user", request.getUserPrompt()));
        }

        ChatCompletionRequest completionRequest = ChatCompletionRequest.builder()
                .model(request.getModel() != null ? request.getModel() : model)
                .messages(messages)
                .maxTokens(request.getMaxTokens() != null ? request.getMaxTokens() : maxTokens)
                .temperature(request.getTemperature() != null ? request.getTemperature() : temperature)
                .stream(true)
                .build();

        return Flux.create(sink -> {
            try {
                openAiService.streamChatCompletion(completionRequest)
                        .doOnError(sink::error)
                        .blockingForEach(chunk -> {
                            if (chunk.getChoices() != null && !chunk.getChoices().isEmpty()) {
                                String content = chunk.getChoices().get(0).getMessage().getContent();
                                if (content != null && !content.isEmpty()) {
                                    AIStreamResponse response = AIStreamResponse.builder()
                                            .content(content)
                                            .done(false)
                                            .build();
                                    sink.next(response);
                                }
                            }
                        });
                sink.complete();
            } catch (Exception e) {
                sink.error(e);
            }
        });
    }

    @Override
    public List<Double> generateEmbedding(String text) {
        EmbeddingRequest embeddingRequest = EmbeddingRequest.builder()
                .model(embeddingModel)
                .input(List.of(text))
                .build();

        return openAiService.createEmbeddings(embeddingRequest)
                .getData()
                .get(0)
                .getEmbedding();
    }

    @Override
    public String getProviderName() {
        return "OpenAI";
    }

    @Override
    public int estimateTokens(String text) {
        return (int) Math.ceil(text.length() / 4.0);
    }

    @Override
    public double estimateCost(int inputTokens, int outputTokens) {
        double inputCostPer1k = 0.01;
        double outputCostPer1k = 0.03;
        
        return (inputTokens / 1000.0) * inputCostPer1k + (outputTokens / 1000.0) * outputCostPer1k;
    }
}
