package com.jesusanswers.api.bible;

import java.io.IOException;
import java.io.InputStream;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import tools.jackson.databind.json.JsonMapper;

/**
 * The verbatim Scripture corpus shared with the app (assets/bible, built by tool/build_bible.dart).
 *
 * <p>The model may only <em>choose</em> references from {@link #index()}; verse text always comes
 * from these files, so Scripture can never be invented.
 */
@Component
public class BibleCorpus {

    public static final List<String> LANGUAGES =
            List.of("en", "hi", "te", "ta", "kn", "ml", "mr", "pa", "bn", "gu", "or");

    public record IndexEntry(String ref, List<String> themes) {}

    record IndexFile(List<IndexEntry> verses) {}

    record TranslationFile(String lang, String translation, String translationName, String attribution,
                           Map<String, String> books, Map<String, String> verses) {}

    private final List<IndexEntry> index;
    private final Set<String> refs;
    private final Set<String> themes;
    private final Map<String, TranslationFile> translations = new HashMap<>();

    public BibleCorpus(JsonMapper json) throws IOException {
        this.index = read(json, "bible/index.json", IndexFile.class).verses().stream()
                .sorted(Comparator.comparing(IndexEntry::ref)) // stable order keeps the prompt cacheable
                .toList();
        this.refs = index.stream().map(IndexEntry::ref).collect(Collectors.toUnmodifiableSet());
        this.themes = index.stream().flatMap(e -> e.themes().stream())
                .collect(Collectors.toCollection(java.util.TreeSet::new));
        for (String lang : LANGUAGES) {
            translations.put(lang, read(json, "bible/" + lang + ".json", TranslationFile.class));
        }
    }

    private static <T> T read(JsonMapper json, String path, Class<T> type) throws IOException {
        try (InputStream in = new ClassPathResource(path).getInputStream()) {
            return json.readValue(in, type);
        }
    }

    public List<IndexEntry> index() {
        return index;
    }

    public Set<String> themes() {
        return themes;
    }

    public boolean isKnownRef(String ref) {
        return refs.contains(ref);
    }

    public static boolean isSupported(String lang) {
        return LANGUAGES.contains(lang);
    }

    public Optional<Verse> verse(String ref, String lang) {
        TranslationFile t = translations.getOrDefault(lang, translations.get("en"));
        String text = t.verses().get(ref);
        if (text == null) return Optional.empty();
        String book = ref.substring(0, ref.indexOf(' '));
        String reference = t.books().getOrDefault(book, book) + ref.substring(ref.indexOf(' '));
        return Optional.of(new Verse(ref, reference, text, t.translation(), t.lang()));
    }

    public String attribution(String lang) {
        return translations.getOrDefault(lang, translations.get("en")).attribution();
    }

    /** Best verses for themes ordered by importance — used when the model's picks are unusable. */
    public List<String> refsForThemes(List<String> wanted, int count) {
        Map<String, Integer> weight = new HashMap<>();
        for (int i = 0; i < wanted.size(); i++) weight.putIfAbsent(wanted.get(i), wanted.size() - i);
        return index.stream()
                .map(e -> Map.entry(e.ref(), score(e.themes(), weight)))
                .filter(e -> e.getValue() > 0)
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                .limit(count)
                .map(Map.Entry::getKey)
                .collect(Collectors.toCollection(LinkedHashSet::new))
                .stream().toList();
    }

    /** A verse whose primary (first) theme matches counts double. */
    private static int score(List<String> verseThemes, Map<String, Integer> weight) {
        int score = 0;
        for (int j = 0; j < verseThemes.size(); j++) {
            score += weight.getOrDefault(verseThemes.get(j), 0) * (j == 0 ? 2 : 1);
        }
        return score;
    }
}
