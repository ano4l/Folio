package za.co.folio.api;

import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/documents")
public class DocumentController {
    @GetMapping
    public List<Map<String, Object>> list() {
        return List.of();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> get(@PathVariable long id) {
        return ResponseEntity.ok(Map.of("id", id, "status", "not_implemented"));
    }

    @PostMapping(consumes = "multipart/form-data")
    public ResponseEntity<Map<String, Object>> upload(@RequestParam("file") MultipartFile file) {
        return ResponseEntity.accepted().body(Map.of("status", "queued", "filename", file.getOriginalFilename()));
    }
}
