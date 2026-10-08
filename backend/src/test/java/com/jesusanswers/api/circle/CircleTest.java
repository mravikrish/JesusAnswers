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
import com.jesusanswers.api.circle.CircleController.Answered;
import com.jesusanswers.api.circle.CircleController.Join;
import com.jesusanswers.api.circle.CircleController.NewChain;
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
            return new Detail(code, "Family", true, true, List.of(), List.of(), false, false, List.of(), null,
                    List.of(), List.of(), List.of());
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
        public Detail addRequest(String device, String code, String text, String prayerId, String verse,
                                 boolean forLeaders, boolean anonymous, boolean praise) {
            String shared = prayerId != null ? prayerId : verse;
            calls.add((shared == null ? (praise ? "praise " : "ask ") + code + " " + text
                    : "share " + code + " " + shared + " [" + text + "]")
                    + (forLeaders ? " (leaders)" : "") + (anonymous ? " (anonymous)" : ""));
            return empty(code);
        }

        @Override
        public Detail answered(String device, String code, long requestId, String testimony) {
            calls.add("answered " + requestId + (testimony == null ? "" : " [" + testimony + "]"));
            return empty(code);
        }

        @Override
        public Detail createGroup(String device, String code, String name) {
            calls.add("group " + name + " in " + code);
            return empty(code);
        }

        @Override
        public Detail createChain(String device, String code, String title, java.time.Instant startsAt,
                                  int slotMinutes, int slots) {
            calls.add("chain " + title + " " + slots + "x" + slotMinutes);
            return empty(code);
        }

        @Override
        public Detail turn(String device, String code, long chainId, int slot, boolean on) {
            calls.add((on ? "take " : "give back ") + chainId + "/" + slot);
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
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("My marriage is struggling", null, null, true, true, null), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Pray for my exam", null, null, false, null, null), http);
        // A shared prayer is always for everyone, with the sharer's name.
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("", "psalm23", null, true, true, null), http);
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
                null, 0, start, true, null, null, null));
        for (int i = 1; i <= 30; i++) {
            items.add(new CircleService.News("prayed", "K7P3MX", "Grace Church", 2L, null, "", null, i,
                    start.plusSeconds(i * 60), false, null, null, null));
        }
        var kept = CircleService.newest(items);
        assertThat(kept).hasSize(CircleService.MAX_NEWS);
        assertThat(kept.getFirst().crisis()).isTrue();
        assertThat(kept.getLast().count()).isEqualTo(30);
    }

    @Test
    void sharesAVersePraiseAndTestimonies() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("This Sunday's sermon", null, "JHN 3:16", true, true, null), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Anil got the job!", null, null, true, true, true), http);
        controller.answered(INSTALL, "K7P3MX", 7, new Answered(" She is home from hospital "), http);
        controller.answered(INSTALL, "K7P3MX", 8, null, http);
        // A verse, and a praise report, are for everyone, with the name.
        assertThat(service.calls).containsExactly(
                "share K7P3MX JHN 3:16 [This Sunday's sermon]", "praise K7P3MX Anil got the job!",
                "answered 7 [She is home from hospital]", "answered 8");
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest("", null, "JHN 3", null, null, null), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
    }

    @Test
    void versesAreNamedAsTheAppNamesThem() {
        assertThat(CircleService.cleanVerse("JHN 3:16")).isEqualTo("JHN 3:16");
        assertThat(CircleService.cleanVerse("1CO 13:4")).isEqualTo("1CO 13:4");
        assertThat(CircleService.cleanVerse("PSA 119:105")).isEqualTo("PSA 119:105");
        assertThat(CircleService.cleanVerse("JHN 3:16-18")).isNull();
        assertThat(CircleService.cleanVerse("jhn 3:16")).isNull();
        assertThat(CircleService.cleanVerse("JHN 0:1")).isNull();
    }

    @Test
    void addsGroupsToAChurch() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.createGroup(INSTALL, "K7P3MX", new CircleController.NewGroup(" Youth "), http);
        assertThat(service.calls).containsExactly("group Youth in K7P3MX");
        assertThatThrownBy(() -> controller.createGroup(INSTALL, "K7P3MX", new CircleController.NewGroup(""), http))
                .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
    }

    @Test
    void prayerChainsAndFastingDays() {
        // An hour each for a day and a night; a day each for 40 days; not more, nor too short a turn.
        assertThat(CircleService.validChain(60, 24)).isTrue();
        assertThat(CircleService.validChain(1440, 40)).isTrue();
        assertThat(CircleService.validChain(1440, 41)).isFalse();
        assertThat(CircleService.validChain(60, 169)).isFalse();
        assertThat(CircleService.validChain(10, 6)).isFalse();
        assertThat(CircleService.validChain(60, 0)).isFalse();

        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        String tomorrow = java.time.Instant.now().plusSeconds(86400).toString();
        controller.createChain(INSTALL, "K7P3MX", new NewChain("24 hours for revival", tomorrow, 60, 24), http);
        controller.takeTurn(INSTALL, "K7P3MX", 5, 6, http);
        controller.giveBackTurn(INSTALL, "K7P3MX", 5, 6, http);
        assertThat(service.calls).containsExactly("chain 24 hours for revival 24x60", "take 5/6", "give back 5/6");

        String lastYear = java.time.Instant.now().minusSeconds(400L * 86400).toString();
        for (var bad : List.of(new NewChain("Fast", lastYear, 1440, 3), new NewChain("Fast", tomorrow, 1440, 41),
                new NewChain("Fast", "soon", 1440, 3), new NewChain(" ", tomorrow, 1440, 3))) {
            assertThatThrownBy(() -> controller.createChain(INSTALL, "K7P3MX", bad, http))
                    .isInstanceOf(ResponseStatusException.class).hasMessageContaining("BAD_REQUEST");
        }
    }

    @Test
    void createsJoinsAndAsks() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.create(INSTALL, new NewCircle(" Family ", "Ravi"), http);
        controller.join(INSTALL, new Join("k7p-3mx", "Ravi"), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest("Pray for my exam", null, null, null, null, null), http);
        assertThat(service.calls).containsExactly(
                "create Family by Ravi", "join K7P3MX as Ravi", "ask K7P3MX Pray for my exam");
    }

    @Test
    void sharesAReadyPrayerWithOrWithoutANote() {
        var service = new Recording();
        var controller = controller(service, 10);
        var http = new MockHttpServletRequest();
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest(null, "psalm23", null, null, null, null), http);
        controller.addRequest(INSTALL, "K7P3MX", new NewRequest(" Let's pray this tonight ", "psalm23", null, null, null, null), http);
        assertThat(service.calls).containsExactly(
                "share K7P3MX psalm23 []", "share K7P3MX psalm23 [Let's pray this tonight]");
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest(null, "../etc", null, null, null, null), http))
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
        assertThatThrownBy(() -> controller.addRequest(INSTALL, "K7P3MX", new NewRequest(" ", null, null, null, null, null), http))
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
