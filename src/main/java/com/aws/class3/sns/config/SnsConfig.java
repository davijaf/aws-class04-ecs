package com.aws.class3.sns.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sns.SnsClient;

@Configuration
public class SnsConfig {

    @Bean
    public SnsClient snsClient() {
        return SnsClient.builder()
                .region(Region.SA_EAST_1)
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }
}