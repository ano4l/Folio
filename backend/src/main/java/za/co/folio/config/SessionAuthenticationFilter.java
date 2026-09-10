package za.co.folio.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Instant;
import java.util.Arrays;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import za.co.folio.identity.CurrentUser;
import za.co.folio.identity.TokenHash;
import za.co.folio.identity.UserSessionRepository;

@Component
public class SessionAuthenticationFilter extends OncePerRequestFilter {
    public static final String COOKIE = "FOLIO_SESSION";
    private final UserSessionRepository sessions;
    public SessionAuthenticationFilter(UserSessionRepository sessions) { this.sessions = sessions; }

    @Override protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String token = request.getCookies() == null ? null : Arrays.stream(request.getCookies())
                .filter(cookie -> COOKIE.equals(cookie.getName())).map(Cookie::getValue).findFirst().orElse(null);
        if (token != null && !token.isBlank()) {
            sessions.findByTokenHash(TokenHash.sha256(token))
                    .filter(session -> session.getRevokedAt() == null && session.getExpiresAt().isAfter(Instant.now()))
                    .ifPresent(session -> SecurityContextHolder.getContext().setAuthentication(
                            new UsernamePasswordAuthenticationToken(new CurrentUser(session.getUser(), session), null, java.util.List.of())));
        }
        chain.doFilter(request, response);
    }
}
