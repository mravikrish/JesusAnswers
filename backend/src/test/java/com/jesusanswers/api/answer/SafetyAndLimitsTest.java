package com.jesusanswers.api.answer;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;

class SafetyAndLimitsTest {

    @Test
    void detectsCrisisAcrossLanguages() {
        assertThat(Safety.isCrisis("I want to end my life")).isTrue();
        assertThat(Safety.isCrisis("मैं आत्महत्या के बारे में सोच रहा हूँ")).isTrue();
        assertThat(Safety.isCrisis("தற்கொலை எண்ணம்")).isTrue();
        assertThat(Safety.isCrisis("I am worried about my exam")).isFalse();
        assertThat(Safety.isCrisis(null)).isFalse();
    }

    @Test
    void rateLimiterAllowsQuotaThenBlocksUntilNextHour() {
        var clock = new MutableClock(Instant.parse("2026-10-01T10:00:00Z"));
        var limiter = new RateLimiter(2, clock);
        limiter.check("ip:1");
        limiter.check("ip:1");
        assertThatThrownBy(() -> limiter.check("ip:1")).isInstanceOf(RateLimiter.LimitExceededException.class);
        limiter.check("ip:2"); // other callers unaffected

        clock.now = clock.now.plus(Duration.ofHours(1));
        limiter.check("ip:1");
    }

    static class MutableClock extends Clock {
        Instant now;

        MutableClock(Instant now) {
            this.now = now;
        }

        @Override public ZoneOffset getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return now; }
    }
}
