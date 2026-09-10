package za.co.folio.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

import java.util.List;
import org.junit.jupiter.api.Test;
import za.co.folio.documents.VaultDocument;
import za.co.folio.documents.VaultDocumentRepository;
import za.co.folio.identity.AppUser;

class OpenRouterGroundedServiceTest {
    private final AppUser user = new AppUser("student@example.com", "Student", "hash");
    private final VaultDocument document = new VaultDocument(user, "Funding Award", 1, "Funding of R10,000 is approved until December.");

    @Test void rejectsUnrelatedChatterBeforeCallingAProvider() {
        VaultDocumentRepository repository = mock(VaultDocumentRepository.class);
        when(repository.findAllByUserId(user.getId())).thenReturn(List.of(document));
        OpenRouterGroundedService service = new OpenRouterGroundedService(repository, "", "google/gemma-4-31b-it:free", "http://localhost", "Folio", true);

        OpenRouterGroundedService.Answer answer = service.ask(user, "Write me a joke about spaceships",
                List.of(new OpenRouterGroundedService.HistoryMessage("assistant", "Your funding award is R10,000.")));

        assertThat(answer.abstained()).isTrue();
        assertThat(answer.grounded()).isFalse();
        assertThat(answer.citations()).isEmpty();
    }

    @Test void handlesGreetingWithoutSpendingAProviderRequest() {
        VaultDocumentRepository repository = mock(VaultDocumentRepository.class);
        when(repository.findAllByUserId(user.getId())).thenReturn(List.of(document));
        OpenRouterGroundedService service = new OpenRouterGroundedService(repository, "", "google/gemma-4-31b-it:free", "http://localhost", "Folio", true);

        assertThat(service.ask(user, "Hello!", List.of()).answer()).contains("documents in your Folio vault");
    }
}
