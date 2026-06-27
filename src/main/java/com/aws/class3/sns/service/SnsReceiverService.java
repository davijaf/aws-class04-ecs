package com.aws.class3.sns.service;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.ConfirmSubscriptionRequest;

@Service
public class SnsReceiverService {

    private static final Logger log = LoggerFactory.getLogger(SnsReceiverService.class);

    private final SnsClient snsClient;

    public SnsReceiverService(SnsClient snsClient) {
        this.snsClient = snsClient;
    }

    /**
     * Confirma a inscrição da app no topic.
     * Chamado quando o SNS envia uma requisição do tipo "SubscriptionConfirmation".
     */
    public String confirmSubscription(JsonNode payload) {

        String topicArn = payload.get("TopicArn").asText();
        String token = payload.get("Token").asText();

        snsClient.confirmSubscription(ConfirmSubscriptionRequest.builder()
                .topicArn(topicArn)
                .token(token)
                .build());

        log.info("Inscrição confirmada automaticamente para topic: {}", topicArn);

        return "Subscription confirmed";
    }

    /**
     * Processa uma notificação recebida do topic.
     * Aqui é onde sua lógica de negócio entraria:
     * salvar no banco, disparar workflow, atualizar cache, etc.
     */
    public String processNotification(JsonNode payload) {

        log.info(" ");
        log.info("Novidade recebida do SNS!");
        log.info("Message ID: {}", payload.toString());
        log.info(" ");

        return "Notification processed: ";
    }
}