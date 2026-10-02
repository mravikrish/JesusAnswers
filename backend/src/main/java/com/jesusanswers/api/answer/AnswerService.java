package com.jesusanswers.api.answer;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Service;

import com.jesusanswers.api.answer.AnswerDtos.AnswerRequest;
import com.jesusanswers.api.answer.AnswerDtos.AnswerResponse;
import com.jesusanswers.api.bible.BibleCorpus;

/** Question → understanding → Scripture → encouragement → prayer, with safety and grounding checks. */
@Service
public class AnswerService {

    static final String CRISIS_REF = "PSA 34:18";
    private static final List<String> FALLBACK_THEMES = List.of("peace", "hope", "faith");

    private final LlmClient llm;
    private final PromptBuilder prompts;
    private final BibleCorpus corpus;

    public AnswerService(LlmClient llm, PromptBuilder prompts, BibleCorpus corpus) {
        this.llm = llm;
        this.prompts = prompts;
        this.corpus = corpus;
    }

    /** @throws LlmClient.LlmUnavailableException when no answer can be produced; the app then answers offline. */
    public AnswerResponse answer(AnswerRequest request) {
        ModelReply reply = llm.reply(prompts.systemPrompt(), prompts.userMessage(request));

        boolean crisis = reply.crisis() || Safety.isCrisis(request.question());

        List<String> themes = safe(reply.themes()).stream()
                .filter(corpus.themes()::contains)
                .distinct().limit(3).toList();
        if (themes.isEmpty()) themes = FALLBACK_THEMES;

        // Only references that exist in the corpus survive; the app renders their verbatim text.
        Set<String> refs = new LinkedHashSet<>();
        if (crisis) refs.add(CRISIS_REF);
        safe(reply.verseRefs()).stream().map(String::strip).filter(corpus::isKnownRef).forEach(refs::add);
        if (refs.isEmpty()) refs.addAll(corpus.refsForThemes(themes, 2));

        if (isBlank(reply.encouragement()) || isBlank(reply.prayer())) {
            throw new LlmClient.LlmUnavailableException("Incomplete reply", null);
        }
        return new AnswerResponse(themes, new ArrayList<>(refs).subList(0, Math.min(2, refs.size())),
                reply.encouragement().strip(), reply.prayer().strip(), crisis);
    }

    private static <T> List<T> safe(List<T> list) {
        return list == null ? List.of() : list;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
