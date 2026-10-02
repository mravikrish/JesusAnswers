package com.jesusanswers.api.journey;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "journey_entry")
public class JourneyEntry {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    private String kind;
    private String lang;
    private String mood;

    @JdbcTypeCode(SqlTypes.ARRAY)
    private List<String> themes;

    @JdbcTypeCode(SqlTypes.ARRAY)
    @Column(name = "verse_refs")
    private List<String> verseRefs;

    @Convert(converter = EncryptedStringConverter.class)
    private String question;

    @Convert(converter = EncryptedStringConverter.class)
    private String encouragement;

    @Convert(converter = EncryptedStringConverter.class)
    private String prayer;

    private boolean crisis;
    private boolean favorite;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected JourneyEntry() {}

    public JourneyEntry(UUID id, UUID userId) {
        this.id = id;
        this.userId = userId;
    }

    public void update(String kind, String lang, String mood, List<String> themes, List<String> verseRefs,
                       String question, String encouragement, String prayer, boolean crisis, boolean favorite,
                       Instant createdAt) {
        this.kind = kind;
        this.lang = lang;
        this.mood = mood;
        this.themes = themes;
        this.verseRefs = verseRefs;
        this.question = question;
        this.encouragement = encouragement;
        this.prayer = prayer;
        this.crisis = crisis;
        this.favorite = favorite;
        this.createdAt = createdAt;
        this.updatedAt = Instant.now();
    }

    public UUID getId() { return id; }
    public UUID getUserId() { return userId; }
    public String getKind() { return kind; }
    public String getLang() { return lang; }
    public String getMood() { return mood; }
    public List<String> getThemes() { return themes; }
    public List<String> getVerseRefs() { return verseRefs; }
    public String getQuestion() { return question; }
    public String getEncouragement() { return encouragement; }
    public String getPrayer() { return prayer; }
    public boolean isCrisis() { return crisis; }
    public boolean isFavorite() { return favorite; }
    public Instant getCreatedAt() { return createdAt; }
}
