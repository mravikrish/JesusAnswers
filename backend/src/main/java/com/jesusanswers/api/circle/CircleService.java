package com.jesusanswers.api.circle;

import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
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
 *
 * For a church: a circle can hold groups (one level), let new members in only once a leader approves,
 * keep a praise wall of answered prayers, run prayer chains, and share Bible verses.
 */
@Service
public class CircleService {

    /** No I, O, 0 or 1, so a code read out over the phone can't be mistaken. */
    static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    static final int CODE_LENGTH = 6;

    /** Big enough for a whole church. */
    static final int MAX_MEMBERS = 500;
    static final int MAX_CIRCLES_PER_DEVICE = 20;
    static final int MAX_GROUPS = 30;
    static final int MAX_NAME = 40, MAX_CIRCLE_NAME = 60, MAX_TEXT = 1000, MAX_CHAIN_TITLE = 80;

    /** Requests older than this are no longer shown, and are deleted as new ones come in. */
    static final int KEEP_DAYS = 60;

    /** Answered prayers stay on the praise wall this long. */
    static final int KEEP_PRAISE_DAYS = 365;

    /** Prayer chains: at most this many running in a circle, of at most [MAX_SLOTS] turns over [MAX_CHAIN_DAYS]. */
    static final int MAX_CHAINS = 10, MAX_SLOTS = 168, MAX_CHAIN_DAYS = 40;

    /**
     * [parent]: the church's name, for one of its circles. [pending]: asked to join, waiting for a leader.
     * [church]: a church, the home of its circles.
     */
    public record Summary(String code, String name, int members, boolean owner, Instant latest, String parent,
                          boolean pending, boolean church) {}

    /** [leader]: made a leader by the owner (the owner isn't marked a leader). */
    public record Member(long id, String name, boolean owner, boolean leader, boolean me) {}

    /**
     * [prayerId]: a shared ready prayer, and [verse] a shared Bible verse ("JHN 3:16"); [text] is then an
     * optional note (may be empty).
     * [leader]: asked by the owner or a leader. [pinned]: the circle's prayer focus, shown first.
     * [forLeaders]: only the owner and leaders see it. [anonymous]: asked without a name; [name] is then
     * empty (and [memberId] 0) for members, and only the asker, the owner and leaders see who asked.
     * [praise]: a praise report, shared as such. [testimony]: how God answered, when [answered].
     */
    public record Request(long id, long memberId, String name, String text, Instant at, boolean answered,
                          long prayed, boolean prayedByMe, boolean mine, String prayerId, long hearts,
                          boolean heartedByMe, boolean leader, boolean pinned, boolean forLeaders,
                          boolean anonymous, boolean praise, String testimony, String verse, Instant answeredAt) {}

    /** A group of a church, as its members see it. [joined]: the reader is in it; [pending]: waiting to be. */
    public record Group(String code, String name, int members, boolean joined, boolean pending) {}

    /** The church a group belongs to. [code]: null unless the reader is in the church too. */
    public record Parent(String code, String name) {}

    /** Someone's turn in a prayer chain. */
    public record Turn(int slot, String name, boolean mine) {}

    /** A prayer chain or fasting days: [slots] turns of [slotMinutes] each, from [startsAt]. [mine]: started it. */
    public record Chain(long id, String title, Instant startsAt, int slotMinutes, int slots, boolean mine,
                        List<Turn> turns) {}

    /**
     * [leader]: the reader is the owner or a leader, so can pin, delete requests and remove members.
     * [pending]: the reader asked to join and waits for a leader; nothing else is filled in then.
     * [approval]: new members wait for a leader. [waiting]: who waits (for the owner and leaders only).
     * [groups]: a church's circles. [praise]: answered prayers, the newest answer first.
     * [church]: a church, the home of its circles.
     */
    public record Detail(String code, String name, boolean owner, boolean leader, List<Member> members,
                         List<Request> requests, boolean pending, boolean approval, List<Member> waiting,
                         Parent parent, List<Group> groups, List<Request> praise, List<Chain> chains,
                         boolean church) {

        static Detail waitingFor(String code, String name, Parent parent, boolean church) {
            return new Detail(code, name, false, false, List.of(), List.of(), true, true, List.of(), parent,
                    List.of(), List.of(), List.of(), church);
        }
    }

    /**
     * Something new in one of the person's circles, shown as a popup when they next open the app.
     * [kind]: request (someone asked), prayer (someone shared a ready prayer), verse (someone shared a
     * Bible verse), prayed ([count] people prayed for the person's own request), answered (God answered
     * someone's request, or a praise report; with its [testimony]), joined ([count] new members, the
     * latest of them [name]), waiting (for leaders: [count] people waiting to join), approved (the person
     * was let in), chain (a prayer chain started, [text] its title, [requestId] its id), group (a new
     * group, [name], of the person's church; [group] its code).
     * [crisis]: told only to the owner and leaders, about a request from someone who may be thinking of
     * ending their life, so they reach out today. Never left out for lack of room.
     */
    public record News(String kind, String circle, String circleName, Long requestId, String name, String text,
                       String prayerId, long count, Instant at, boolean crisis, String verse, String testimony,
                       String group) {}

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

    private static final Pattern VERSE = Pattern.compile("[1-3A-Z][A-Z]{2} [1-9][0-9]{0,2}:[1-9][0-9]{0,2}");

    /** A Bible verse as the app names it ("JHN 3:16", "1CO 13:4"); null when it can't be one. */
    static String cleanVerse(String input) {
        return input != null && VERSE.matcher(input).matches() ? input : null;
    }

    /** Request text keeps its line breaks; null when empty or too long. */
    static String cleanText(String input) {
        if (input == null) return null;
        String text = input.replaceAll("[\\p{Cc}&&[^\\n]]", "").replaceAll("\\n{3,}", "\n\n").strip();
        return text.isEmpty() || text.codePointCount(0, text.length()) > MAX_TEXT ? null : text;
    }

    /** A prayer chain's turns: 15 minutes to a day each, at most [MAX_SLOTS] of them, over at most [MAX_CHAIN_DAYS]. */
    static boolean validChain(int slotMinutes, int slots) {
        return slotMinutes >= 15 && slotMinutes <= 1440 && slots >= 1 && slots <= MAX_SLOTS
                && (long) slotMinutes * slots <= MAX_CHAIN_DAYS * 1440L;
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

    /** The person's churches and circles, each church followed by its circles; and those they wait to join. */
    public List<Summary> mine(String device) {
        return db.query("""
                select c.code, c.name, m.owner,
                       (select count(*) from circle_member o where o.circle_id = c.id and not o.removed),
                       (select max(r.created_at) from circle_request r where r.circle_id = c.id and not r.praise
                          and (not r.for_leaders or r.device = m.device or m.owner or m.leader)),
                       p.name, false, coalesce(c.parent_id, c.id) as family, c.parent_id is not null as child,
                       m.joined_at as at, c.church
                from circle c join circle_member m on m.circle_id = c.id
                left join circle p on p.id = c.parent_id
                where m.device = ? and not m.removed
                union all
                select c.code, c.name, false,
                       (select count(*) from circle_member o where o.circle_id = c.id and not o.removed),
                       null, p.name, true, coalesce(c.parent_id, c.id), c.parent_id is not null, w.asked_at, c.church
                from circle_waiting w join circle c on c.id = w.circle_id
                left join circle p on p.id = c.parent_id
                where w.device = ?
                order by family, child, at""",
                (rs, i) -> new Summary(rs.getString(1), rs.getString(2), rs.getInt(4), rs.getBoolean(3),
                        instant(rs.getTimestamp(5)), rs.getString(6), rs.getBoolean(7), rs.getBoolean(11)),
                device, device);
    }

    /**
     * Starts a circle, or with [church] a church: the home of the church's circles. A church lets new
     * members in only once a leader approves, from the start, since its code is read out and shown on
     * screens; the owner can turn that off.
     */
    @Transactional
    public Detail create(String device, String name, String memberName, boolean church) {
        checkRoomForAnother(device);
        String code = newCircle(name, null);
        if (church) db.update("update circle set church = true, approval = true where code = ?", code);
        db.update("insert into circle_member (circle_id, device, name, owner) select id, ?, ?, true from circle where code = ?",
                device, memberName, code);
        return detail(device, code);
    }

    /**
     * The owner or a leader of a church adds a circle to it, and starts it as its owner, under the name
     * they have in the church. Answers with the church, its circles now including this one. Only a
     * church holds circles.
     */
    @Transactional
    public Detail createGroup(String device, String code, String name) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        Boolean church = db.queryForObject("select church from circle where id = ?", Boolean.class, me.circleId());
        if (!Boolean.TRUE.equals(church)) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        Long groups = db.queryForObject("select count(*) from circle where parent_id = ?", Long.class, me.circleId());
        if (groups != null && groups >= MAX_GROUPS) throw status(HttpStatus.CONFLICT, "full");
        checkRoomForAnother(device);
        String group = newCircle(name, me.circleId());
        db.update("""
                insert into circle_member (circle_id, device, name, owner)
                select g.id, ?, m.name, true from circle g, circle_member m where g.code = ? and m.id = ?""",
                device, group, me.memberId());
        return detail(device, code);
    }

    /** Owner only: whether people joining with the code wait for a leader to let them in. */
    public Detail setApproval(String device, String code, boolean on) {
        Membership me = membership(device, code);
        if (!me.owner()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("update circle set approval = ? where id = ?", on, me.circleId());
        return detail(device, code);
    }

    /**
     * Joins, or with approval on, asks to join and waits (answered with a pending circle).
     * Someone removed or declined can't join again.
     */
    @Transactional
    public Detail join(String device, String code, String memberName) {
        record Row(long id, boolean approval) {}
        Row circle = db.query("select id, approval from circle where code = ? for update",
                rs -> rs.next() ? new Row(rs.getLong(1), rs.getBoolean(2)) : null, code);
        if (circle == null) throw status(HttpStatus.NOT_FOUND, "no-circle");
        Boolean removed = db.query("select removed from circle_member where circle_id = ? and device = ?",
                rs -> rs.next() ? rs.getBoolean(1) : null, circle.id(), device);
        if (Boolean.TRUE.equals(removed)) throw status(HttpStatus.FORBIDDEN, "removed");
        if (removed != null) {
            // Already in it: joining again just updates the name the others see.
            db.update("update circle_member set name = ? where circle_id = ? and device = ?", memberName, circle.id(), device);
            return detail(device, code);
        }
        if (db.update("update circle_waiting set name = ? where circle_id = ? and device = ?",
                memberName, circle.id(), device) > 0) {
            return detail(device, code);
        }
        Long taken = db.queryForObject("""
                select (select count(*) from circle_member where circle_id = ? and not removed)
                     + (select count(*) from circle_waiting where circle_id = ?)""", Long.class, circle.id(), circle.id());
        if (taken != null && taken >= MAX_MEMBERS) throw status(HttpStatus.CONFLICT, "full");
        checkRoomForAnother(device);
        db.update(circle.approval()
                        ? "insert into circle_waiting (circle_id, device, name) values (?, ?, ?)"
                        : "insert into circle_member (circle_id, device, name) values (?, ?, ?)",
                circle.id(), device, memberName);
        return detail(device, code);
    }

    /** The owner or a leader lets in someone who waits. */
    @Transactional
    public Detail approve(String device, String code, long waitingId) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        record Waiting(String device, String name) {}
        Waiting w = db.query("select device, name from circle_waiting where id = ? and circle_id = ?",
                rs -> rs.next() ? new Waiting(rs.getString(1), rs.getString(2)) : null, waitingId, me.circleId());
        if (w == null) throw status(HttpStatus.NOT_FOUND, "no-member");
        db.update("delete from circle_waiting where id = ?", waitingId);
        db.update("""
                insert into circle_member (circle_id, device, name, approved) values (?, ?, ?, true)
                on conflict do nothing""", me.circleId(), w.device(), w.name());
        return detail(device, code);
    }

    /** The owner or a leader turns away someone who waits; like someone removed, they can't ask again. */
    @Transactional
    public Detail decline(String device, String code, long waitingId) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        record Waiting(String device, String name) {}
        Waiting w = db.query("select device, name from circle_waiting where id = ? and circle_id = ?",
                rs -> rs.next() ? new Waiting(rs.getString(1), rs.getString(2)) : null, waitingId, me.circleId());
        if (w == null) throw status(HttpStatus.NOT_FOUND, "no-member");
        db.update("delete from circle_waiting where id = ?", waitingId);
        db.update("""
                insert into circle_member (circle_id, device, name, removed) values (?, ?, ?, true)
                on conflict do nothing""", me.circleId(), w.device(), w.name());
        return detail(device, code);
    }

    public Detail detail(String device, String code) {
        Membership me = findMembership(device, code);
        if (me == null) return waitingDetail(device, code);

        record Row(String name, boolean approval, Long parentId, boolean church) {}
        Row circle = db.queryForObject("select name, approval, parent_id, church from circle where id = ?",
                (rs, i) -> new Row(rs.getString(1), rs.getBoolean(2), (Long) rs.getObject(3), rs.getBoolean(4)),
                me.circleId());

        List<Member> members = db.query("""
                select id, name, owner, leader, device = ? from circle_member
                where circle_id = ? and not removed order by owner desc, leader desc, joined_at""",
                (rs, i) -> new Member(rs.getLong(1), rs.getString(2), rs.getBoolean(3), rs.getBoolean(4),
                        rs.getBoolean(5)),
                device, me.circleId());
        List<Member> waiting = !me.leads() ? List.of() : db.query(
                "select id, name from circle_waiting where circle_id = ? order by asked_at",
                (rs, i) -> new Member(rs.getLong(1), rs.getString(2), false, false, false), me.circleId());

        Parent parent = circle.parentId() == null ? null : db.queryForObject("""
                select case when exists (select 1 from circle_member m where m.circle_id = p.id and m.device = ?
                                         and not m.removed) then p.code end, p.name
                from circle p where p.id = ?""",
                (rs, i) -> new Parent(rs.getString(1), rs.getString(2)), device, circle.parentId());
        List<Group> groups = !circle.church() ? List.of() : db.query("""
                select g.code, g.name,
                       (select count(*) from circle_member o where o.circle_id = g.id and not o.removed),
                       exists (select 1 from circle_member m where m.circle_id = g.id and m.device = ? and not m.removed),
                       exists (select 1 from circle_waiting w where w.circle_id = g.id and w.device = ?)
                from circle g where g.parent_id = ? order by g.name""",
                (rs, i) -> new Group(rs.getString(1), rs.getString(2), rs.getInt(3), rs.getBoolean(4), rs.getBoolean(5)),
                device, device, me.circleId());

        List<Request> requests = requests(device, me,
                "not r.praise and r.created_at > now() - make_interval(days => ?)",
                "r.pinned_at is not null desc, r.created_at desc", 100, KEEP_DAYS);
        List<Request> praise = requests(device, me,
                "r.answered_at > now() - make_interval(days => ?)", "r.answered_at desc", 50, KEEP_PRAISE_DAYS);

        return new Detail(code, circle.name(), me.owner(), me.leads(), members, requests, false, circle.approval(),
                waiting, parent, groups, praise, chains(device, me), circle.church());
    }

    /** For someone who asked to join and waits; 404 for anyone else. */
    private Detail waitingDetail(String device, String code) {
        Detail d = db.query("""
                select c.name, p.name, c.church from circle_waiting w join circle c on c.id = w.circle_id
                left join circle p on p.id = c.parent_id
                where c.code = ? and w.device = ?""",
                rs -> rs.next()
                        ? Detail.waitingFor(code, rs.getString(1),
                                rs.getString(2) == null ? null : new Parent(null, rs.getString(2)), rs.getBoolean(3))
                        : null,
                code, device);
        if (d == null) throw status(HttpStatus.NOT_FOUND, "no-circle");
        return d;
    }

    private static final String REQUESTS = """
            select r.id, m.id, m.name, r.text, r.created_at, r.answered_at,
                   (select count(*) from circle_prayed p where p.request_id = r.id),
                   exists (select 1 from circle_prayed p where p.request_id = r.id and p.device = ?),
                   r.device = ?, r.prayer_id,
                   (select count(*) from circle_heart h where h.request_id = r.id),
                   exists (select 1 from circle_heart h where h.request_id = r.id and h.device = ?),
                   m.owner or m.leader, r.pinned_at is not null, r.for_leaders, r.anonymous,
                   r.praise, r.testimony, r.verse
            from circle_request r
            join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
            where r.circle_id = ? and (not r.for_leaders or r.device = ? or ?)
              and not exists (select 1 from circle_report x where x.request_id = r.id and x.device = ?)
              and %s
            order by %s
            limit %d""";

    /** The requests the reader may see, [where] and in [order]; [more] are the parameters of [where]. */
    private List<Request> requests(String device, Membership me, String where, String order, int limit, Object... more) {
        var params = new ArrayList<Object>(List.of(device, device, device, me.circleId(), device, me.leads(), device));
        params.addAll(List.of(more));
        return db.query(REQUESTS.formatted(where, order, limit), (rs, i) -> {
            boolean mine = rs.getBoolean(9), anonymous = rs.getBoolean(16);
            boolean hide = hidesName(anonymous, mine, me.leads());
            Instant answeredAt = instant(rs.getTimestamp(6));
            return new Request(rs.getLong(1), hide ? 0 : rs.getLong(2), hide ? "" : rs.getString(3),
                    crypto.convertToEntityAttribute(rs.getString(4)), instant(rs.getTimestamp(5)),
                    answeredAt != null, rs.getLong(7), rs.getBoolean(8), mine, rs.getString(10),
                    rs.getLong(11), rs.getBoolean(12), !hide && rs.getBoolean(13), rs.getBoolean(14),
                    rs.getBoolean(15), anonymous, rs.getBoolean(17), crypto.convertToEntityAttribute(rs.getString(18)),
                    rs.getString(19), answeredAt);
        }, params.toArray());
    }

    /** The circle's prayer chains, until two days after they end, with who took which turn. */
    private List<Chain> chains(String device, Membership me) {
        Map<Long, List<Turn>> turns = new HashMap<>();
        db.query("""
                select s.chain_id, s.slot, m.name, s.device = ? from circle_chain_slot s
                join circle_chain c on c.id = s.chain_id
                join circle_member m on m.circle_id = c.circle_id and m.device = s.device and not m.removed
                where c.circle_id = ? order by s.slot, m.joined_at""", rs -> {
            turns.computeIfAbsent(rs.getLong(1), k -> new ArrayList<>())
                    .add(new Turn(rs.getInt(2), rs.getString(3), rs.getBoolean(4)));
        }, device, me.circleId());
        return db.query("""
                select id, title, starts_at, slot_minutes, slots, device = ? from circle_chain
                where circle_id = ? and starts_at + make_interval(mins => slot_minutes * slots) > now() - interval '2 days'
                order by starts_at""",
                (rs, i) -> new Chain(rs.getLong(1), crypto.convertToEntityAttribute(rs.getString(2)),
                        instant(rs.getTimestamp(3)), rs.getInt(4), rs.getInt(5), rs.getBoolean(6),
                        List.copyOf(turns.getOrDefault(rs.getLong(1), List.of()))),
                device, me.circleId());
    }

    /**
     * Takes the member's requests and turns with them. The owner's place passes to the longest-serving
     * leader, or with none, to whoever joined first after them. Someone waiting stops waiting.
     */
    @Transactional
    public void leave(String device, String code) {
        Membership me = findMembership(device, code);
        if (me == null) {
            int stopped = db.update("delete from circle_waiting w using circle c where c.id = w.circle_id and c.code = ? and w.device = ?",
                    code, device);
            if (stopped == 0) throw status(HttpStatus.NOT_FOUND, "no-circle");
            return;
        }
        forget(me.circleId(), device);
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
        forget(me.circleId(), gone.device());
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
                select c.code, c.name, r.id, m.name, r.text, r.prayer_id, %1$s, me.owner or me.leader, r.anonymous,
                       r.crisis, r.verse, r.testimony
                from circle_request r
                join circle c on c.id = r.circle_id
                join circle_member me on me.circle_id = r.circle_id and me.device = ? and not me.removed
                join circle_member m on m.circle_id = r.circle_id and m.device = r.device and not m.removed
                where r.device <> ? and %1$s > ? %2$s
                  and (not r.for_leaders or me.owner or me.leader)
                  and not exists (select 1 from circle_report x where x.request_id = r.id and x.device = ?)""";
        // A praise report comes as an answered prayer.
        db.query(others.formatted("r.created_at", "and not r.praise"), rs -> {
            String prayerId = rs.getString(6), verse = rs.getString(11);
            boolean leads = rs.getBoolean(8);
            String kind = verse != null ? "verse" : prayerId != null ? "prayer" : "request";
            items.add(new News(kind, rs.getString(1), rs.getString(2), rs.getLong(3),
                    hidesName(rs.getBoolean(9), false, leads) ? "" : rs.getString(4),
                    crypto.convertToEntityAttribute(rs.getString(5)), prayerId, 0, instant(rs.getTimestamp(7)),
                    leads && rs.getBoolean(10), verse, null, null));
        }, device, device, t, device);
        db.query(others.formatted("r.answered_at", ""), rs -> {
            items.add(new News("answered", rs.getString(1), rs.getString(2), rs.getLong(3),
                    hidesName(rs.getBoolean(9), false, rs.getBoolean(8)) ? "" : rs.getString(4),
                    crypto.convertToEntityAttribute(rs.getString(5)), rs.getString(6), 0, instant(rs.getTimestamp(7)),
                    false, rs.getString(11), crypto.convertToEntityAttribute(rs.getString(12)), null));
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
                    instant(rs.getTimestamp(7)), false, null, null, null));
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
                    rs.getLong(4), instant(rs.getTimestamp(5)), false, null, null, null));
        }, device, device, t);

        // For the owner and leaders: who is waiting to be let in, one item per circle.
        db.query("""
                select c.code, c.name, (array_agg(w.name order by w.asked_at desc))[1], count(*), max(w.asked_at)
                from circle_waiting w
                join circle c on c.id = w.circle_id
                join circle_member me on me.circle_id = w.circle_id and me.device = ? and not me.removed
                where (me.owner or me.leader) and w.asked_at > ?
                group by c.code, c.name""", rs -> {
            items.add(new News("waiting", rs.getString(1), rs.getString(2), null, rs.getString(3), null, null,
                    rs.getLong(4), instant(rs.getTimestamp(5)), false, null, null, null));
        }, device, t);

        // The person was let in.
        db.query("""
                select c.code, c.name, m.joined_at from circle_member m join circle c on c.id = m.circle_id
                where m.device = ? and m.approved and not m.removed and m.joined_at > ?""", rs -> {
            items.add(new News("approved", rs.getString(1), rs.getString(2), null, null, null, null, 0,
                    instant(rs.getTimestamp(3)), false, null, null, null));
        }, device, t);

        // A prayer chain someone else started.
        db.query("""
                select c.code, c.name, ch.id, m.name, ch.title, ch.created_at
                from circle_chain ch
                join circle c on c.id = ch.circle_id
                join circle_member me on me.circle_id = ch.circle_id and me.device = ? and not me.removed
                join circle_member m on m.circle_id = ch.circle_id and m.device = ch.device
                where ch.device <> ? and ch.created_at > ?""", rs -> {
            items.add(new News("chain", rs.getString(1), rs.getString(2), rs.getLong(3), rs.getString(4),
                    crypto.convertToEntityAttribute(rs.getString(5)), null, 0, instant(rs.getTimestamp(6)), false,
                    null, null, null));
        }, device, device, t);

        // A new group of the person's church, that they aren't in yet.
        db.query("""
                select p.code, p.name, g.code, g.name, g.created_at
                from circle g
                join circle p on p.id = g.parent_id
                join circle_member me on me.circle_id = p.id and me.device = ? and not me.removed
                where g.created_at > ?
                  and not exists (select 1 from circle_member x where x.circle_id = g.id and x.device = ?)""", rs -> {
            items.add(new News("group", rs.getString(1), rs.getString(2), null, rs.getString(4), null, null, 0,
                    instant(rs.getTimestamp(5)), false, null, null, rs.getString(3)));
        }, device, t, device);

        return new NewsPage(now, newest(items));
    }

    // ── Requests ────────────────────────────────────────────────────────────

    /**
     * A request in [text]; or a ready prayer [prayerId] or Bible [verse], with [text] as an optional note;
     * or with [praise], a praise report (already answered). [forLeaders]: only the owner and leaders will
     * see it. [anonymous]: members won't see who asked.
     * Checked for signs of crisis now, while the text is still readable, so leaders can be told.
     */
    @Transactional
    public Detail addRequest(String device, String code, String text, String prayerId, String verse,
                             boolean forLeaders, boolean anonymous, boolean praise) {
        Membership me = membership(device, code);
        boolean crisis = !text.isEmpty() && Safety.isCrisis(text);
        db.update("""
                insert into circle_request (circle_id, device, text, prayer_id, verse, for_leaders, anonymous, crisis,
                                            praise, answered_at)
                values (?, ?, ?, ?, ?, ?, ?, ?, ?, case when ? then now() end)""",
                me.circleId(), device, crypto.convertToDatabaseColumn(text), prayerId, verse, forLeaders, anonymous,
                crisis, praise, praise);
        db.update("""
                delete from circle_request where circle_id = ?
                  and ((answered_at is null and created_at < now() - make_interval(days => ?))
                       or answered_at < now() - make_interval(days => ?))""",
                me.circleId(), KEEP_DAYS, KEEP_PRAISE_DAYS);
        return detail(device, code);
    }

    public Detail prayed(String device, String code, long requestId) {
        Membership me = membership(device, code);
        author(me, requestId);
        db.update("insert into circle_prayed (request_id, device) values (?, ?) on conflict do nothing", requestId, device);
        return detail(device, code);
    }

    /** A heart on a shared prayer, verse or answered prayer, or taking it back. */
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

    /**
     * Only whoever asked can say God answered it, with [testimony] (how He answered) for the praise wall,
     * or null. Saying it again adds or changes the testimony.
     */
    public Detail answered(String device, String code, long requestId, String testimony) {
        Membership me = membership(device, code);
        if (!device.equals(author(me, requestId))) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("""
                update circle_request set answered_at = coalesce(answered_at, now()), testimony = coalesce(?, testimony)
                where id = ?""", crypto.convertToDatabaseColumn(testimony), requestId);
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

    // ── Prayer chains ───────────────────────────────────────────────────────

    /**
     * The owner or a leader starts a prayer chain (turns of an hour, say) or fasting days (turns of a day).
     * [slotMinutes] and [slots] must pass [validChain]; [startsAt] is checked by the caller.
     */
    @Transactional
    public Detail createChain(String device, String code, String title, Instant startsAt, int slotMinutes, int slots) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("""
                delete from circle_chain where circle_id = ?
                  and starts_at + make_interval(mins => slot_minutes * slots) < now() - interval '30 days'""",
                me.circleId());
        Long running = db.queryForObject("""
                select count(*) from circle_chain where circle_id = ?
                  and starts_at + make_interval(mins => slot_minutes * slots) > now()""", Long.class, me.circleId());
        if (running != null && running >= MAX_CHAINS) throw status(HttpStatus.CONFLICT, "full");
        db.update("""
                insert into circle_chain (circle_id, device, title, starts_at, slot_minutes, slots)
                values (?, ?, ?, ?, ?, ?)""",
                me.circleId(), device, crypto.convertToDatabaseColumn(title), Timestamp.from(startsAt), slotMinutes, slots);
        return detail(device, code);
    }

    /** The owner or a leader. */
    public Detail deleteChain(String device, String code, long chainId) {
        Membership me = membership(device, code);
        if (!me.leads()) throw status(HttpStatus.FORBIDDEN, "not-allowed");
        db.update("delete from circle_chain where id = ? and circle_id = ?", chainId, me.circleId());
        return detail(device, code);
    }

    /** Takes turn [slot] of a chain ("I'll pray 6–7 AM"), or gives it back. Several people can share a turn. */
    public Detail turn(String device, String code, long chainId, int slot, boolean on) {
        Membership me = membership(device, code);
        Integer slots = db.query("select slots from circle_chain where id = ? and circle_id = ?",
                rs -> rs.next() ? rs.getInt(1) : null, chainId, me.circleId());
        if (slots == null || slot < 0 || slot >= slots) throw status(HttpStatus.NOT_FOUND, "no-chain");
        if (on) {
            db.update("insert into circle_chain_slot (chain_id, slot, device) values (?, ?, ?) on conflict do nothing",
                    chainId, slot, device);
        } else {
            db.update("delete from circle_chain_slot where chain_id = ? and slot = ? and device = ?", chainId, slot, device);
        }
        return detail(device, code);
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Not a member (or no such circle) looks the same from outside: 404. */
    private Membership membership(String device, String code) {
        Membership m = findMembership(device, code);
        if (m == null) throw status(HttpStatus.NOT_FOUND, "no-circle");
        return m;
    }

    private Membership findMembership(String device, String code) {
        return db.query("""
                select c.id, m.id, m.owner, m.leader from circle c join circle_member m on m.circle_id = c.id
                where c.code = ? and m.device = ? and not m.removed""",
                rs -> rs.next() ? new Membership(rs.getLong(1), rs.getLong(2), rs.getBoolean(3), rs.getBoolean(4)) : null,
                code, device);
    }

    /** A new circle with a fresh code; its code. */
    private String newCircle(String name, Long parentId) {
        for (int attempt = 0; ; attempt++) {
            String code = newCode(random);
            try {
                db.update("insert into circle (code, name, parent_id) values (?, ?, ?)", code, name, parentId);
                return code;
            } catch (DuplicateKeyException e) {
                if (attempt >= 5) throw e;
            }
        }
    }

    /** Someone leaving or removed takes their requests and their turns in prayer chains with them. */
    private void forget(long circleId, String device) {
        db.update("delete from circle_request where circle_id = ? and device = ?", circleId, device);
        db.update("""
                delete from circle_chain_slot s using circle_chain c
                where c.id = s.chain_id and c.circle_id = ? and s.device = ?""", circleId, device);
    }

    /** The device that asked [requestId], which must be in this circle. */
    private String author(Membership me, long requestId) {
        String device = db.query("select device from circle_request where id = ? and circle_id = ?",
                rs -> rs.next() ? rs.getString(1) : null, requestId, me.circleId());
        if (device == null) throw status(HttpStatus.NOT_FOUND, "no-request");
        return device;
    }

    /** Circles the person is in, and those they wait to join, count alike. */
    private void checkRoomForAnother(String device) {
        Long count = db.queryForObject("""
                select (select count(*) from circle_member where device = ? and not removed)
                     + (select count(*) from circle_waiting where device = ?)""", Long.class, device, device);
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
