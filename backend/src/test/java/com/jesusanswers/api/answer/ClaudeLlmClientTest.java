package com.jesusanswers.api.answer;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;

/** Checks the request we send to Claude without calling the API. */
class ClaudeLlmClientTest {

    final MessageCreateParams params =
            new ClaudeLlmClient("claude-opus-5-5", "medium", 25).buildParams("SYSTEM", "USER").rawParams();

    @Test
    void keepsEffortAndAddsStructuredFormat() {
        OutputConfig config = params.outputConfig().orElseThrow();
        assertThat(config.effort()).contains(OutputConfig.Effort.MEDIUM);
        assertThat(config.format()).isPresent();
    }

    @Test
    void cachesTheSystemPrompt() {
        var block = params.system().orElseThrow().asTextBlockParams().get(0);
        assertThat(block.text()).isEqualTo("SYSTEM");
        assertThat(block.cacheControl()).isPresent();
    }

    @Test
    void optsIntoServerSideFallbacks() {
        assertThat(params._additionalBodyProperties()).containsKey("fallbacks");
        assertThat(params._additionalHeaders().values("anthropic-beta"))
                .contains("server-side-fallback-2026-07-01");
        assertThat(params.model().asString()).isEqualTo("claude-opus-5-5");
    }
}
