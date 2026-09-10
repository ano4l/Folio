package za.co.folio.identity;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface UserSessionRepository extends JpaRepository<UserSession, UUID> { Optional<UserSession> findByTokenHash(String tokenHash); }
