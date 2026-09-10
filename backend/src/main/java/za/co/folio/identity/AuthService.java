package za.co.folio.identity;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Locale;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import za.co.folio.api.ApiExceptionHandler.ApiProblem;
import za.co.folio.documents.DemoDocumentSeeder;
import za.co.folio.email.OtpEmailSender;

@Service
public class AuthService {
    private final AppUserRepository users;
    private final OtpChallengeRepository challenges;
    private final UserSessionRepository sessions;
    private final PasswordEncoder passwords;
    private final OtpEmailSender emailSender;
    private final DemoDocumentSeeder demoDocuments;
    private final SecureRandom random = new SecureRandom();
    private final Duration otpLifetime;
    private final Duration sessionLifetime;
    private final String otpPepper;

    public AuthService(AppUserRepository users, OtpChallengeRepository challenges, UserSessionRepository sessions,
            PasswordEncoder passwords, OtpEmailSender emailSender, DemoDocumentSeeder demoDocuments,
            @Value("${folio.auth.otp-minutes:10}") long otpMinutes,
            @Value("${folio.auth.session-hours:12}") long sessionHours,
            @Value("${folio.auth.otp-pepper}") String otpPepper) {
        this.users = users; this.challenges = challenges; this.sessions = sessions; this.passwords = passwords;
        this.emailSender = emailSender; this.demoDocuments = demoDocuments; this.otpLifetime = Duration.ofMinutes(otpMinutes);
        this.sessionLifetime = Duration.ofHours(sessionHours); this.otpPepper = otpPepper;
    }

    @Transactional
    public ChallengeResult register(String email, String displayName, String password) {
        String normalized = normalize(email);
        AppUser user = users.findByEmailIgnoreCase(normalized).orElse(null);
        if (user != null && user.isVerified()) throw new ApiProblem(HttpStatus.CONFLICT, "An account already exists for this email");
        String passwordHash = passwords.encode(password);
        if (user == null) user = users.save(new AppUser(normalized, displayName.trim(), passwordHash));
        else { user.updateRegistration(displayName.trim(), passwordHash); users.save(user); }
        return issueChallenge(user, "REGISTER");
    }

    @Transactional
    public ChallengeResult login(String email, String password) {
        AppUser user = users.findByEmailIgnoreCase(normalize(email))
                .orElseThrow(() -> new ApiProblem(HttpStatus.UNAUTHORIZED, "Email or password is incorrect"));
        if (!passwords.matches(password, user.getPasswordHash())) throw new ApiProblem(HttpStatus.UNAUTHORIZED, "Email or password is incorrect");
        if (!user.isVerified()) throw new ApiProblem(HttpStatus.FORBIDDEN, "Verify this account before signing in");
        return issueChallenge(user, "LOGIN");
    }

    @Transactional
    public ChallengeResult resend(UUID challengeId) {
        OtpChallenge old = challenges.findById(challengeId)
                .orElseThrow(() -> new ApiProblem(HttpStatus.NOT_FOUND, "Verification request not found"));
        if (old.getConsumedAt() != null) throw new ApiProblem(HttpStatus.CONFLICT, "Verification request has already been used");
        if (old.getCreatedAt().plusSeconds(60).isAfter(Instant.now()))
            throw new ApiProblem(HttpStatus.TOO_MANY_REQUESTS, "Please wait before requesting another code");
        ChallengeResult replacement = issueChallenge(old.getUser(), old.getPurpose());
        old.consume(); challenges.save(old);
        return replacement;
    }

    @Transactional(noRollbackFor = ApiProblem.class)
    public VerifiedSession verify(UUID challengeId, String code) {
        OtpChallenge challenge = challenges.findById(challengeId)
                .orElseThrow(() -> new ApiProblem(HttpStatus.NOT_FOUND, "Verification request not found"));
        if (challenge.getConsumedAt() != null) throw new ApiProblem(HttpStatus.CONFLICT, "This code has already been used");
        if (challenge.getExpiresAt().isBefore(Instant.now())) throw new ApiProblem(HttpStatus.GONE, "This code has expired");
        if (challenge.getAttempts() >= 5) throw new ApiProblem(HttpStatus.TOO_MANY_REQUESTS, "Too many incorrect attempts; request a new code");
        String expected = TokenHash.sha256(otpPepper + ":" + challenge.getId() + ":" + code);
        if (!java.security.MessageDigest.isEqual(expected.getBytes(java.nio.charset.StandardCharsets.US_ASCII),
                challenge.getCodeHash().getBytes(java.nio.charset.StandardCharsets.US_ASCII))) {
            challenge.failAttempt(); challenges.save(challenge);
            throw new ApiProblem(HttpStatus.UNAUTHORIZED, "The verification code is incorrect");
        }
        challenge.consume();
        AppUser user = challenge.getUser();
        if ("REGISTER".equals(challenge.getPurpose()) && !user.isVerified()) {
            user.verify(); users.save(user); demoDocuments.seedFor(user);
        }
        String rawToken = randomToken();
        sessions.save(new UserSession(user, TokenHash.sha256(rawToken), Instant.now().plus(sessionLifetime)));
        return new VerifiedSession(rawToken, sessionLifetime, user);
    }

    @Transactional public void logout(CurrentUser current) { current.session().revoke(); sessions.save(current.session()); }

    private ChallengeResult issueChallenge(AppUser user, String purpose) {
        String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
        UUID challengeId = UUID.randomUUID();
        OtpChallenge challenge = challenges.save(new OtpChallenge(challengeId, user, purpose,
                TokenHash.sha256(otpPepper + ":" + challengeId + ":" + code), Instant.now().plus(otpLifetime)));
        emailSender.send(user.getEmail(), user.getDisplayName(), code, purpose, "folio-otp/" + challenge.getId());
        return new ChallengeResult(challenge.getId(), mask(user.getEmail()), otpLifetime.toSeconds(), 60);
    }

    private String normalize(String email) { return email.trim().toLowerCase(Locale.ROOT); }
    private String mask(String email) { int at = email.indexOf('@'); return email.substring(0, Math.min(2, at)) + "***" + email.substring(at); }
    private String randomToken() { byte[] bytes = new byte[32]; random.nextBytes(bytes); return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); }
    public record ChallengeResult(UUID challengeId, String destination, long expiresInSeconds, long resendAfterSeconds) {}
    public record VerifiedSession(String token, Duration lifetime, AppUser user) {}
}
