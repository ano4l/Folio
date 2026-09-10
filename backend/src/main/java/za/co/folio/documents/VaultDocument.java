package za.co.folio.documents;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
import za.co.folio.identity.AppUser;

@Entity
@Table(name = "vault_documents")
public class VaultDocument {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false) @JoinColumn(name = "user_id") private AppUser user;
    @Column(nullable = false, length = 240) private String title;
    @Column(name = "page_number", nullable = false) private int pageNumber;
    @Column(nullable = false, columnDefinition = "text") private String content;
    @Column(name = "created_at", nullable = false) private Instant createdAt;
    protected VaultDocument() {}
    public VaultDocument(AppUser user, String title, int pageNumber, String content) {
        this.id = UUID.randomUUID(); this.user = user; this.title = title; this.pageNumber = pageNumber;
        this.content = content; this.createdAt = Instant.now();
    }
    public UUID getId() { return id; }
    public String getTitle() { return title; }
    public int getPageNumber() { return pageNumber; }
    public String getContent() { return content; }
}
