package com.jesusanswers.api.answer;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Deterministic crisis check, mirroring the app's lib/services/answer/safety.dart.
 * The model also classifies risk; either one firing marks the answer as a crisis.
 */
public final class Safety {

    private static final List<Pattern> PATTERNS = List.of(
            Pattern.compile(
                    "suicid|kill (my ?self|me)|end (my|it) (life|all)|want to die|wanna die|"
                            + "don'?t want to (live|be alive)|no reason to live|better off dead|"
                            + "self[- ]?harm|hurt(ing)? myself|cut(ting)? myself|take my (own )?life|"
                            + "khud ?kushi|aatm?ahatya|atmahatya|marna chaht",
                    Pattern.CASE_INSENSITIVE),
            Pattern.compile(
                    "आत्महत्या|मरना चाहत|ఆత్మహత్య|தற்கொலை|ಆತ್ಮಹತ್ಯೆ|ആത്മഹത്യ|"
                            + "ਖੁਦਕੁਸ਼ੀ|ਖ਼ੁਦਕੁਸ਼ੀ|ਆਤਮਹੱਤਿਆ|আত্মহত্যা|આત્મહત્યા|ଆତ୍ମହତ୍ୟା"));

    private Safety() {}

    public static boolean isCrisis(String text) {
        return text != null && PATTERNS.stream().anyMatch(p -> p.matcher(text).find());
    }
}
