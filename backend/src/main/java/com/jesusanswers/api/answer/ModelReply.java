package com.jesusanswers.api.answer;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonPropertyDescription;

/** Structured output Claude must return; the JSON schema is derived from this record. */
public record ModelReply(
        @JsonPropertyDescription("1-3 themes from the allowed theme list, most relevant first.")
        List<String> themes,

        @JsonPropertyDescription("1-2 verse references copied exactly from the Scripture index, best first.")
        List<String> verseRefs,

        @JsonPropertyDescription("Encouragement in the requested language, 2-4 sentences.")
        String encouragement,

        @JsonPropertyDescription("A first-person prayer in the requested language, 3-5 sentences, ending with Amen.")
        String prayer,

        @JsonPropertyDescription("True if the person may be at risk of suicide, self-harm, abuse or other danger.")
        boolean crisis) {}
