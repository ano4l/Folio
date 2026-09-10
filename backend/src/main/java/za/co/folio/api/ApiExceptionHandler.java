package za.co.folio.api;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {
    @ExceptionHandler(ApiProblem.class) ResponseEntity<Map<String, String>> problem(ApiProblem problem) {
        return ResponseEntity.status(problem.status).body(Map.of("message", problem.getMessage()));
    }
    @ExceptionHandler(MethodArgumentNotValidException.class) ResponseEntity<Map<String, String>> invalid(MethodArgumentNotValidException error) {
        String message = error.getBindingResult().getFieldErrors().stream().findFirst()
                .map(item -> item.getDefaultMessage()).orElse("Please check the submitted details");
        return ResponseEntity.badRequest().body(Map.of("message", message));
    }
    public static class ApiProblem extends RuntimeException {
        private final HttpStatus status;
        public ApiProblem(HttpStatus status, String message) { super(message); this.status = status; }
    }
}
