package com.jesusanswers.api.community;

import java.time.Duration;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.answer.RateLimiter;
import com.jesusanswers.api.community.CommunityService.Counts;
import com.jesusanswers.api.community.CommunityService.Kind;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/** Anonymous: the app sends its random install id (X-Install-Id), never who the person is. */
@RestController
public class CommunityController {

    public record Reaction(@NotNull String item, @NotNull Kind kind) {}

    private static final Pattern INSTALL_ID = Pattern.compile("[A-Za-z0-9-]{16,64}");

    private final CommunityService community;
    private final RateLimiter limiter;

    @Autowired
    public CommunityController(CommunityService community) {
        this(community, new RateLimiter(300));
    }

    /** [limiter]: per hour — generous for a person, low enough that one phone or address can't push counts up. */
    CommunityController(CommunityService community, RateLimiter limiter) {
        this.community = community;
        this.limiter = limiter;
    }

    @PostMapping("/v1/reactions")
    public ResponseEntity<Void> react(@RequestHeader("X-Install-Id") String installId,
                                      @Valid @RequestBody Reaction reaction, HttpServletRequest http) {
        if (!INSTALL_ID.matcher(installId).matches() || !CommunityService.validItem(reaction.item())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        try {
            limiter.check("ip:" + http.getRemoteAddr());
            limiter.check("install:" + installId);
        } catch (RateLimiter.LimitExceededException e) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
        }
        community.record(reaction.item(), reaction.kind(), installId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/v1/counts")
    public ResponseEntity<Counts> counts() {
        return ResponseEntity.ok().cacheControl(CacheControl.maxAge(Duration.ofMinutes(5)).cachePublic())
                .body(community.counts());
    }
}
