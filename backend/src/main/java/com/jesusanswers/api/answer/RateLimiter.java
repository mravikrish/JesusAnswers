package com.jesusanswers.api.answer;

import java.time.Clock;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Per-caller fixed-window limit on AI answers, so one client can't run up the model bill.
 * In-memory: fine for a single instance; move to Redis or the gateway when scaling out.
 */
@Component
public class RateLimiter {

    private record Window(long hour, int count) {}

    private final Map<String, Window> windows = new ConcurrentHashMap<>();
    private final int perHour;
    private final Clock clock;

    @Autowired
    public RateLimiter(@Value("${jesusanswers.rate-limit.answers-per-hour}") int perHour) {
        this(perHour, Clock.systemUTC());
    }

    RateLimiter(int perHour, Clock clock) {
        this.perHour = perHour;
        this.clock = clock;
    }

    public void check(String caller) {
        long hour = clock.millis() / 3_600_000;
        Window w = windows.compute(caller, (k, old) ->
                old == null || old.hour() != hour ? new Window(hour, 1) : new Window(hour, old.count() + 1));
        if (w.count() > perHour) throw new LimitExceededException();
        if (windows.size() > 100_000) windows.entrySet().removeIf(e -> e.getValue().hour() != hour);
    }

    public static class LimitExceededException extends RuntimeException {}
}
