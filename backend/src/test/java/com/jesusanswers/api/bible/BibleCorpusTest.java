package com.jesusanswers.api.bible;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.json.JsonMapper;

public class BibleCorpusTest {

    public static final BibleCorpus corpus = create();

    static BibleCorpus create() {
        try {
            return new BibleCorpus(JsonMapper.builder().build());
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @Test
    void everyIndexedVerseExistsInEveryLanguage() {
        for (String lang : BibleCorpus.LANGUAGES) {
            for (BibleCorpus.IndexEntry e : corpus.index()) {
                assertThat(corpus.verse(e.ref(), lang)).as(lang + " " + e.ref()).isPresent();
            }
        }
    }

    @Test
    void rendersVerbatimTextWithLocalizedReference() {
        Verse en = corpus.verse("MAT 6:34", "en").orElseThrow();
        assertThat(en.reference()).isEqualTo("Matthew 6:34");
        assertThat(en.text()).startsWith("Take therefore no thought for the morrow");

        Verse te = corpus.verse("MAT 6:34", "te").orElseThrow();
        assertThat(te.reference()).isEqualTo("మత్తయి 6:34");
        assertThat(te.translation()).isEqualTo("IRV");
    }

    @Test
    void unknownRefsAreRejected() {
        assertThat(corpus.isKnownRef("JHN 3:16")).isFalse(); // real verse, but not in our index
        assertThat(corpus.isKnownRef("MAT 6:34")).isTrue();
        assertThat(corpus.verse("XYZ 1:1", "en")).isEmpty();
    }

    @Test
    void picksVersesByThemeWeight() {
        assertThat(corpus.refsForThemes(java.util.List.of("sleep"), 2)).contains("PSA 4:8");
    }
}
