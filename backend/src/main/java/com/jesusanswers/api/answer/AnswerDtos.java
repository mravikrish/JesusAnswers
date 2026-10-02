package com.jesusanswers.api.answer;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Wire format of POST /v1/answers — matches RemoteAnswerService in the app. */
public final class AnswerDtos {

    private AnswerDtos() {}

    public enum Kind { question, prayer }

    public record AnswerRequest(
            @NotBlank @Size(max = 2000) String question,
            @NotBlank @Pattern(regexp = "en|hi|te|ta|kn|ml|mr|pa|bn|gu|or") String lang,
            @Size(max = 32) String mood,
            Kind kind) {

        public Kind kindOrDefault() {
            return kind == null ? Kind.question : kind;
        }
    }

    public record AnswerResponse(
            List<String> themes,
            List<String> verseRefs,
            String encouragement,
            String prayer,
            boolean crisis) {}
}
