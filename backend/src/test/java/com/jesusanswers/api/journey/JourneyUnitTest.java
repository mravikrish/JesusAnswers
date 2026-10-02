package com.jesusanswers.api.journey;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.Base64;

import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class JourneyUnitTest {

    static String key(int fill) {
        byte[] k = new byte[32];
        java.util.Arrays.fill(k, (byte) fill);
        return Base64.getEncoder().encodeToString(k);
    }

    final EncryptedStringConverter converter = new EncryptedStringConverter(key(7));

    @Test
    void encryptionRoundTripsUnicodeAndHidesPlaintext() {
        String plain = "నాకు ఉద్యోగం పోయింది — I lost my job";
        String stored = converter.convertToDatabaseColumn(plain);
        assertThat(stored).doesNotContain("job");
        assertThat(converter.convertToEntityAttribute(stored)).isEqualTo(plain);
    }

    @Test
    void sameTextEncryptsDifferentlyEachTime() {
        assertThat(converter.convertToDatabaseColumn("same")).isNotEqualTo(converter.convertToDatabaseColumn("same"));
    }

    @Test
    void wrongKeyCannotDecrypt() {
        String stored = converter.convertToDatabaseColumn("secret");
        assertThatThrownBy(() -> new EncryptedStringConverter(key(9)).convertToEntityAttribute(stored))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void rejectsShortKeys() {
        assertThatThrownBy(() -> new EncryptedStringConverter(Base64.getEncoder().encodeToString(new byte[16])))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    void parsesAppTimestamps() {
        assertThat(JourneyController.parseInstant("2026-10-01T09:30:00Z")).isEqualTo(Instant.parse("2026-10-01T09:30:00Z"));
        assertThat(JourneyController.parseInstant("2026-10-01T09:30:00.123456")).isNotNull();
        assertThatThrownBy(() -> JourneyController.parseInstant("yesterday")).isInstanceOf(ResponseStatusException.class);
    }
}
