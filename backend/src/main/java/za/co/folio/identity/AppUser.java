package za.co.folio.identity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "app_users")
public class AppUser {
    @Id private UUID id;
    @Column(nullable = false, unique = true, length = 320) private String email;
    @Column(name = "display_name", nullable = false, length = 120) private String displayName;
    @Column(name = "password_hash", nullable = false, length = 100) private String passwordHash;
    @Column(nullable = false) private boolean verified;
    @Column(name = "created_at", nullable = false) private Instant createdAt;

    protected AppUser() {}
    public AppUser(String email, String displayName, String passwordHash) {
        this.id = UUID.randomUUID(); this.email = email; this.displayName = displayName;
        this.passwordHash = passwordHash; this.createdAt = Instant.now();
    }
    public UUID getId() { return id; }
    public String getEmail() { return email; }
    public String getDisplayName() { return displayName; }
    public String getPasswordHash() { return passwordHash; }
    public boolean isVerified() { return verified; }
    public void verify() { this.verified = true; }
    public void updateRegistration(String name, String passwordHash) { this.displayName = name; this.passwordHash = passwordHash; }
}
