package com.jesusanswers.api.community;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.server.ResponseStatusException;

import com.jesusanswers.api.answer.RateLimiter;
import com.jesusanswers.api.community.CommunityController.Reaction;
import com.jesusanswers.api.community.CommunityService.Kind;

class CommunityTest {

    static final String INSTALL = "3f2a9c1e-7b4d-4e8a-9f00-1234567890ab";

    /** Records instead of writing to the database. */
    static class Recording extends CommunityService {
        final List<String> recorded = new ArrayList<>();

        Recording() {
            super(null, "salt");
        }

        @Override
        public void record(String item, Kind kind, String installId) {
            recorded.add(item + " " + kind);
        }
    }

    @Test
    void acceptsOnlyKnownKindsOfItem() {
        assertThat(CommunityService.validItem("prayer:hopeless")).isTrue();
        assertThat(CommunityService.validItem("story:prodigal_son")).isTrue();
        assertThat(CommunityService.validItem("chapter:JHN.3")).isTrue();
        assertThat(CommunityService.validItem("saying:MAT.11.28")).isTrue();
        assertThat(CommunityService.validItem("user:ravi")).isFalse();
        assertThat(CommunityService.validItem("prayer:")).isFalse();
        assertThat(CommunityService.validItem("prayer:a b")).isFalse();
        assertThat(CommunityService.validItem(null)).isFalse();
    }

    @Test
    void storesOnlyASaltedHashOfTheInstall() {
        String stored = new Recording().device(INSTALL);
        assertThat(stored).hasSize(64).doesNotContain(INSTALL);
        assertThat(new Recording().device(INSTALL)).isEqualTo(stored);
        assertThat(new CommunityService(null, "other").device(INSTALL)).isNotEqualTo(stored);
    }

    @Test
    void recordsAReaction() {
        var service = new Recording();
        var controller = new CommunityController(service, new RateLimiter(10));
        assertThat(controller.react(INSTALL, new Reaction("prayer:hopeless", Kind.PRAYED), new MockHttpServletRequest())
                .getStatusCode().value()).isEqualTo(204);
        assertThat(service.recorded).containsExactly("prayer:hopeless PRAYED");
    }

    @Test
    void rejectsBadItemsAndInstallIds() {
        var controller = new CommunityController(new Recording(), new RateLimiter(10));
        assertThatThrownBy(() -> controller.react(INSTALL, new Reaction("user:ravi", Kind.HEART), new MockHttpServletRequest()))
                .isInstanceOf(ResponseStatusException.class);
        assertThatThrownBy(() -> controller.react("x", new Reaction("prayer:hopeless", Kind.HEART), new MockHttpServletRequest()))
                .isInstanceOf(ResponseStatusException.class);
    }

    @Test
    void oneInstallCannotFloodTheCounts() {
        var service = new Recording();
        var controller = new CommunityController(service, new RateLimiter(3));
        for (int i = 0; i < 3; i++) {
            controller.react(INSTALL, new Reaction("story:creation", Kind.LISTENED), new MockHttpServletRequest());
        }
        assertThatThrownBy(() -> controller.react(INSTALL, new Reaction("story:creation", Kind.LISTENED),
                new MockHttpServletRequest()))
                .isInstanceOf(ResponseStatusException.class)
                .hasMessageContaining("TOO_MANY_REQUESTS");
        assertThat(service.recorded).hasSize(3);
    }
}
