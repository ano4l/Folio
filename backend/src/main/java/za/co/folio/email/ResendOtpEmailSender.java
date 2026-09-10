package za.co.folio.email;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
public class ResendOtpEmailSender implements OtpEmailSender {
    private final String apiKey;
    private final String from;
    private final RestClient http = RestClient.builder().baseUrl("https://api.resend.com").defaultHeader(HttpHeaders.USER_AGENT, "Folio/0.1").build();
    public ResendOtpEmailSender(@Value("${folio.resend.api-key:}") String apiKey, @Value("${folio.resend.from}") String from) {
        this.apiKey = apiKey; this.from = from;
    }
    @Override public void send(String email, String displayName, String code, String purpose, String idempotencyKey) {
        if (apiKey == null || apiKey.isBlank()) throw new IllegalStateException("Resend is not configured");
        String action = "REGISTER".equals(purpose) ? "verify your new Folio account" : "finish signing in to Folio";
        String safeName = escape(displayName);
        String html = "<div style=\"font-family:Arial,sans-serif;max-width:520px;margin:auto\"><h2>Folio security code</h2>"
                + "<p>Hello " + safeName + ", use this code to " + action + ":</p>"
                + "<p style=\"font-size:32px;letter-spacing:8px;font-weight:700\">" + code + "</p>"
                + "<p>This code expires shortly. If you did not request it, you can ignore this email.</p></div>";
        http.post().uri("/emails")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                .header("Idempotency-Key", idempotencyKey)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("from", from, "to", java.util.List.of(email), "subject", "Your Folio verification code", "html", html))
                .retrieve().toBodilessEntity();
    }
    private String escape(String value) { return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;"); }
}
