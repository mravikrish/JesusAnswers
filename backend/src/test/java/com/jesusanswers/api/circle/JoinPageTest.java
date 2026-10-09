package com.jesusanswers.api.circle;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class JoinPageTest {

    final JoinPageController controller = new JoinPageController("/download/ask-jesus.apk");

    @Test
    void opensTheAppWithTheCodeOrShowsWhereToGetIt() {
        var page = controller.join("k7p-3mx");
        assertThat(page.getStatusCode().value()).isEqualTo(200);
        assertThat(page.getBody())
                .contains("K7P-3MX")
                .contains("intent://app/join/K7P3MX#Intent;scheme=jesusanswers;package=com.jesusanswers.jesus_answers;")
                .contains("S.browser_fallback_url=%2Fjoin%2FK7P3MX%3Fnoapp%3D1")
                .contains("href=\"/download/ask-jesus.apk\"");
    }

    @Test
    void saysNothingAboutTheCircleItself() {
        // No lookup: a real code and a made-up one get the same page, so no one learns which codes exist.
        String real = controller.join("K7P3MX").getBody(), madeUp = controller.join("ZZZ222").getBody();
        assertThat(madeUp.replace("ZZZ-222", "K7P-3MX").replace("ZZZ222", "K7P3MX")).isEqualTo(real);
    }

    @Test
    void anIncompleteLinkStillPointsToTheApp() {
        var page = controller.join("nope");
        assertThat(page.getStatusCode().value()).isEqualTo(404);
        assertThat(page.getBody()).contains("isn't complete").contains("/download/ask-jesus.apk").doesNotContain("intent://");
    }

    @Test
    void escapesTheDownloadLink() {
        var page = new JoinPageController("https://x.example/a?b=1&c=\"2\"").join("K7P3MX").getBody();
        assertThat(page).contains("https://x.example/a?b=1&amp;c=&quot;2&quot;").doesNotContain("c=\"2\"");
    }
}
