package com.aiassistant.service.ai;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.ResourceLoader;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Slf4j
public class PromptService {

    private final ResourceLoader resourceLoader;
    private final String promptVersion;
    private final Map<String, PromptTemplate> templates = new HashMap<>();

    public PromptService(
            ResourceLoader resourceLoader,
            @Value("${app.ai.prompt.version}") String promptVersion) {
        this.resourceLoader = resourceLoader;
        this.promptVersion = promptVersion;
    }

    @PostConstruct
    public void loadPrompts() {
        try {
            loadPrompt("system", "System prompt for AI assistant");
            loadPrompt("question_answering", "Question answering with context");
            loadPrompt("document_summary", "Document summarization");
            log.info("Loaded {} prompt templates with version {}", templates.size(), promptVersion);
        } catch (Exception e) {
            log.error("Failed to load prompts", e);
        }
    }

    private void loadPrompt(String name, String description) {
        try {
            String path = String.format("classpath:prompts/%s_%s.txt", name, promptVersion);
            Resource resource = resourceLoader.getResource(path);
            
            if (resource.exists()) {
                String content = new BufferedReader(
                        new InputStreamReader(resource.getInputStream(), StandardCharsets.UTF_8))
                        .lines()
                        .collect(Collectors.joining("\n"));
                
                templates.put(name, new PromptTemplate(name, promptVersion, content, description));
                log.debug("Loaded prompt template: {}", name);
            } else {
                log.warn("Prompt template not found: {}", path);
            }
        } catch (Exception e) {
            log.error("Failed to load prompt: " + name, e);
        }
    }

    public PromptTemplate getTemplate(String name) {
        return templates.get(name);
    }

    public String renderPrompt(String templateName, Map<String, String> variables) {
        PromptTemplate template = templates.get(templateName);
        if (template == null) {
            log.warn("Prompt template not found: {}", templateName);
            return "";
        }
        return template.render(variables);
    }

    public String getPromptVersion() {
        return promptVersion;
    }
}
