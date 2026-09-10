package za.co.folio.documents;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface VaultDocumentRepository extends JpaRepository<VaultDocument, UUID> { List<VaultDocument> findAllByUserId(UUID userId); long countByUserId(UUID userId); }
