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

    /**
     * A request in [text]; or a ready prayer [prayerId], or a Bible [verse] ("JHN 3:16"), with [text] as an
     * optional note; or with [praise], a praise report in [text].
     * [forLeaders]: only the owner and leaders see it. [anonymous]: members don't see who asked.
     * Those two are for requests only. All but [text] may be left out (older apps).
     */
    public record NewRequest(String text, String prayerId, String verse, Boolean forLeaders, Boolean anonymous,
                             Boolean praise) {}

    /** [testimony]: how God answered, for the praise wall; may be left out. */
    public record Answered(String testimony) {}

    public record NewGroup(String name) {}

    /** [startsAt]: ISO time. Turns of [slotMinutes] (60 for a prayer chain, 1440 for fasting days). */
    public record NewChain(String title, String startsAt, int slotMinutes, int slots) {}

    private static final Pattern INSTALL_ID = Pattern.compile("[A-Za-z0-9-]{16,64}");

    private final CircleService circles;
    private final CommunityService community;
    private final RateLimiter writes;
    private final RateLimiter addressWrites;
    private final RateLimiter joins;

    @Autowired
    public CircleController(CircleService circles, CommunityService community) {
        this(circles, community, new RateLimiter(120), new RateLimiter(3000), new RateLimiter(20));
    }

    /**
     * [writes]: changes per hour per install, plenty for a person. [addressWrites]: per internet address,
     * far higher, because a whole church on its Wi-Fi shares one address on a Sunday. [joins]: tries per
     * hour per install, so codes can't be guessed by trying them (there are about a billion).
     */
    CircleController(CircleService circles, CommunityService community, RateLimiter writes,
                     RateLimiter addressWrites, RateLimiter joins) {
        this.circles = circles;
        this.community = community;
        this.writes = writes;
        this.addressWrites = addressWrites;
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
        limit(installId, http);
        return circles.create(device, name, member);
    }

    @PostMapping("/join")
    public Detail join(@RequestHeader("X-Install-Id") String installId, @RequestBody Join body, HttpServletRequest http) {
        String device = device(installId);
        String member = valid(CircleService.cleanName(body.memberName(), CircleService.MAX_NAME));
        limit(installId, http);
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
        limit(installId, http);
        circles.leave(device, code(code));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{code}/members/{memberId}")
    public Detail removeMember(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                               @PathVariable long memberId, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.removeMember(device, code(code), memberId);
    }

    @PostMapping("/{code}/members/{memberId}/leader")
    public Detail makeLeader(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                             @PathVariable long memberId, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.setLeader(device, code(code), memberId, true);
    }

    @DeleteMapping("/{code}/members/{memberId}/leader")
    public Detail unmakeLeader(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                               @PathVariable long memberId, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.setLeader(device, code(code), memberId, false);
    }

    @PostMapping("/{code}/requests")
    public Detail addRequest(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                             @RequestBody NewRequest body, HttpServletRequest http) {
        String device = device(installId);
        String prayerId = null, verse = null;
        String text;
        if (body.prayerId() != null || body.verse() != null) {
            if (body.prayerId() != null) prayerId = valid(CircleService.cleanPrayerId(body.prayerId()));
            else verse = valid(CircleService.cleanVerse(body.verse()));
            text = body.text() == null || body.text().isBlank() ? "" : valid(CircleService.cleanText(body.text()));
        } else {
            text = valid(CircleService.cleanText(body.text()));
        }
        // A shared prayer or verse is for everyone, with the sharer's name; so is a praise report.
        boolean request = prayerId == null && verse == null;
        boolean praise = request && Boolean.TRUE.equals(body.praise());
        boolean forLeaders = request && !praise && Boolean.TRUE.equals(body.forLeaders());
        boolean anonymous = request && !praise && Boolean.TRUE.equals(body.anonymous());
        limit(installId, http);
        return circles.addRequest(device, code(code), text, prayerId, verse, forLeaders, anonymous, praise);
    }

    @PostMapping("/{code}/requests/{id}/heart")
    public Detail heart(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                        @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.heart(device, code(code), id, true);
    }

    @DeleteMapping("/{code}/requests/{id}/heart")
    public Detail unheart(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                          @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.heart(device, code(code), id, false);
    }

    @PostMapping("/{code}/requests/{id}/prayed")
    public Detail prayed(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                         @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.prayed(device, code(code), id);
    }

    /** With an optional body {testimony}: how God answered, for the praise wall. */
    @PostMapping("/{code}/requests/{id}/answered")
    public Detail answered(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                           @PathVariable long id, @RequestBody(required = false) Answered body,
                           HttpServletRequest http) {
        String device = device(installId);
        String testimony = body == null || body.testimony() == null || body.testimony().isBlank()
                ? null : valid(CircleService.cleanText(body.testimony()));
        limit(installId, http);
        return circles.answered(device, code(code), id, testimony);
    }

    // ── For a church ────────────────────────────────────────────────────────

    @PostMapping("/{code}/groups")
    public Detail createGroup(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                              @RequestBody NewGroup body, HttpServletRequest http) {
        String device = device(installId);
        String name = valid(CircleService.cleanName(body.name(), CircleService.MAX_CIRCLE_NAME));
        limit(installId, http);
        return circles.createGroup(device, code(code), name);
    }

    @PostMapping("/{code}/approval")
    public Detail approvalOn(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                             HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.setApproval(device, code(code), true);
    }

    @DeleteMapping("/{code}/approval")
    public Detail approvalOff(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                              HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.setApproval(device, code(code), false);
    }

    @PostMapping("/{code}/waiting/{id}/approve")
    public Detail approve(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                          @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.approve(device, code(code), id);
    }

    @DeleteMapping("/{code}/waiting/{id}")
    public Detail decline(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                          @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.decline(device, code(code), id);
    }

    /** A chain may start up to a day ago (set up a little late) and up to a year ahead. */
    @PostMapping("/{code}/chains")
    public Detail createChain(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                              @RequestBody NewChain body, HttpServletRequest http) {
        String device = device(installId);
        String title = valid(CircleService.cleanName(body.title(), CircleService.MAX_CHAIN_TITLE));
        Instant startsAt;
        try {
            startsAt = Instant.parse(body.startsAt());
        } catch (DateTimeParseException | NullPointerException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        Instant now = Instant.now();
        if (startsAt.isBefore(now.minusSeconds(86400)) || startsAt.isAfter(now.plusSeconds(366L * 86400))
                || !CircleService.validChain(body.slotMinutes(), body.slots())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST);
        }
        limit(installId, http);
        return circles.createChain(device, code(code), title, startsAt, body.slotMinutes(), body.slots());
    }

    @DeleteMapping("/{code}/chains/{id}")
    public Detail deleteChain(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                              @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.deleteChain(device, code(code), id);
    }

    @PostMapping("/{code}/chains/{id}/turns/{slot}")
    public Detail takeTurn(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                           @PathVariable long id, @PathVariable int slot, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.turn(device, code(code), id, slot, true);
    }

    @DeleteMapping("/{code}/chains/{id}/turns/{slot}")
    public Detail giveBackTurn(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                               @PathVariable long id, @PathVariable int slot, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.turn(device, code(code), id, slot, false);
    }

    @PostMapping("/{code}/requests/{id}/pin")
    public Detail pin(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                      @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.pin(device, code(code), id, true);
    }

    @DeleteMapping("/{code}/requests/{id}/pin")
    public Detail unpin(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                        @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.pin(device, code(code), id, false);
    }

    @PostMapping("/{code}/requests/{id}/report")
    public Detail report(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                         @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
        return circles.report(device, code(code), id);
    }

    @DeleteMapping("/{code}/requests/{id}")
    public Detail deleteRequest(@RequestHeader("X-Install-Id") String installId, @PathVariable String code,
                                @PathVariable long id, HttpServletRequest http) {
        String device = device(installId);
        limit(installId, http);
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

    private void limit(String installId, HttpServletRequest http) {
        try {
            addressWrites.check("ip:" + http.getRemoteAddr());
            writes.check("install:" + installId);
        } catch (RateLimiter.LimitExceededException e) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS);
        }
    }
}
