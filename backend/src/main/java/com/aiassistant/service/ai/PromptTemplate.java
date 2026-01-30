package com.aiassistant.service.ai;

import lombok.AllArgsConstructor;
import lombok.Data;

import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Data
@AllArgsConstructor
public class PromptTemplate {
    
    private String name;
    private String version;
    private String template;
    private String description;

    public String render(Map<String, String> variables) {
        String result = template;
        
        Pattern pattern = Pattern.compile("\\{\\{(\\w+)\\}\\}");
        Matcher matcher = pattern.matcher(template);
        
        while (matcher.find()) {
            String variable = matcher.group(1);
            String value = variables.getOrDefault(variable, "");
            result = result.replace("{{" + variable + "}}", value);
        }
        
        return result;
    }
}
