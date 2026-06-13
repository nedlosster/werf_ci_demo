package com.example.app1;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/v1")
public class HelloController {

    @Value("${app.version}")
    private String version;

    @GetMapping("/hello")
    public Map<String, String> hello() {
        return Map.of(
            "app", "app1-java-react",
            "stack", "Spring Boot (Java)",
            "message", "привет из бекенда app1"
        );
    }

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", version);
    }
}
