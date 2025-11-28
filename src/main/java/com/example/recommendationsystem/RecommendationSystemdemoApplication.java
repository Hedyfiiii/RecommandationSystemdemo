package com.example.recommendationsystem;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class RecommendationSystemdemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(RecommendationSystemdemoApplication.class, args);
    }

    @GetMapping("/")
    public String home() {
        return """
                <!DOCTYPE html>
                <html>
                <head>
                    <title>Recommendation System</title>
                    <style>
                        body {
                            display: flex;
                            justify-content: center;
                            align-items: center;
                            height: 100vh;
                            margin: 0;
                            font-family: Arial, sans-serif;
                            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        }
                        h1 {
                            color: white;
                            font-size: 48px;
                            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
                        }
                    </style>
                </head>
                <body>
                    <h1>Recommendation System</h1>
                </body>
                </html>
                """;
    }

    @GetMapping("/actuator/health")
    public String health() {
        return "{\"status\":\"UP\"}";
    }
}