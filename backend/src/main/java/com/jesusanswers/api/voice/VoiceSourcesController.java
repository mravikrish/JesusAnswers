package com.jesusanswers.api.voice;

import java.time.Duration;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Where the app downloads its natural voices from, tried in order. Changing VOICE_SOURCES moves
 * every phone to a new host without an app update; the app still tries its built-in hosts after these.
 * Each is a URL template — see VoiceSources in the app's natural_voices.dart for {id}, {name}, {path}, {file}.
 */
@RestController
public class VoiceSourcesController {

    public record VoiceSources(List<String> sources) {}

    private final VoiceSources sources;

    public VoiceSourcesController(@Value("${jesusanswers.voice-sources:}") List<String> sources) {
        this.sources = new VoiceSources(sources.stream().map(String::trim).filter(s -> s.startsWith("https://")).toList());
    }

    @GetMapping("/v1/voice-sources")
    public ResponseEntity<VoiceSources> sources() {
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofHours(1))).body(sources);
    }
}
