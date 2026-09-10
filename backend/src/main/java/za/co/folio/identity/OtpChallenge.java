package za.co.folio.identity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "otp_challenges")
public class OtpChallenge {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(nullable = false, length = 24) private String purpose;
    @Column(name = "code_hash", nullable = false, length = 64) private String codeHash;
    @Column(name = "expires_at", nullable = false) private Instant expiresAt;
    @Column(nullable = false) private int attempts;
    @Column(name = "consumed_at") private Instant consumedAt;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected OtpChallenge() {}
    public OtpChallenge(UUID id, AppUser user, String purpose, String codeHash, Instant expiresAt) {
        this.id = id; this.user = user; this.purpose = purpose; this.codeHash = codeHash;
        this.expiresAt = expiresAt; this.createdAt = Instant.now();
    }
    public UUID getId() { return id; }
    public AppUser getUser() { return user; }
    public String getPurpose() { return purpose; }
    public String getCodeHash() { return codeHash; }
    public Instant getExpiresAt() { return expiresAt; }
    public int getAttempts() { return attempts; }
    public Instant getConsumedAt() { return consumedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public void failAttempt() { attempts++; }
    public void consume() { consumedAt = Instant.now(); }
}
