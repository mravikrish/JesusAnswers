package com.jesusanswers.api.journey;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.UUID;

import org.springframework.data.domain.Limit;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.bible.BibleCorpus;
import com.jesusanswers.api.bible.Verse;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * "My Journey" sync for signed-in users. The JSON shape matches the app's Answer.toJson(), so the
 * app can push and pull entries as-is. Verse text is re-rendered from the corpus, never stored.
 */
@RestController
public class JourneyController {

    public record VerseRef(@NotBlank String ref) {}

    public record EntryDto(
            @NotNull UUID id,
            @NotNull @Pattern(regexp = "question|prayer") String kind,
            @NotBlank @Size(max = 4000) String question,
            @NotNull @Pattern(regexp = "en|hi|te|ta|kn|ml|mr|pa|bn|gu|or") String lang,
            @Size(max = 32) String mood,
            List<@Size(max = 32) String> themes,
            @Size(max = 4) List<VerseRef> verses,
            @NotBlank @Size(max = 8000) String encouragement,
            @NotBlank @Size(max = 8000) String prayer,
            @NotBlank String createdAt,
            boolean crisis,
            boolean favorite) {}

    public record EntryView(UUID id, String kind, String question, String lang, String mood, List<String> themes,
                            List<Verse> verses, String encouragement, String prayer, String createdAt,
                            boolean crisis, boolean favorite) {}

    private final AppUserRepository users;
    private final JourneyEntryRepository entries;
    private final BibleCorpus corpus;

    public JourneyController(AppUserRepository users, JourneyEntryRepository entries, BibleCorpus corpus) {
        this.users = users;
        this.entries = entries;
        this.corpus = corpus;
    }

    @GetMapping("/v1/journey")
    @Transactional
    public List<EntryView> list(@AuthenticationPrincipal Jwt jwt) {
        return entries.findByUserIdOrderByCreatedAtDesc(user(jwt).getId(), Limit.of(500)).stream()
                .map(this::view).toList();
    }

    /** Idempotent upsert keyed by the app-generated id — safe to retry after going offline. */
    @PutMapping("/v1/journey/{id}")
    @Transactional
    public EntryView put(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @Valid @RequestBody EntryDto dto) {
        if (!id.equals(dto.id())) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "id mismatch");
        AppUser user = user(jwt);
        JourneyEntry entry = entries.findById(id).orElseGet(() -> new JourneyEntry(id, user.getId()));
        if (!entry.getUserId().equals(user.getId())) throw new ResponseStatusException(HttpStatus.NOT_FOUND);

        List<String> refs = dto.verses() == null ? List.of()
                : dto.verses().stream().map(VerseRef::ref).filter(corpus::isKnownRef).distinct().toList();
        entry.update(dto.kind(), dto.lang(), dto.mood(), dto.themes() == null ? List.of() : dto.themes(), refs,
                dto.question(), dto.encouragement(), dto.prayer(), dto.crisis(), dto.favorite(),
                parseInstant(dto.createdAt()));
        return view(entries.save(entry));
    }

    @DeleteMapping("/v1/journey/{id}")
    @Transactional
    public ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        entries.findByIdAndUserId(id, user(jwt).getId()).ifPresent(entries::delete);
        return ResponseEntity.noContent().build();
    }

    /** Deletes the account and every journey entry (required by both app stores). */
    @DeleteMapping("/v1/me")
    @Transactional
    public ResponseEntity<Void> deleteAccount(@AuthenticationPrincipal Jwt jwt) {
        users.findByFirebaseUid(jwt.getSubject()).ifPresent(users::delete);
        return ResponseEntity.noContent().build();
    }

    private AppUser user(Jwt jwt) {
        return users.findByFirebaseUid(jwt.getSubject())
                .orElseGet(() -> users.save(new AppUser(jwt.getSubject())));
    }

    private EntryView view(JourneyEntry e) {
        List<Verse> verses = e.getVerseRefs().stream()
                .flatMap(ref -> corpus.verse(ref, e.getLang()).stream()).toList();
        return new EntryView(e.getId(), e.getKind(), e.getQuestion(), e.getLang(), e.getMood(), e.getThemes(),
                verses, e.getEncouragement(), e.getPrayer(), e.getCreatedAt().toString(), e.isCrisis(),
                e.isFavorite());
    }

    /** Accepts ISO instants ("…Z") and, for older app builds, offset-less local timestamps (read as UTC). */
    static Instant parseInstant(String s) {
        try {
            return Instant.parse(s);
        } catch (DateTimeParseException e) {
            try {
                return LocalDateTime.parse(s).toInstant(ZoneOffset.UTC);
            } catch (DateTimeParseException e2) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "createdAt must be ISO-8601");
            }
        }
    }
}
