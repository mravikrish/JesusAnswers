package com.jesusanswers.api.circle;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Random;
import java.util.regex.Pattern;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.answer.Safety;
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

    /** Big enough for a whole church. */
    static final int MAX_MEMBERS = 500;
    static final int MAX_CIRCLES_PER_DEVICE = 20;
    static final int MAX_NAME = 40, MAX_CIRCLE_NAME = 60, MAX_TEXT = 1000;

    /** Requests older than this are no longer shown, and are deleted as new ones come in. */
    static final int KEEP_DAYS = 60;

    public record Summary(String code, String name, int members, boolean owner, Instant latest) {}

    /** [leader]: made a leader by the owner (the owner isn't marked a leader). */
    public record Member(long id, String name, boolean owner, boolean leader, boolean me) {}

    /**
     * [prayerId]: a shared ready prayer, with [text] as an optional note (may be empty).
     * [leader]: asked by the owner or a leader. [pinned]: the circle's prayer focus, shown first.
     * [forLeaders]: only the owner and leaders see it. [anonymous]: asked without a name; [name] is then
     * empty (and [memberId] 0) for members, and only the asker, the owner and leaders see who asked.
     */
    public record Request(long id, long memberId, String name, String text, Instant at, boolean answered,
                          long prayed, boolean prayedByMe, boolean mine, String prayerId, long hearts,
                          boolean heartedByMe, boolean leader, boolean pinned, boolean forLeaders,
                          boolean anonymous) {}

    /** [leader]: the reader is the owner or a leader, so can pin, delete requests and remove members. */
    public record Detail(String code, String name, boolean owner, boolean leader, List<Member> members,
                         List<Request> requests) {}

    /**
     * Something new in one of the person's circles, shown as a popup when they next open the app.
     * [kind]: request (someone asked), prayer (someone shared a ready prayer), prayed ([count] people
     * prayed for the person's own request), answered (God answered someone's request), joined ([count]
     * new members, the latest of them [name]).
     * [crisis]: told only to the owner and leaders, about a request from someone who may be thinking of
     * ending their life, so they reach out today. Never left out for lack of room.
     */
    public record News(String kind, String circle, String circleName, Long requestId, String name, String text,
                       String prayerId, long count, Instant at, boolean crisis) {}

    /** [now]: the server's time, to send back as `since` next time. */
    public record NewsPage(Instant now, List<News> items) {}

    static final int MAX_NEWS = 20;

    private record Membership(long circleId, long memberId, boolean owner, boolean leader) {
        boolean leads() {
            return owner || leader;
        }
    }

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

    private static final Pattern PRAYER_ID = Pattern.compile("[a-z0-9_-]{1,64}");

    /** A ready prayer's id as the app names it (e.g. "psalm23"); null when it can't be one. */
    static String cleanPrayerId(String input) {
        return input != null && PRAYER_ID.matcher(input).matches() ? input : null;
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

    /**
     * Who may take [target] out of the circle: the owner anyone else; a leader only members who
     * aren't the owner or another leader.
     */
    static boolean mayRemove(boolean owner, boolean leader, boolean targetOwner, boolean targetLeader) {
        if (owner) return !targetOwner;
        return leader && !targetOwner && !targetLeader;
    }

    /** Who asked an [anonymous] request is hidden from everyone but the asker, the owner and leaders. */
    static boolean hidesName(boolean anonymous, boolean mine, boolean readerLeads) {
        return anonymous && !mine && !readerLeads;
    }

    /**
     * The newest [MAX_NEWS] of [items] (oldest first), but every crisis alert stays, however many other
     * things happened: a leader must not miss one.
     */
    static List<News> newest(List<News> items) {
        var sorted = new ArrayList<>(items);
        sorted.sort(Comparator.comparing(News::at));
        List<News> crisis = sorted.stream().filter(News::crisis).toList();
        List<News> rest = sorted.stream().filter(n -> !n.crisis()).toList();
        int room = Math.max(0, MAX_NEWS - crisis.size());
        var kept = new ArrayList<>(crisis);
        kept.addAll(rest.size() > room ? rest.subList(rest.size() - room, rest.size()) : rest);
        kept.sort(Comparator.comparing(News::at));
        return List.copyOf(kept);
    }

    // ── Circles ─────────────────────────────────────────────────────────────

    public List<Summary> mine(String device) {
        return db.query("""
                select c.code, c.name, m.owner,
                       (select count(*) from circle_member o where o.circle_id = c.id and not o.removed),
                       (select max(r.created_at) from circle_request r where r.circle_id = c.id
                          and (not r.for_leaders or r.device = m.device or m.owner or m.leader))
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
                select id, name, owner, leader, device = ? from circle_member
                where circle_id = ? and not removed order by owner desc, leader desc, joined_at""",
                (rs, i) -> new Member(rs.getLong(1), rs.getString(2), rs.getBoolean(3), rs.getBoolean(4),
                        rs.getBoolean(5)),
                device, me.circleId());
        List<Request> requests = db.query("""
                select r.id, m.id, m.name, r.text, r.created_at, r.answered_at is not null,
                       (select count(*) from circle_prayed p where p.request_id = r.id),
                       exists (select 1 from circle_prayed p where p.request_id = r.id and p.device = ?),
                       r.device = ?, r.prayer_id,
                       (select count(*) from circle_heart h where h.request_id = r.id),
                       exists (select 1 from circle_heart h where h.request_id = r.id and h.device = ?),
                       m.owner or m.leader, r.pinned_at is not null, r.for_leaders, r.anonymous
                from circle_request r
                join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
                where r.circle_id = ? and r.created_at > now() - make_interval(days => ?)
                  and (not r.for_leaders or r.device = ? or ?)
                  and not exists (select 1 from circle_report x where x.request_id = r.id and x.device = ?)
                order by r.pinned_at is not null desc, r.created_at desc
                limit 100""",
                (rs, i) -> {
                    boolean mine = rs.getBoolean(9), anonymous = rs.getBoolean(16);
                    boolean hide = hidesName(anonymous, mine, me.leads());
                    return new Request(rs.getLong(1), hide ? 0 : rs.getLong(2), hide ? "" : rs.getString(3),
                            crypto.convertToEntityAttribute(rs.getString(4)), instant(rs.getTimestamp(5)),
                            rs.getBoolean(6), rs.getLong(7), rs.getBoolean(8), mine, rs.getString(10),
                            rs.getLong(11), rs.getBoolean(12), !hide && rs.getBoolean(13), rs.getBoolean(14),
                            rs.getBoolean(15), anonymous);
                },
                device, device, device, me.circleId(), KEEP_DAYS, device, me.leads(), device);
        return new Detail(code, name, me.owner(), me.leads(), members, requests);
    }

    /**
     * Takes the member's requests with them. The owner's place passes to the longest-serving leader,
     * or with none, to whoever joined first after them.
     */
    @Transactional
    public void leave(String device, String code) {
        Membership me = membership(device, code);
        db.update("delete from circle_request where circle_id = ? and device = ?", me.circleId(), device);
        db.update("delete from circle_member where circle_id = ? and device = ?", me.circleId(), device);
        if (!me.owner()) return;
        int passed = db.update("""
                update circle_member set owner = true, leader = false
                where id = (select id from circle_member where circle_id = ? and not removed
                            order by leader desc, joined_at limit 1)""",
                me.circleId());
        if (passed == 0) db.update("delete from circle where id = ?", me.circleId());
    }

    /** The owner or a leader (see [mayRemove]): takes a member out, with their requests, and they can't join again. */
    @Transactional
    public Detail removeMember(String device, String code, long memberId) {
        Membership me = membership(device, code);
        if (me.memberId() == memberId) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        record Target(String device, boolean owner, boolean leader) {}
        Target gone = db.query("select device, owner, leader from circle_member where id = ? and circle_id = ? and not removed",
                rs -> rs.next() ? new Target(rs.getString(1), rs.getBoolean(2), rs.getBoolean(3)) : null,
                memberId, me.circleId());
        if (gone == null) throw status(HttpStatus.NOT_FOUND, "no-member");
        if (!mayRemove(me.owner(), me.leader(), gone.owner(), gone.leader())) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("update circle_member set removed = true, leader = false where id = ?", memberId);
        db.update("delete from circle_request where circle_id = ? and device = ?", me.circleId(), gone.device());
        return detail(device, code);
    }

    /** Owner only: makes a member a leader, or no longer one. */
    public Detail setLeader(String device, String code, long memberId, boolean on) {
        Membership me = membership(device, code);
        if (!me.owner() || me.memberId() == memberId) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        int changed = db.update("update circle_member set leader = ? where id = ? and circle_id = ? and not removed",
                on, memberId, me.circleId());
        if (changed == 0) throw status(HttpStatus.NOT_FOUND, "no-member");
        return detail(device, code);
    }

    // ── News ────────────────────────────────────────────────────────────────

    /**
     * What happened in the person's circles after [since], oldest first, at most [MAX_NEWS] (the newest).
     * With no [since] (first time) there is nothing to tell yet: only the time to start from.
     */
    public NewsPage news(String device, Instant since) {
        Instant now = db.queryForObject("select now()", Timestamp.class).toInstant();
        if (since == null) return new NewsPage(now, List.of());
        // Away for long: only the last week, so opening the app isn't a wall of popups.
        Instant from = since.isBefore(now.minusSeconds(7 * 86400)) ? now.minusSeconds(7 * 86400) : since;
        Timestamp t = Timestamp.from(from);
        var items = new ArrayList<News>();

        // Asked or shared by someone else; answered by someone else. Only what the person may see:
        // requests for leaders only to leaders, and no name on an anonymous one unless they lead.
        String others = """
                select c.code, c.name, r.id, m.name, r.text, r.prayer_id, %s, me.owner or me.leader, r.anonymous, r.crisis
                from circle_request r
                join circle c on c.id = r.circle_id
                join circle_member me on me.circle_id = r.circle_id and me.device = ? and not me.removed
                join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
                where r.device <> ? and %s > ?
                  and (not r.for_leaders or me.owner or me.leader)
                  and not exists (select 1 from circle_report x where x.request_id = r.id and x.device = ?)""";
        db.query(others.formatted("r.created_at", "r.created_at"), rs -> {
            String prayerId = rs.getString(6);
            boolean leads = rs.getBoolean(8);
            items.add(new News(prayerId == null ? "request" : "prayer", rs.getString(1), rs.getString(2), rs.getLong(3),
                    hidesName(rs.getBoolean(9), false, leads) ? "" : rs.getString(4),
                    crypto.convertToEntityAttribute(rs.getString(5)), prayerId, 0, instant(rs.getTimestamp(7)),
                    leads && rs.getBoolean(10)));
        }, device, device, t, device);
        db.query(others.formatted("r.answered_at", "r.answered_at"), rs -> {
            items.add(new News("answered", rs.getString(1), rs.getString(2), rs.getLong(3),
                    hidesName(rs.getBoolean(9), false, rs.getBoolean(8)) ? "" : rs.getString(4),
                    crypto.convertToEntityAttribute(rs.getString(5)), rs.getString(6), 0, instant(rs.getTimestamp(7)),
                    false));
        }, device, device, t, device);

        // Others who prayed for the person's own requests (or joined their shared prayer).
        db.query("""
                select c.code, c.name, r.id, r.text, r.prayer_id, count(*), max(p.at)
                from circle_prayed p
                join circle_request r on r.id = p.request_id
                join circle c on c.id = r.circle_id
                where r.device = ? and p.device <> ? and p.at > ?
                group by c.code, c.name, r.id, r.text, r.prayer_id""", rs -> {
            items.add(new News("prayed", rs.getString(1), rs.getString(2), rs.getLong(3), null,
                    crypto.convertToEntityAttribute(rs.getString(4)), rs.getString(5), rs.getLong(6),
                    instant(rs.getTimestamp(7)), false));
        }, device, device, t);

        // New members of circles the person was already in: one item per circle, so a church's
        // Sunday of joins is one popup, not hundreds.
        db.query("""
                select c.code, c.name, (array_agg(m.name order by m.joined_at desc))[1], count(*), max(m.joined_at)
                from circle_member m
                join circle c on c.id = m.circle_id
                join circle_member me on me.circle_id = m.circle_id and me.device = ? and not me.removed
                where m.device <> ? and not m.removed and m.joined_at > ? and m.joined_at > me.joined_at
                group by c.code, c.name""", rs -> {
            items.add(new News("joined", rs.getString(1), rs.getString(2), null, rs.getString(3), null, null,
                    rs.getLong(4), instant(rs.getTimestamp(5)), false));
        }, device, device, t);

        return new NewsPage(now, newest(items));
    }

    // ── Requests ────────────────────────────────────────────────────────────

    /**
     * [forLeaders]: only the owner and leaders will see it. [anonymous]: members won't see who asked.
     * Checked for signs of crisis now, while the text is still readable, so leaders can be told.
     */
    @Transactional
    public Detail addRequest(String device, String code, String text, String prayerId, boolean forLeaders,
                             boolean anonymous) {
        Membership me = membership(device, code);
        boolean crisis = !text.isEmpty() && Safety.isCrisis(text);
        db.update("""
                insert into circle_request (circle_id, device, text, prayer_id, for_leaders, anonymous, crisis)
                values (?, ?, ?, ?, ?, ?, ?)""",
                me.circleId(), device, crypto.convertToDatabaseColumn(text), prayerId, forLeaders, anonymous, crisis);
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

    /** A heart on a shared prayer, or taking it back. */
    public Detail heart(String device, String code, long requestId, boolean on) {
        Membership me = membership(device, code);
        author(me, requestId);
        if (on) {
            db.update("insert into circle_heart (request_id, device) values (?, ?) on conflict do nothing", requestId, device);
        } else {
            db.update("delete from circle_heart where request_id = ? and device = ?", requestId, device);
        }
        return detail(device, code);
    }

    /** Only whoever asked can say God answered it. */
    public Detail answered(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (!device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("update circle_request set answered_at = coalesce(answered_at, now()) where id = ?", requestId);
        return detail(device, code);
    }

    /** Whoever asked, the circle's owner, or a leader. */
    public Detail deleteRequest(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (!me.leads() && !device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("delete from circle_request where id = ?", requestId);
        return detail(device, code);
    }

    /** The owner or a leader: makes [requestId] the circle's prayer focus (only one at a time), or unpins it. */
    @Transactional
    public Detail pin(String device, String code, long requestId, boolean on) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        author(me, requestId);
        if (on) {
            db.update("update circle_request set pinned_at = null where circle_id = ? and id <> ?", me.circleId(), requestId);
            db.update("update circle_request set pinned_at = coalesce(pinned_at, now()) where id = ?", requestId);
        } else {
            db.update("update circle_request set pinned_at = null where id = ?", requestId);
        }
        return detail(device, code);
    }

    /**
     * Hidden at once for whoever reported it. Removed for everyone once enough agree ([removedByReports]),
     * except a leader's or the owner's: a few members can't take down what the pastor shared.
     */
    @Transactional
    public Detail report(String device, String code, long requestId) {
        Membership me = membership(device, code);
        if (device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("insert into circle_report (request_id, device) values (?, ?) on conflict do nothing", requestId, device);
        Boolean byLeader = db.queryForObject("""
                select coalesce(bool_or(m.owner or m.leader), false) from circle_request r
                join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
                where r.id = ?""", Boolean.class, requestId);
        if (Boolean.TRUE.equals(byLeader)) return detail(device, code);
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
                select c.id, m.id, m.owner, m.leader from circle c join circle_member m on m.circle_id = c.id
                where c.code = ? and m.device = ? and not m.removed""",
                rs -> rs.next() ? new Membership(rs.getLong(1), rs.getLong(2), rs.getBoolean(3), rs.getBoolean(4)) : null,
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
