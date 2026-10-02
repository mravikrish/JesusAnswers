package com.jesusanswers.api.answer;

/** Seam between answer orchestration and the model, so the pipeline is testable without network. */
public interface LlmClient {

    /** Returns the model's structured reply, or throws {@link LlmUnavailableException}. */
    ModelReply reply(String systemPrompt, String userMessage);

    class LlmUnavailableException extends RuntimeException {
        public LlmUnavailableException(String message, Throwable cause) {
            super(message, cause);
        }
    }
}
