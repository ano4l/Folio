package za.co.folio.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import za.co.folio.documents.DemoDocumentSeeder;
import za.co.folio.email.OtpEmailSender;

class AuthServiceTest {
    @Test void registrationCodeVerifiesAccountAndCreatesSession() {
        AppUserRepository users = mock(AppUserRepository.class);
        OtpChallengeRepository challenges = mock(OtpChallengeRepository.class);
        UserSessionRepository sessions = mock(UserSessionRepository.class);
        DemoDocumentSeeder seeder = mock(DemoDocumentSeeder.class);
        AtomicReference<String> sentCode = new AtomicReference<>();
        OtpEmailSender sender = (email, name, code, purpose, key) -> sentCode.set(code);
        when(users.findByEmailIgnoreCase("student@example.com")).thenReturn(Optional.empty());
        when(users.save(any(AppUser.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(challenges.save(any(OtpChallenge.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(sessions.save(any(UserSession.class))).thenAnswer(invocation -> invocation.getArgument(0));
        AuthService service = new AuthService(users, challenges, sessions, new BCryptPasswordEncoder(4), sender, seeder, 10, 12, "test-pepper");

        AuthService.ChallengeResult challenge = service.register(" Student@Example.com ", "Student Name", "strong-password");
        var savedChallenge = org.mockito.ArgumentCaptor.forClass(OtpChallenge.class);
        verify(challenges).save(savedChallenge.capture());
        when(challenges.findById(challenge.challengeId())).thenReturn(Optional.of(savedChallenge.getValue()));

        AuthService.VerifiedSession verified = service.verify(challenge.challengeId(), sentCode.get());

        assertThat(verified.user().isVerified()).isTrue();
        assertThat(verified.token()).isNotBlank();
        assertThat(challenge.resendAfterSeconds()).isEqualTo(60);
        verify(seeder).seedFor(verified.user());
        verify(sessions).save(any(UserSession.class));
    }
}
