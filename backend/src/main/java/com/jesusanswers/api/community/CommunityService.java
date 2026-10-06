package com.jesusanswers.api.community;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Counts how many people loved, prayed or listened to each item. Counts are worked out from the
 * tables at most every few minutes and served from memory, so busy days cost the database little.
 * Kept behind this one class so the counts can move (e.g. to Firebase) without touching the app's screens.
 */
@Service
public class CommunityService {

    /** prayer:&lt;id&gt;, story:&lt;id&gt;, chapter:JHN.3, saying:MAT.11.28 */
    static final Pattern ITEM = Pattern.compile("(prayer|story|chapter|saying):[A-Za-z0-9_.-]{1,60}");

    public enum Kind { HEART, UNHEART, PRAYED, LISTENED }

    /** [week] = prayed + listened in the last 7 days, for "Loved this week". */
    public record ItemCounts(long hearts, long prayed, long listened, long week) {}

    /** [today] = how many people prayed or listened today. */
    public record Counts(long today, Map<String, ItemCounts> items, Instant at) {}

    private static final long REFRESH_MILLIS = 5 * 60_000;

    private final JdbcTemplate db;
    private final String salt;
    private final Clock clock;
    private volatile Counts cached;

    @Autowired
    public CommunityService(JdbcTemplate db, @Value("${jesusanswers.community.salt}") String salt) {
        this(db, salt, Clock.systemUTC());
    }

    CommunityService(JdbcTemplate db, String salt, Clock clock) {
        this.db = db;
        this.salt = salt;
        this.clock = clock;
    }

    static boolean validItem(String item) {
        return item != null && ITEM.matcher(item).matches();
    }

    /** The install id is never stored as sent: only a salted hash of it. */
    String device(String installId) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest((salt + ':' + installId).getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    public void record(String item, Kind kind, String installId) {
        String device = device(installId);
        switch (kind) {
            case HEART -> db.update("insert into heart (item, device) values (?, ?) on conflict do nothing", item, device);
            case UNHEART -> db.update("delete from heart where item = ? and device = ?", item, device);
            case PRAYED, LISTENED -> db.update(
                    "insert into activity (item, kind, device, day) values (?, ?, ?, ?) on conflict do nothing",
                    item, kind.name().toLowerCase(), device, today());
        }
    }

    public Counts counts() {
        Counts c = cached;
        if (c == null || clock.millis() - c.at().toEpochMilli() > REFRESH_MILLIS) {
            c = cached = load();
        }
        return c;
    }

    private LocalDate today() {
        return LocalDate.ofInstant(clock.instant(), ZoneOffset.UTC);
    }

    private Counts load() {
        LocalDate today = today();
        Map<String, long[]> items = new HashMap<>();
        db.query("select item, count(*) from heart group by item",
                rs -> { items.computeIfAbsent(rs.getString(1), k -> new long[4])[0] = rs.getLong(2); });
        db.query("""
                select item, kind, count(*), count(*) filter (where day > ?)
                from activity group by item, kind""",
                rs -> {
                    long[] n = items.computeIfAbsent(rs.getString(1), k -> new long[4]);
                    n["prayed".equals(rs.getString(2)) ? 1 : 2] = rs.getLong(3);
                    n[3] += rs.getLong(4);
                },
                today.minusDays(7));
        Long people = db.queryForObject("select count(distinct device) from activity where day = ?", Long.class, today);
        Map<String, ItemCounts> out = new HashMap<>();
        items.forEach((item, n) -> out.put(item, new ItemCounts(n[0], n[1], n[2], n[3])));
        return new Counts(people == null ? 0 : people, out, clock.instant());
    }
}
