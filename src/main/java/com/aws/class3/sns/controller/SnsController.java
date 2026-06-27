package com.aws.class3.sns.controller;

import com.aws.class3.sns.service.SnsService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/sns")
public class SnsController {

    private final SnsService service;

    public SnsController(SnsService service) {
        this.service = service;
    }

    @PostMapping("/publish")
    public ResponseEntity<String> publish(@RequestParam String message) {
        return ResponseEntity.ok(service.publish(message));
    }

    @PostMapping("/subscribe")
    public ResponseEntity<String> subscribe(@RequestParam String email) {
        return ResponseEntity.ok(service.subscribeEmail(email));
    }

    @PostMapping("/subscribe-app")
    public ResponseEntity<String> subscribeApp(@RequestParam String endpointUrl) {
        return ResponseEntity.ok(service.subscribeHttp(endpointUrl));
    }

    @PostMapping("/sms")
    public ResponseEntity<String> sms(
            @RequestParam String phoneNumber,
            @RequestParam String message) {
        return ResponseEntity.ok(service.sendSms(phoneNumber, message));
    }
}