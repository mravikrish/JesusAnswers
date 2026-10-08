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
            return new Detail(code, "Family", true, true, List.of(), List.of());
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
        public Detail addRequest(String device, String code, String text, String prayerId, boolean forLeaders,
                                 boolean anonymous) {
            calls.add((prayerId == null ? "ask " + code + " " + text : "share " + code + " " + prayerId + " [" + text + "]")
                    + (forLeaders ? " (leaders)" : "") + (anonymous ? " (anonymous)" : ""));
            return empty(code);
        }

        @Override
        public Detail prayed(String device, String code, long requestId) {
            calls.add("prayed " + requestId);
            return empty(code);
        }

        @Override
        public Detail setLeader(String device, String code, long memberId, boolean on) {
            calls.add((on ? "leader " : "not leader ") + memberId);
            return empty(code);
        }

        @Override
        public Detail pin(String device, String code, long requestId, boolean on) {
            calls.add((on ? "pin " : "unpin ") + requestId);
            return empty(code);
        }
    }

    static CircleController controller(Recording service, int joinsPerHour) {
        return new CircleController(service, new CommunityService(null, "salt"), new RateLimiter(100),
                new RateLimiter(3000), new RateLimiter(joinsPerHour));
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
    void leadersHelpTheOwnerLookAfterTheCircle() {
        // The owner can remove anyone else, leaders included.
        assertThat(CircleService.mayRemove(true, false, false, false)).isTrue();
        assertThat(CircleService.mayRemove(true, false, false, true)).isTrue();
        // A leader can remove members, but not the owner or another leader.
        assertThat(CircleService.mayRemove(false, true, false, false)).isTrue();
        assertThat(CircleService.mayRemove(false, true, false, true)).isFalse();
        assertThat(CircleService.mayRemove(false, true, true, false)).isFalse();
        // A member can't remove anyone.
        assertThat(CircleService.mayRemove(false, false, false, false)).isFalse();
    }

    @Test
    void makesLeadersAndPins() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.makeLeader(INSTALL, "K7P3MX", 12, http);
        controller.unmakeLeader(INSTALL, "K7P3MX", 12, http);
        controller.pin(INSTALL, "K7P-3MX", 40, http);
        controller.unpin(INSTALL, "K7P3MX", 40, http);
        assertThat(service.calls).containsExactly("leader 12", "not leader 12", "pin 40", "unpin 40");
    }

    @Test
    void aWholeChurchOnOneWifiIsNotBlocked() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();   // every phone has the same address
        for (int phone = 0; phone < 300; phone++) {
            String install = "%08d-7b4d-4e8a-9f00-1234567890ab".formatted(phone);
            controller.prayed(install, "K7P3MX", 1, http);
        }
        assertThat(service.calls).hasSize(300);
    }

    @Test
    void privateRequestsGoToLeadersAndAnonymousOnesHideTheName() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("My marriage is struggling", null, true, true), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Pray for my exam", null, false, null), http);
        // A shared prayer is always for everyone, with the sharer's name.
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("", "psalm23", true, true), http);
        assertThat(service.calls).containsExactly(
                "ask K7P3MX My marriage is struggling (leaders) (anonymous)", "ask K7P3MX Pray for my exam",
                "share K7P3MX psalm23 []");

        // Who asked is hidden from other members, but never from the asker or the leaders.
        assertThat(CircleService.hidesName(true, false, false)).isTrue();
        assertThat(CircleService.hidesName(true, true, false)).isFalse();
        assertThat(CircleService.hidesName(true, false, true)).isFalse();
        assertThat(CircleService.hidesName(false, false, false)).isFalse();
    }

    @Test
    void aCrisisAlertIsNeverCrowdedOut() {
        var start = java.time.Instant.parse("2026-10-09T08:00:00Z");
        var items = new ArrayList<CircleService.News>();
        items.add(new CircleService.News("request", "K7P3MX", "Grace Church", 1L, "Anil", "I want to end my life",
                null, 0, start, true));
        for (int i = 1; i <= 30; i++) {
            items.add(new CircleService.News("prayed", "K7P3MX", "Grace Church", 2L, null, "", null, i,
                    start.plusSeconds(i * 60), false));
        }
        var kept = CircleService.newest(items);
        assertThat(kept).hasSize(CircleService.MAX_NEWS);
        assertThat(kept.getFirst().crisis()).isTrue();
        assertThat(kept.getLast().count()).isEqualTo(30);
    }

    @Test
    void createsJoinsAndAsks() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.create(INSTALL, new NewCircle(" Family ", "Ravi"), http);
        controller.join(INSTALL, new Join("k7p-3mx", "Ravi"), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Pray for my exam", null, null, null), http);
        assertThat(service.calls).containsExactly(
                "create Family by Ravi", "join K7P3MX as Ravi", "ask K7P3MX Pray for my exam");
    }

    @Test
    void sharesAReadyPrayerWithOrWithoutANote() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest(null, "psalm23", null, null), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest(" Let's pray this tonight ", "psalm23", null, null), http);
        assertThat(service.calls).containsExactly(
                "share K7P3MX psalm23 []", "share K7P3MX psalm23 [Let's pray this tonight]");
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest(null, "../etc", null, null), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
    }

    @Test
    void rejectsBadInput() {
        var controller = controller(new Recording(), 10);
        var http = new MockHttpServletRequest();
        assertThatThrownBy(() -> controller.create("x", new NewCircle("Family", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        assertThatThrownBy(() -> controller.create(INSTALL, new NewCircle("", "Ravi"), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest(" ", null, null, null), http))
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
