package com.jesusanswers.api.circle;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.util.HtmlUtils;

/**
 * An invite as a web link, https://…/join/K7P3MX, for the QR code on the church's screen and the
 * message people share: it opens the app's Join with the code filled in, and for someone without the
 * app yet, shows the code and where to get the app.
 *
 * It never looks the circle up, so the page tells no one whether a code is in use or what the circle
 * is called: joining still needs the app, under the same limits as always.
 */
@RestController
public class JoinPageController {

    static final String PACKAGE = "com.jesusanswers.jesus_answers";

    private final String downloadUrl;

    public JoinPageController(@Value("${jesusanswers.app-download-url}") String downloadUrl) {
        this.downloadUrl = downloadUrl;
    }

    @GetMapping(value = "/join/{code}", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> join(@PathVariable String code) {
        String c = CircleService.normalizeCode(code);
        if (c == null) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).contentType(MediaType.TEXT_HTML).body(page(null, downloadUrl));
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).contentType(MediaType.TEXT_HTML)
                .body(page(c, downloadUrl));
    }

    /** "K7P3MX" → "K7P-3MX", as the app shows it. */
    static String showCode(String code) {
        return code.substring(0, 3) + "-" + code.substring(3);
    }

    /**
     * Android's browsers open the app straight from an intent link when it's installed, and otherwise
     * come back to this page (?noapp) to show how to get it.
     */
    static String intentLink(String code) {
        return "intent://app/join/" + code + "#Intent;scheme=jesusanswers;package=" + PACKAGE
                + ";S.browser_fallback_url=" + java.net.URLEncoder.encode("/join/" + code + "?noapp=1",
                java.nio.charset.StandardCharsets.UTF_8) + ";end";
    }

    static String page(String code, String downloadUrl) {
        String download = HtmlUtils.htmlEscape(downloadUrl);
        String body;
        if (code == null) {
            body = """
                    <h1>This invite link isn't complete</h1>
                    <p>Ask the person who sent it for the circle's code, then open the app and join with it.</p>
                    <a class="button" href="%s">Get the app</a>
                    """.formatted(download);
        } else {
            String shown = showCode(code);
            String intent = HtmlUtils.htmlEscape(intentLink(code));
            body = """
                    <p class="kicker">Prayer circle invite</p>
                    <h1>You're invited to pray together</h1>
                    <p class="label">Invite code</p>
                    <p class="code" id="code">%1$s</p>
                    <a class="button" id="open" href="%2$s">Open in Ask Jesus</a>
                    <button class="ghost" id="copy" type="button">Copy the code</button>
                    <div class="card">
                      <h2>Don't have the app yet?</h2>
                      <ol>
                        <li>Copy the code above.</li>
                        <li>Get the app and open it.</li>
                        <li>Tap <b>Pray → Prayer Circles → Join with a code</b>. The code you copied is filled in.</li>
                      </ol>
                      <a class="button secondary" href="%3$s">Get the app</a>
                    </div>
                    <script>
                      const code = "%1$s";
                      document.getElementById("copy").onclick = async (e) => {
                        try { await navigator.clipboard.writeText(code); e.target.textContent = "Copied ✓"; }
                        catch (_) { e.target.textContent = code; }
                      };
                      // Straight into the app on Android, unless we just came back because it isn't installed.
                      if (/Android/i.test(navigator.userAgent) && !location.search.includes("noapp")) {
                        location.href = document.getElementById("open").href;
                      }
                    </script>
                    """.formatted(shown, intent, download);
        }
        return """
                <!doctype html>
                <html lang="en">
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <meta name="robots" content="noindex">
                <title>Join a prayer circle · Ask Jesus</title>
                <style>
                  :root { color-scheme: dark; }
                  body { margin: 0; min-height: 100vh; font-family: system-ui, sans-serif; color: #fff; text-align: center;
                         background: linear-gradient(#0A1430, #13234A 60%%, #1F3366); }
                  main { max-width: 420px; margin: 0 auto; padding: 40px 20px 48px; }
                  .kicker { color: #F2D293; letter-spacing: .08em; text-transform: uppercase; font-size: 13px; font-weight: 700; }
                  h1 { font-family: Georgia, serif; font-size: 28px; line-height: 1.25; margin: 8px 0 28px; }
                  h2 { font-family: Georgia, serif; font-size: 20px; margin: 0 0 8px; }
                  .label { color: rgba(255,255,255,.7); margin: 0; font-size: 14px; }
                  .code { font-size: 44px; font-weight: 800; letter-spacing: 6px; margin: 4px 0 24px; color: #F2D293; }
                  .button, .ghost { display: block; box-sizing: border-box; width: 100%%; padding: 16px; border-radius: 999px;
                         font-size: 17px; font-weight: 700; text-decoration: none; margin: 0 0 12px; border: 0; cursor: pointer; }
                  .button { background: #D9A54A; color: #0A1430; }
                  .ghost { background: transparent; color: #fff; border: 1px solid rgba(255,255,255,.5); }
                  .secondary { margin: 16px 0 0; }
                  .card { text-align: left; background: rgba(255,255,255,.07); border: 1px solid rgba(255,255,255,.12);
                          border-radius: 20px; padding: 20px; margin-top: 24px; }
                  ol { padding-left: 20px; line-height: 1.6; color: rgba(255,255,255,.88); }
                </style>
                </head>
                <body><main>
                %s
                </main></body>
                </html>
                """.formatted(body);
    }
}
