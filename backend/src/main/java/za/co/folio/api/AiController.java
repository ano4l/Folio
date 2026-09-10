package za.co.folio.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import za.co.folio.ai.OpenRouterGroundedService;
import za.co.folio.identity.CurrentUser;

@RestController
@RequestMapping("/api/v1/ai")
public class AiController {
    private final OpenRouterGroundedService assistant;
    public AiController(OpenRouterGroundedService assistant) { this.assistant = assistant; }
    @PostMapping("/ask") public OpenRouterGroundedService.Answer ask(@AuthenticationPrincipal CurrentUser current, @Valid @RequestBody AskRequest request) {
        List<OpenRouterGroundedService.HistoryMessage> history = request.history() == null ? List.of() : request.history().stream()
                .filter(item -> item != null && item.text() != null && item.role() != null)
                .limit(12).map(item -> new OpenRouterGroundedService.HistoryMessage(item.role(), item.text())).toList();
        return assistant.ask(current.user(), request.question(), history);
    }
    public record AskRequest(@NotBlank @Size(max=2000) String question, List<HistoryItem> history) {}
    public record HistoryItem(@Size(max=16) String role, @Size(max=4000) String text) {}
}
