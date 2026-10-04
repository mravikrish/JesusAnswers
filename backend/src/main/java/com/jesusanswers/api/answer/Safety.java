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
                            + "ਖੁਦਕੁਸ਼ੀ|ਖ਼ੁਦਕੁਸ਼ੀ|ਆਤਮਹੱਤਿਆ|আত্মহত্যা|આત્મહત્યા|ଆତ୍ମହତ୍ୟା"),
            // Spanish, Portuguese, French, Swahili, Tagalog, German, Italian, Polish, Russian, Ukrainian
            Pattern.compile(
                    "quiero morir|matarme|quitarme la vida|acabar con mi vida|no quiero vivir|hacerme daño|"
                            + "suic[ií]d|quero morrer|me matar|tirar (a )?minha (própria )?vida|"
                            + "não quero (mais )?viver|me machucar|veux mourir|me tuer|en finir|plus envie de vivre|"
                            + "me faire du mal|kujiua|nataka kufa|sitaki kuishi|kujidhuru|magpakamatay|pagpapakamatay|"
                            + "gusto ko nang mamatay|ayoko nang mabuhay|saktan ang sarili|suizid|selbstmord|"
                            + "mich umbringen|sterben will|will sterben|nicht mehr leben|mir das leben nehmen|"
                            + "voglio morire|uccidermi|togliermi la vita|non voglio più vivere|farmi del male|samobój|"
                            + "chcę umrzeć|zabić się|odebrać sobie życie|nie chcę żyć|skrzywdzić się|самоубий|суицид|"
                            + "покончить с собой|хочу умереть|не хочу жить|убить себя|навредить себе|самогубств|суїцид|"
                            + "покінчити з собою|хочу померти|не хочу жити|вбити себе|нашкодити собі",
                    Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE));

    private Safety() {}

    public static boolean isCrisis(String text) {
        return text != null && PATTERNS.stream().anyMatch(p -> p.matcher(text).find());
    }
}
