package com.jesusanswers.api.circle;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Random;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.journey.EncryptedStringConverter;

/**
 * Prayer circles: someone starts one, shares its code, and the people who join pray for each
 * other's requests. Members are a salted hash of the install id ("device"), never an account.
 * Requests are encrypted at rest and only members can read them.
 */
@Service
public class CircleService {

    /** No I, O, 0 or 1, so a code read out over the phone can't be mistaken. */
    static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static final int CODE_LENGTH = 6;

    static final int MAX_MEMBERS = 100;
    static final int MAX_CIRCLES_PER_DEVICE = 20;
    static final int MAX_NAME = 40, MAX_CIRCLE_NAME = 60, MAX_TEXT = 1000;

    /** Requests older than this are no longer shown, and are deleted as new ones come in. */
    static final int KEEP_DAYS = 60;

    public record Summary(String code, String name, int members, boolean owner, Instant latest) {}

    public record Member(long id, String name, boolean owner, boolean me) {}

    public record Request(long id, long memberId, String name, String text, Instant at, boolean answered,
                          long prayed, boolean prayedByMe, boolean mine) {}

    public record Detail(String code, String name, boolean owner, List<Member> members, List<Request> requests) {}

    private record Membership(long circleId, long memberId, boolean owner) {}

    private final JdbcTemplate db;
    private final EncryptedStringConverter crypto;
    private final Random random = new SecureRandom();

    public CircleService(JdbcTemplate db, EncryptedStringConverter crypto) {
        this.db = db;
        this.crypto = crypto;
    }

    // ── Rules that need no database ─────────────────────────────────────────

    static String newCode(Random random) {
        var code = new StringBuilder();
        for (int i = 0; i < CODE_LENGTH; i++) code.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        return code.toString();
    }

    /** "k7p-3mx " → "K7P3MX"; null when it can't be a code. */
    static String normalizeCode(String input) {
        if (input == null) return null;
        String code = input.toUpperCase().replaceAll("[\\s-]", "");
        if (code.length() != CODE_LENGTH) return null;
        for (char c : code.toCharArray()) if (ALPHABET.indexOf(c) < 0) return null;
        return code;
    }

    /** A name on one line, trimmed; null when empty or longer than [max] characters. */
    static String cleanName(String input, int max) {
        if (input == null) return null;
        String name = input.replaceAll("\\p{Cc}", " ").replaceAll("\\s+", " ").strip();
        return name.isEmpty() || name.codePointCount(0, name.length()) > max ? null : name;
    }

    /** Request text keeps its line breaks; null when empty or too long. */
    static String cleanText(String input) {
        if (input == null) return null;
        String text = input.replaceAll("[\\p{Cc}&&[^\\n]]", "").replaceAll("\\n{3,}", "\n\n").strip();
        return text.isEmpty() || text.codePointCount(0, text.length()) > MAX_TEXT ? null : text;
    }

    /**
     * A reported request is removed for everyone once 3 members, or half of the others, have reported it.
     * In a circle of two, one report is enough: the reporter is the only one reading it.
     */
    static boolean removedByReports(long reports, long members) {
        return reports >= 3 || reports * 2 >= members - 1;
    }

    // ── Circles ─────────────────────────────────────────────────────────────

    public List<Summary> mine(String device) {
        return db.query("""
                select c.code, c.name, m.owner,
                       (select count(*) from circle_member o where o.circle_id = c.id and not o.removed),
                       (select max(r.created_at) from circle_request r where r.circle_id = c.id)
                from circle c join circle_member m on m.circle_id = c.id
                where m.device = ? and not m.removed
                order by m.joined_at""",
                (rs, i) -> new Summary(rs.getString(1), rs.getString(2), rs.getInt(4), rs.getBoolean(3),
                        instant(rs.getTimestamp(5))),
                device);
    }

    @Transactional
    public Detail create(String device, String name, String memberName) {
        checkRoomForAnother(device);
        Long id = null;
        String code = null;
        for (int attempt = 0; id == null; attempt++) {
            code = newCode(random);
            try {
                id = db.queryForObject("insert into circle (code, name) values (?, ?) returning id", Long.class, code, name);
            } catch (DuplicateKeyException e) {
                if (attempt >= 5) throw e;
            }
        }
        db.update("insert into circle_member (circle_id, device, name, owner) values (?, ?, ?, true)", id, device, memberName);
        return detail(device, code);
    }

    @Transactional
    public Detail join(String device, String code, String memberName) {
        Long id = db.query("select id from circle where code = ? for update", rs -> rs.next() ? rs.getLong(1) : null, code);
        if (id == null) throw status(HttpStatus.NOT_FOUND, "no-circle");
        Boolean removed = db.query("select removed from circle_member where circle_id = ? and device = ?",
                rs -> rs.next() ? rs.getBoolean(1) : null, id, device);
        if (Boolean.TRUE.equals(removed)) throw status(HttpStatus.FORBIDDEN, "removed");
        if (removed == null) {
            Long members = db.queryForObject("select count(*) from circle_member where circle_id = ? and not removed",
                    Long.class, id);
            if (members != null && members >= MAX_MEMBERS) throw status(HttpStatus.CONFLICT, "full");
            checkRoomForAnother(device);
            db.update("insert into circle_member (circle_id, device, name) values (?, ?, ?)", id, device, memberName);
        } else {
            // Already in it: joining again just updates the name the others see.
            db.update("update circle_member set name = ? where circle_id = ? and device = ?", memberName, id, device);
        }
        return detail(device, code);
    }

    public Detail detail(String device, String code) {
        Membership me = membership(device, code);
        String name = db.queryForObject("select name from circle where id = ?", String.class, me.circleId());
        List<Member> members = db.query("""
                select id, name, owner, device = ? from circle_member
                where circle_id = ? and not removed order by owner desc, joined_at""",
                (rs, i) -> new Member(rs.getLong(1), rs.getString(2), rs.getBoolean(3), rs.getBoolean(4)),
                device, me.circleId());
        List<Request> requests = db.query("""
                select r.id, m.id, m.name, r.text, r.created_at, r.answered_at is not null,
                       (select count(*) from circle_prayed p where p.request_id = r.id),
                       exists (select 1 from circle_prayed p where p.request_id = r.id and p.device = ?),
                       r.device = ?
                from circle_request r
                join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
                where r.circle_id = ? and r.created_at > now() - make_interval(days => ?)
                  and not exists (select 1 from circle_report x where x.request_id = r.id and x.device = ?)
                order by r.created_at desc
                limit 100""",
                (rs, i) -> new Request(rs.getLong(1), rs.getLong(2), rs.getString(3),
                        crypto.convertToEntityAttribute(rs.getString(4)), instant(rs.getTimestamp(5)),
                        rs.getBoolean(6), rs.getLong(7), rs.getBoolean(8), rs.getBoolean(9)),
                device, device, me.circleId(), KEEP_DAYS, device);
        return new Detail(code, name, me.owner(), members, requests);
    }

    /** Takes the member's requests with them. The owner's place passes to whoever joined first after them. */
    @Transactional
    public void leave(String device, String code) {
        Membership me = membership(device, code);
        db.update("delete from circle_request where circle_id = ? and device = ?", me.circleId(), device);
        db.update("delete from circle_member where circle_id = ? and device = ?", me.circleId(), device);
        if (!me.owner()) return;
        int passed = db.update("""
                update circle_member set owner = true
                where id = (select id from circle_member where circle_id = ? and not removed order by joined_at limit 1)""",
                me.circleId());
        if (passed == 0) db.update("delete from circle where id = ?", me.circleId());
    }

    /** Owner only: takes a member out, with their requests, and they can't join again. */
    @Transactional
    public Detail removeMember(String device, String code, long memberId) {
        Membership me = membership(device, code);
        if (!me.owner() || me.memberId() == memberId) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        String gone = db.query("select device from circle_member where id = ? and circle_id = ? and not removed",
                rs -> rs.next() ? rs.getString(1) : null, memberId, me.circleId());
        if (gone == null) throw status(HttpStatus.NOT_FOUND, "no-member");
        db.update("update circle_member set removed = true where id = ?", memberId);
        db.update("delete from circle_request where circle_id = ? and device = ?", me.circleId(), gone);
        return detail(device, code);
    }

    // ── Requests ────────────────────────────────────────────────────────────

    @Transactional
    public Detail addRequest(String device, String code, String text) {
        Membership me = membership(device, code);
        db.update("insert into circle_request (circle_id, device, text) values (?, ?, ?)",
                me.circleId(), device, crypto.convertToDatabaseColumn(text));
        db.update("delete from circle_request where circle_id = ? and created_at < now() - make_interval(days => ?)",
                me.circleId(), KEEP_DAYS);
        return detail(device, code);
    }

    public Detail prayed(String device, String code, long requestId) {
        Membership me = membership(device, code);
        author(me, requestId);
        db.update("insert into circle_prayed (request_id, device) values (?, ?) on conflict do nothing", requestId, device);
        return detail(device, code);
    }

    /** Only whoever asked can say God answered it. */
    public Detail answered(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (!device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("update circle_request set answered_at = coalesce(answered_at, now()) where id = ?", requestId);
        return detail(device, code);
    }

    /** Whoever asked, or the circle's owner. */
    public Detail deleteRequest(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (!me.owner() && !device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("delete from circle_request where id = ?", requestId);
        return detail(device, code);
    }

    @Transactional
    public Detail report(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("insert into circle_report (request_id, device) values (?, ?) on conflict do nothing", requestId, device);
        Long reports = db.queryForObject("select count(*) from circle_report where request_id = ?", Long.class, requestId);
        Long members = db.queryForObject("select count(*) from circle_member where circle_id = ? and not removed",
                Long.class, me.circleId());
        if (removedByReports(reports == null ? 0 : reports, members == null ? 0 : members)) {
            db.update("delete from circle_request where id = ?", requestId);
        }
        return detail(device, code);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Not a member (or no such circle) looks the same from outside: 404. */
    private Membership membership(String device, String code) {
        Membership m = db.query("""
                select c.id, m.id, m.owner from circle c join circle_member m on m.circle_id = c.id
                where c.code = ? and m.device = ? and not m.removed""",
                rs -> rs.next() ? new Membership(rs.getLong(1), rs.getLong(2), rs.getBoolean(3)) : null,
                code, device);
        if (m == null) throw status(HttpStatus.NOT_FOUND, "no-circle");
        return m;
    }

    /** The device that asked [requestId], which must be in this circle. */
    private String author(Membership me, long requestId) {
        String device = db.query("select device from circle_request where id = ? and circle_id = ?",
                rs -> rs.next() ? rs.getString(1) : null, requestId, me.circleId());
        if (device == null) throw status(HttpStatus.NOT_FOUND, "no-request");
        return device;
    }

    private void checkRoomForAnother(String device) {
        Long count = db.queryForObject("select count(*) from circle_member where device = ? and not removed",
                Long.class, device);
        // Its own status, so the app can tell it from a full circle (409): error bodies carry no reason.
        if (count != null && count >= MAX_CIRCLES_PER_DEVICE) throw status(HttpStatus.UNPROCESSABLE_CONTENT, "too-many");
    }

    private static Instant instant(Timestamp t) {
        return t == null ? null : t.toInstant();
    }

    private static ResponseStatusException status(HttpStatus status, String reason) {
        return new ResponseStatusException(status, reason);
    }
}
