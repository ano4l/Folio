package za.co.folio.identity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface OtpChallengeRepository extends JpaRepository<OtpChallenge, UUID> {}
