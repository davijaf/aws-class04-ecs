package com.aws.class3.health.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

@RestController
public class HealthController {

    // Tag da imagem deployada — vem da env APP_TAG (default "dev" em execucao local)
    @Value("${app.tag:dev}")
    private String tag;

    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> checkHealth() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("tag", tag);
        response.put("timestamp", String.valueOf(System.currentTimeMillis()));

        // HTTP 200 OK com status + tag deployada
        return ResponseEntity.ok(response);
    }
}
