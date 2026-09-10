package za.co.folio.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "user_sessions")
public class UserSession {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.EAGER, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(name = "token_hash", nullable = false, unique = true, length = 64) private String tokenHash;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @Column(name = "revoked_at") private Instant revokedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected UserSession() {}
    public UserSession(AppUser user, String tokenHash, Instant expiresAt) {
        this.id = UUID.randomUUID(); this.user = user; this.tokenHash = tokenHash;
        this.expiresAt = expiresAt; this.createdAt = Instant.now();
    }
    public AppUser getUser() { return user; }
    public Instant getExpiresAt() { return expiresAt; }
    public Instant getRevokedAt() { return revokedAt; }
    public void revoke() { revokedAt = Instant.now(); }
}
