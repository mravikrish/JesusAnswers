package com.jesusanswers.api.circle;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.answer.RateLimiter;
import com.jesusanswers.api.circle.CircleController.Join;
import com.jesusanswers.api.circle.CircleController.NewCircle;
import com.jesusanswers.api.circle.CircleController.NewRequest;
import com.jesusanswers.api.circle.CircleService.Detail;
import com.jesusanswers.api.community.CommunityService;

class CircleTest {

    static final String INSTALL = "3f2a9c1e-7b4d-4e8a-9f00-1234567890ab";

    /** Records instead of writing to the database. */
    static class Recording extends CircleService {
        final List<String> calls = new ArrayList<>();

        Recording() {
            super(null, null);
        }

        Detail empty(String code) {
            return new Detail(code, "Family", true, List.of(), List.of());
        }

        @Override
        public Detail create(String device, String name, String memberName) {
            calls.add("create " + name + " by " + memberName);
            return empty("K7P3MX");
        }

        @Override
        public Detail join(String device, String code, String memberName) {
            calls.add("join " + code + " as " + memberName);
            return empty(code);
        }

        @Override
        public Detail addRequest(String device, String code, String text) {
            calls.add("ask " + code + " " + text);
            return empty(code);
        }
    }

    static CircleController controller(Recording service, int joinsPerHour) {
        return new CircleController(service, new CommunityService(null, "salt"), new RateLimiter(100),
                new RateLimiter(joinsPerHour));
    }

    @Test
    void codesAreSixCharactersThatCantBeMisread() {
        var random = new Random(7);
        for (int i = 0; i < 1000; i++) {
            String code = CircleService.newCode(random);
            assertThat(code).hasSize(6).doesNotContain("I", "O", "0", "1");
            assertThat(CircleService.normalizeCode(code)).isEqualTo(code);
        }
    }

    @Test
    void typedCodesAreForgiving() {
        assertThat(CircleService.normalizeCode("k7p-3mx ")).isEqualTo("K7P3MX");
        assertThat(CircleService.normalizeCode(" K7P 3MX")).isEqualTo("K7P3MX");
        assertThat(CircleService.normalizeCode("K7P3M")).isNull();
        assertThat(CircleService.normalizeCode("K7P3MO")).isNull();
        assertThat(CircleService.normalizeCode(null)).isNull();
    }

    @Test
    void namesAreOneTrimmedLine() {
        assertThat(CircleService.cleanName("  Ravi \n Krishna ", 40)).isEqualTo("Ravi Krishna");
        assertThat(CircleService.cleanName("రవి", 40)).isEqualTo("రవి");
        assertThat(CircleService.cleanName("   ", 40)).isNull();
        assertThat(CircleService.cleanName("x".repeat(41), 40)).isNull();
    }

    @Test
    void requestsKeepTheirLineBreaks() {
        assertThat(CircleService.cleanText(" Please pray for my mother.\n\n\n\nShe is in hospital. "))
                .isEqualTo("Please pray for my mother.\n\nShe is in hospital.");
        assertThat(CircleService.cleanText("\n \n")).isNull();
        assertThat(CircleService.cleanText("x".repeat(1001))).isNull();
    }

    @Test
    void reportsRemoveARequestOnceEnoughMembersAgree() {
        assertThat(CircleService.removedByReports(1, 2)).isTrue();   // the only other reader
        assertThat(CircleService.removedByReports(1, 5)).isFalse();
        assertThat(CircleService.removedByReports(2, 5)).isTrue();   // half of the other four
        assertThat(CircleService.removedByReports(2, 50)).isFalse();
        assertThat(CircleService.removedByReports(3, 50)).isTrue();
    }

    @Test
    void createsJoinsAndAsks() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.create(INSTALL, new NewCircle(" Family ", "Ravi"), http);
        controller.join(INSTALL, new Join("k7p-3mx", "Ravi"), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Pray for my exam"), http);
        assertThat(service.calls).containsExactly(
                "create Family by Ravi", "join K7P3MX as Ravi", "ask K7P3MX Pray for my exam");
    }

    @Test
    void rejectsBadInput() {
        var controller = controller(new Recording(), 10);
        var http = new MockHttpServletRequest();
        assertThatThrownBy(() -> controller.create("x", new NewCircle("Family", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        assertThatThrownBy(() -> controller.create(INSTALL, new NewCircle("", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest(" "), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        assertThatThrownBy(() -> controller.join(INSTALL, new Join("nope", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("NOT_FOUND");
    }

    @Test
    void codesCannotBeGuessedByTryingThemAll() {
        var service = new Recording();
        var controller = controller(service, 3);
        var http = new MockHttpServletRequest();
        for (int i = 0; i < 3; i++) controller.join(INSTALL, new Join("K7P3MX", "Ravi"), http);
        assertThatThrownBy(() -> controller.join(INSTALL, new Join("K7P3MY", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("TOO_MANY_REQUESTS");
        assertThat(service.calls).hasSize(3);
    }
}
