package com.jesusanswers.api.circle;

import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.answer.RateLimiter;
import com.jesusanswers.api.circle.CircleService.Detail;
import com.jesusanswers.api.circle.CircleService.NewsPage;
import com.jesusanswers.api.circle.CircleService.Summary;
import com.jesusanswers.api.community.CommunityService;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Prayer circles. Anonymous like the shared counts: the app sends its random install id
 * (X-Install-Id), and only a salted hash of it is kept. Every change answers with the circle as it now is.
 */
@RestController
@RequestMapping("/v1/circles")
public class CircleController {

    public record NewCircle(String name, String memberName) {}

    public record Join(String code, String memberName) {}

    /** A request in [text]; or a ready prayer, [prayerId], with [text] as an optional note. */
    public record NewRequest(String text, String prayerId) {}

    private static final Pattern INSTALL_ID = Pattern.compile("[A-Za-z0-9-]{16,64}");

    private final CircleService circles;
    private final CommunityService community;
    private final RateLimiter writes;
    private final RateLimiter joins;

    @Autowired
    public CircleController(CircleService circles, CommunityService community) {
        this(circles, community, new RateLimiter(120), new RateLimiter(20));
    }

    /**
     * [writes]: changes per hour, plenty for a person. [joins]: tries per hour per install, so codes
     * can't be guessed by trying them (there are about a billion).
     */
    CircleController(CircleService circles, CommunityService community, RateLimiter writes, RateLimiter joins) {
        this.circles = circles;
        this.community = community;
        this.writes = writes;
        this.joins = joins;
    }

    @GetMapping
    public List<Summary> mine(@RequestHeader("X-Install-Id") String installId) {
        return circles.mine(device(installId));
    }

    /** What's new since [since] (ISO time from the last answer's `now`); none the first time. */
    @GetMapping("/news")
    public NewsPage news(@RequestHeader("X-Install-Id") String installId,
                         @RequestParam(required = false) String since) {
        Instant from = null;
        if (since != null) {
            try {
                from = Instant.parse(since);
            } catch (DateTimeParseException e) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
            }
        }
        return circles.news(device(installId), from);
    }

    @PostMapping
    public Detail create(@RequestHeader("X-Install-Id") String installId, @RequestBody NewCircle body,
                         HttpServletRequest http) {
        String device = device(installId);
        String name = valid(CircleService.cleanName(body.name(), CircleService.MAX_CIRCLE_NAME));
        String member = valid(CircleService.cleanName(body.memberName(), CircleService.MAX_NAME));
        limit(writes, installId, http);
        return circles.create(device, name, member);
    }

    @PostMapping("/join")
    public Detail join(@RequestHeader("X-Install-Id") String installId, @RequestBody Join body, HttpServletRequest http) {
        String device = device(installId);
        String member = valid(CircleService.cleanName(body.memberName(), CircleService.MAX_NAME));
        limit(writes, installId, http);
        try {
            // Per install only: many phones can share one address on mobile networks.
            joins.check("install:" + installId);
        } catch (RateLimiter.LimitExceededException e) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
        }
        String code = CircleService.normalizeCode(body.code());
        if (code == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "no-circle");
        return circles.join(device, code, member);
    }

    @GetMapping("/{code}")
    public Detail detail(@RequestHeader("X-Install-Id") String installId, @PathVariable String code) {
        return circles.detail(device(installId), code(code));
    }

    @PostMapping("/{code}/leave")
    public ResponseEntity<Void> leave(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                                      HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        circles.leave(device, code(code));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{code}/members/{memberId}")
    public Detail removeMember(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                               @PathVariable long memberId, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.removeMember(device, code(code), memberId);
    }

    @PostMapping("/{code}/requests")
    public Detail addRequest(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                             @RequestBody NewRequest body, HttpServletRequest http) {
        String device = device(installId);
        String prayerId = null;
        String text;
        if (body.prayerId() != null) {
            prayerId = valid(CircleService.cleanPrayerId(body.prayerId()));
            text = body.text() == null || body.text().isBlank() ? "" : valid(CircleService.cleanText(body.text()));
        } else {
            text = valid(CircleService.cleanText(body.text()));
        }
        limit(writes, installId, http);
        return circles.addRequest(device, code(code), text, prayerId);
    }

    @PostMapping("/{code}/requests/{id}/heart")
    public Detail heart(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                        @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.heart(device, code(code), id, true);
    }

    @DeleteMapping("/{code}/requests/{id}/heart")
    public Detail unheart(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                          @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.heart(device, code(code), id, false);
    }

    @PostMapping("/{code}/requests/{id}/prayed")
    public Detail prayed(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                         @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.prayed(device, code(code), id);
    }

    @PostMapping("/{code}/requests/{id}/answered")
    public Detail answered(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                           @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.answered(device, code(code), id);
    }

    @PostMapping("/{code}/requests/{id}/report")
    public Detail report(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                         @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.report(device, code(code), id);
    }

    @DeleteMapping("/{code}/requests/{id}")
    public Detail deleteRequest(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                                @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(writes, installId, http);
        return circles.deleteRequest(device, code(code), id);
    }

    private String device(String installId) {
        if (installId == null || !INSTALL_ID.matcher(installId).matches()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        return community.device(installId);
    }

    private static String code(String code) {
        String c = CircleService.normalizeCode(code);
        if (c == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "no-circle");
        return c;
    }

    private static String valid(String cleaned) {
        if (cleaned == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        return cleaned;
    }

    private static void limit(RateLimiter limiter, String installId, HttpServletRequest http) {
        try {
            limiter.check("ip:" + http.getRemoteAddr());
            limiter.check("install:" + installId);
        } catch (RateLimiter.LimitExceededException e) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
        }
    }
}
