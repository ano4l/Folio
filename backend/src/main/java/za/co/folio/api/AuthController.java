package za.co.folio.api;

import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Duration;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import za.co.folio.config.SessionAuthenticationFilter;
import za.co.folio.identity.AuthService;
import za.co.folio.identity.CurrentUser;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService auth;
    private final boolean secureCookie;
    public AuthController(AuthService auth, @Value("${folio.auth.cookie-secure:false}") boolean secureCookie) {
        this.auth = auth; this.secureCookie = secureCookie;
    }
    @PostMapping("/register") public AuthService.ChallengeResult register(@Valid @RequestBody RegisterRequest request) {
        return auth.register(request.email(), request.displayName(), request.password());
    }
    @PostMapping("/login") public AuthService.ChallengeResult login(@Valid @RequestBody LoginRequest request) {
        return auth.login(request.email(), request.password());
    }
    @PostMapping("/resend") public AuthService.ChallengeResult resend(@Valid @RequestBody ChallengeRequest request) {
        return auth.resend(request.challengeId());
    }
    @PostMapping("/verify") public MeResponse verify(@Valid @RequestBody VerifyRequest request, HttpServletResponse response) {
        AuthService.VerifiedSession verified = auth.verify(request.challengeId(), request.code());
        response.addHeader(HttpHeaders.SET_COOKIE, sessionCookie(verified.token(), verified.lifetime()).toString());
        return MeResponse.from(verified.user().getId(), verified.user().getEmail(), verified.user().getDisplayName());
    }
    @GetMapping("/me") public MeResponse me(@AuthenticationPrincipal CurrentUser current) {
        return MeResponse.from(current.user().getId(), current.user().getEmail(), current.user().getDisplayName());
    }
    @PostMapping("/logout") public Map<String, Boolean> logout(@AuthenticationPrincipal CurrentUser current, HttpServletResponse response) {
        auth.logout(current);
        response.addHeader(HttpHeaders.SET_COOKIE, sessionCookie("", Duration.ZERO).toString());
        return Map.of("loggedOut", true);
    }
    private ResponseCookie sessionCookie(String value, Duration age) {
        return ResponseCookie.from(SessionAuthenticationFilter.COOKIE, value).httpOnly(true).secure(secureCookie)
                .sameSite("Lax").path("/").maxAge(age).build();
    }
    public record RegisterRequest(@NotBlank @Size(max=120) String displayName, @Email @NotBlank @Size(max=320) String email,
            @NotBlank @Size(min=10, max=128, message="Password must be between 10 and 128 characters") String password) {}
    public record LoginRequest(@Email @NotBlank String email, @NotBlank String password) {}
    public record ChallengeRequest(@NotNull UUID challengeId) {}
    public record VerifyRequest(@NotNull UUID challengeId, @NotNull @Pattern(regexp="\\d{6}", message="Enter the 6-digit code") String code) {}
    public record MeResponse(UUID id, String email, String displayName) {
        static MeResponse from(UUID id, String email, String name) { return new MeResponse(id, email, name); }
    }
}
