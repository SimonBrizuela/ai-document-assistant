package com.aiassistant.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.regex.Pattern;

@Service
@Slf4j
public class InputSanitizationService {

    private static final int MAX_INPUT_LENGTH = 10000;
    private static final Pattern INJECTION_PATTERN = Pattern.compile(
            "(ignore previous|forget everything|system:|<\\|im_start\\||<\\|im_end\\||\\[INST\\]|\\[\\/INST\\])",
            Pattern.CASE_INSENSITIVE
    );

    public String sanitize(String input) {
        if (input == null || input.isEmpty()) {
            return input;
        }

        if (input.length() > MAX_INPUT_LENGTH) {
            log.warn("Input exceeds maximum length, truncating");
            input = input.substring(0, MAX_INPUT_LENGTH);
        }

        if (INJECTION_PATTERN.matcher(input).find()) {
            log.warn("Potential prompt injection detected");
            throw new SecurityException("Invalid input detected");
        }

        input = input.replaceAll("[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]", "");

        return input.trim();
    }

    public boolean isValid(String input) {
        try {
            sanitize(input);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
