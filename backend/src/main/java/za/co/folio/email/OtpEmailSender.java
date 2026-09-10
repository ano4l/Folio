package za.co.folio.email;
public interface OtpEmailSender { void send(String email, String displayName, String code, String purpose, String idempotencyKey); }
