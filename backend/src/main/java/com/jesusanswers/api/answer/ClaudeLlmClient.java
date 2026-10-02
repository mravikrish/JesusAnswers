package com.jesusanswers.api.answer;

import java.time.Duration;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.core.JsonValue;
import com.anthropic.errors.AnthropicException;
import com.anthropic.models.messages.CacheControlEphemeral;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.StructuredMessage;
import com.anthropic.models.messages.StructuredMessageCreateParams;
import com.anthropic.models.messages.TextBlockParam;

/**
 * Claude via the official Java SDK, with structured output ({@link ModelReply}), the system prompt
 * prompt-cached, and server-side refusal fallbacks enabled.
 */
@Component
public class ClaudeLlmClient implements LlmClient {

    private static final Logger log = LoggerFactory.getLogger(ClaudeLlmClient.class);

    private final AnthropicClient client;
    private final String model;
    private final OutputConfig.Effort effort;

    public ClaudeLlmClient(
            @Value("${jesusanswers.claude.model}") String model,
            @Value("${jesusanswers.claude.effort}") String effort,
            @Value("${jesusanswers.claude.timeout-seconds}") long timeoutSeconds) {
        // Reads ANTHROPIC_API_KEY (or another configured credential) from the environment.
        this.client = AnthropicOkHttpClient.builder()
                .fromEnv()
                .timeout(Duration.ofSeconds(timeoutSeconds))
                .build();
        this.model = model;
        this.effort = OutputConfig.Effort.of(effort);
    }

    @Override
    public ModelReply reply(String systemPrompt, String userMessage) {
        StructuredMessageCreateParams<ModelReply> params = buildParams(systemPrompt, userMessage);

        StructuredMessage<ModelReply> response;
        try {
            response = client.messages().create(params);
        } catch (AnthropicException e) {
            throw new LlmUnavailableException("Claude request failed", e);
        }
        return parse(response);
    }

    StructuredMessageCreateParams<ModelReply> buildParams(String systemPrompt, String userMessage) {
        return MessageCreateParams.builder()
                .model(model)
                .maxTokens(8000L)
                .systemOfTextBlockParams(List.of(TextBlockParam.builder()
                        .text(systemPrompt)
                        .cacheControl(CacheControlEphemeral.builder().ttl(CacheControlEphemeral.Ttl.TTL_1H).build())
                        .build()))
                .outputConfig(OutputConfig.builder().effort(effort).build())
                // If a safety classifier declines, re-run on Anthropic's recommended fallback model
                // instead of returning nothing to someone who reached out.
                .putAdditionalHeader("anthropic-beta", "server-side-fallback-2026-07-01")
                .putAdditionalBodyProperty("fallbacks", JsonValue.from("default"))
                .outputConfig(ModelReply.class)
                .addUserMessage(userMessage)
                .build();
    }

    private ModelReply parse(StructuredMessage<ModelReply> response) {
        // Never log the person's message or the reply — only operational metadata.
        log.info("claude model={} stop={} in={} out={} cacheRead={} cacheWrite={}",
                response.model(), response.stopReason().map(Object::toString).orElse("?"),
                response.usage().inputTokens(), response.usage().outputTokens(),
                response.usage().cacheReadInputTokens().orElse(0L),
                response.usage().cacheCreationInputTokens().orElse(0L));

        if (response.stopReason().filter(StopReason.REFUSAL::equals).isPresent()) {
            throw new LlmUnavailableException("Claude declined the request", null);
        }
        return response.content().stream()
                .flatMap(block -> block.text().stream())
                .map(text -> text.text())
                .findFirst()
                .orElseThrow(() -> new LlmUnavailableException("No structured reply in response", null));
    }
}
