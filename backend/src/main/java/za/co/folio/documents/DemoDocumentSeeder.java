package za.co.folio.documents;

import org.springframework.stereotype.Service;
import za.co.folio.identity.AppUser;

@Service
public class DemoDocumentSeeder {
    private final VaultDocumentRepository documents;
    public DemoDocumentSeeder(VaultDocumentRepository documents) { this.documents = documents; }
    public void seedFor(AppUser user) {
        if (documents.countByUserId(user.getId()) > 0) return;
        documents.save(new VaultDocument(user, "Government Funding Award Letter — 2026", 1,
                "Award approved for R98,450 covering tuition, accommodation, and books. Maintain a 60% average, remain registered full-time, and submit proof of registration by 12 February 2026."));
        documents.save(new VaultDocument(user, "Merit Bursary Agreement — 2026", 2,
                "The bursary is R32,000 per year. Renewal requires an official Semester 1 transcript showing an average above 75% and a signed renewal declaration before 02 August 2026."));
        documents.save(new VaultDocument(user, "Semester 1 Fee Statement", 1,
                "Charges total R65,000: tuition R45,000, residence R12,000, and meals R8,000. A financial aid credit of R60,880 leaves R4,120 due by 28 February 2026."));
        documents.save(new VaultDocument(user, "Standard Bank Account Confirmation", 1,
                "The active transactional account ending in 192 is verified for financial-aid disbursement deposits and has no restrictions."));
    }
}
