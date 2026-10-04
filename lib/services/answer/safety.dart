/// On-device check for messages that suggest the person may be at risk.
///
/// This is a safety net, not the primary detector — the backend LLM also
/// classifies risk. When either fires, the app shows helplines *before*
/// any Scripture, because verses are not a substitute for urgent care.
abstract final class Safety {
  static final _patterns = [
    // English and common romanised Hindi/Urdu
    RegExp(
      r"suicid|kill (my ?self|me)|end (my|it) (life|all)|want to die|wanna die|"
      r"don'?t want to (live|be alive)|no reason to live|better off dead|"
      r"self[- ]?harm|hurt(ing)? myself|cut(ting)? myself|take my (own )?life|"
      r"khud ?kushi|aatm?ahatya|atmahatya|marna chaht",
      caseSensitive: false,
    ),
    // "Suicide" in each supported Indian language
    RegExp(
      'आत्महत्या|मरना चाहत|ఆత్మహత్య|தற்கொலை|ಆತ್ಮಹತ್ಯೆ|ആത്മഹത്യ|'
      'ਖੁਦਕੁਸ਼ੀ|ਖ਼ੁਦਕੁਸ਼ੀ|ਆਤਮਹੱਤਿਆ|আত্মহত্যা|આત્મહત્યા|ଆତ୍ମହତ୍ୟା',
    ),
    // Spanish, Portuguese, French, Swahili, Tagalog, German, Italian, Polish, Russian, Ukrainian
    RegExp(
      'quiero morir|matarme|quitarme la vida|acabar con mi vida|no quiero vivir|hacerme daño|'
      'suic[ií]d|quero morrer|me matar|tirar (a )?minha (própria )?vida|'
      'não quero (mais )?viver|me machucar|veux mourir|me tuer|en finir|plus envie de vivre|'
      'me faire du mal|kujiua|nataka kufa|sitaki kuishi|kujidhuru|magpakamatay|pagpapakamatay|'
      'gusto ko nang mamatay|ayoko nang mabuhay|saktan ang sarili|suizid|selbstmord|'
      'mich umbringen|sterben will|will sterben|nicht mehr leben|mir das leben nehmen|'
      'voglio morire|uccidermi|togliermi la vita|non voglio più vivere|farmi del male|samobój|'
      'chcę umrzeć|zabić się|odebrać sobie życie|nie chcę żyć|skrzywdzić się|самоубий|суицид|'
      'покончить с собой|хочу умереть|не хочу жить|убить себя|навредить себе|самогубств|суїцид|'
      'покінчити з собою|хочу померти|не хочу жити|вбити себе|нашкодити собі',
      caseSensitive: false,
      unicode: true,
    ),
  ];

  static bool isCrisis(String text) => _patterns.any((p) => p.hasMatch(text));
}
