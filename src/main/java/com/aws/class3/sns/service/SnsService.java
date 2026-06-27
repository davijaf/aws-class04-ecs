package com.aws.class3.sns.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.*;

import java.util.HashMap;
import java.util.Map;

@Service
public class SnsService {

    private static final Logger log = LoggerFactory.getLogger(SnsService.class);

    private final SnsClient snsClient;

    private static final String TOPIC_ARN =
            "arn:aws:sns:sa-east-1:447197207642:AWS-CLASS-SNS";

    public SnsService(SnsClient snsClient) {
        this.snsClient = snsClient;
    }

    public String publish(String message) {

        PublishRequest request = PublishRequest.builder()
                .topicArn(TOPIC_ARN)
                .subject("Aviso da academia AWS")
                .message(message)
                .build();

        PublishResponse response = snsClient.publish(request);

        log.info("Mensagem publicada no topic. MessageId: {}", response.messageId());

        return "Mensagem publicada. ID: " + response.messageId();
    }

    public String subscribeEmail(String email) {

        SubscribeRequest request = SubscribeRequest.builder()
                .topicArn(TOPIC_ARN)
                .protocol("email")
                .endpoint(email)
                .build();

        SubscribeResponse response = snsClient.subscribe(request);

        log.info("Inscrição de email criada: {}", email);

        return "Inscrição criada. ARN: " + response.subscriptionArn() +
                " (verifique seu email e clique em 'Confirm subscription')";
    }

    public String subscribeHttp(String endpointUrl) {

        String protocol = endpointUrl.startsWith("https") ? "https" : "http";

        SubscribeRequest request = SubscribeRequest.builder()
                .topicArn(TOPIC_ARN)
                .protocol(protocol)
                .endpoint(endpointUrl)
                .build();

        SubscribeResponse response = snsClient.subscribe(request);

        log.info("Inscrição HTTP criada para endpoint: {}", endpointUrl);

        return "Inscrição criada. ARN: " + response.subscriptionArn();
    }

    public String sendSms(String phoneNumber, String message) {

        Map<String, MessageAttributeValue> attributes = new HashMap<>();
        attributes.put("AWS.SNS.SMS.SMSType",
                MessageAttributeValue.builder()
                        .dataType("String")
                        .stringValue("Transactional")
                        .build());

        PublishRequest request = PublishRequest.builder()
                .phoneNumber(phoneNumber)
                .message(message)
                .messageAttributes(attributes)
                .build();

        PublishResponse response = snsClient.publish(request);

        log.info("SMS enviado para {}. MessageId: {}", phoneNumber, response.messageId());

        return "SMS enviado. ID: " + response.messageId();
    }
}