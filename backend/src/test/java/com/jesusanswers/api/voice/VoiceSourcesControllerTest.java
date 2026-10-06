package com.jesusanswers.api.voice;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;

class VoiceSourcesControllerTest {

    @Test
    void sendsOnlyHttpsHostsInOrder() {
        var controller = new VoiceSourcesController(List.of(
                " https://github.com/o/r/releases/download/v1/{file}", "", "http://insecure.example/{path}",
                "https://cdn.example/voices/{path}"));
        assertThat(controller.sources().getBody().sources()).containsExactly(
                "https://github.com/o/r/releases/download/v1/{file}", "https://cdn.example/voices/{path}");
    }

    @Test
    void emptyWhenNotConfigured() {
        assertThat(new VoiceSourcesController(List.of()).sources().getBody().sources()).isEmpty();
    }
}
