"""Checks the daily Bible questions (assets/questions/) against the Bibles the app ships.

For every language: each question has its words (the question, four different options, what the story
is about, and a thought to take into the day); its passage is in that
language's Bible; and for a question about a person or place ("names": true), the right answer is in
the passage itself and every other option is somewhere in that Bible — so names are spelt as people
read them in their own Bible.

    python tool/check_questions.py              check everything
    python tool/check_questions.py --show ID    print a question's passage in every language
"""
import gzip, json, pathlib, re, sys, unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
QUESTIONS = ROOT / "assets" / "questions"
BIBLES = ROOT / "assets" / "bible" / "full"
PASSAGE = re.compile(r"^(\S+) (\d+):(\d+)(?:-(\d+))?$")

sys.stdout.reconfigure(encoding="utf-8")


def bible(lang):
    with gzip.open(BIBLES / f"{lang}.json.gz", "rt", encoding="utf-8") as f:
        return json.load(f)


def passage_text(b, passage):
    m = PASSAGE.match(passage)
    if not m:
        return None
    book, ch, start = m.group(1), int(m.group(2)), int(m.group(3))
    end = int(m.group(4) or start)
    try:
        verses = b["chapters"][book][ch - 1]
    except (KeyError, IndexError):
        return None
    text = " ".join(verses[v - 1] for v in range(start, end + 1) if v - 1 < len(verses))
    return text.strip() or None


# Malayalam final consonants (chillu): one letter now, consonant + virama + zero-width joiner in older
# text; and the consonant it becomes before an ending (ലാസർ → ലാസറേ).
CHILLU = {"ൺ": "ണ", "ൻ": "ന", "ർ": "രറ", "ൽ": "ല", "ൾ": "ള"}
OLD_CHILLU = {base[0] + "്‍": chillu for chillu, base in CHILLU.items()}
OLD_CHILLU["റ്‍"] = "ർ"


def same_letters(text):
    for old, new in OLD_CHILLU.items():
        text = text.replace(old, new)
    return text


# Russian and Ukrainian names change their last letter with case (Синай → на горе Синае, Иона → Иону).
SLAVIC_ENDINGS = set("аяоеиыйьуюіїє")


def found(name, text):
    """[name] in [text], allowing for its ending to change, as names do when they are called out or
    take a case ending (Tamil சிம்சோன் → சிம்சோனே, Telugu సౌలు → సౌలూ, Malayalam ലാസർ → ലാസറേ,
    Russian Синай → Синае): the name without its final vowel sign or virama, with its final chillu as
    the plain consonant, or without a final Cyrillic vowel, й or ь, is enough. A name of several words
    (Иисус Навин) is found when each word is."""
    if " " in name:
        return all(found(word, text) for word in name.split())
    name, text = same_letters(name), same_letters(text)
    if name in text:
        return True
    stem = name
    while stem and unicodedata.category(stem[-1]) in ("Mn", "Mc"):
        stem = stem[:-1]
    stems = [stem] if stem != name else []
    if name[-1:] in CHILLU:
        stems += [name[:-1] + base for base in CHILLU[name[-1]]]
    if name[-1:].lower() in SLAVIC_ENDINGS and len(name) >= 4:
        stems.append(name[:-1])
    return any(len(s) >= 2 and s in text for s in stems)


def main():
    index = json.loads((QUESTIONS / "questions.json").read_text(encoding="utf-8"))["questions"]
    langs = sorted(p.stem for p in QUESTIONS.glob("*.json") if p.stem != "questions")

    if len(sys.argv) == 3 and sys.argv[1] == "--show":
        q = next(q for q in index if q["id"] == sys.argv[2])
        for lang in langs:
            print(f"--- {lang}: {passage_text(bible(lang), q['passage'])}\n")
        return

    problems = []
    ids = [q["id"] for q in index]
    if len(ids) != len(set(ids)):
        problems.append("question ids repeat")
    for lang in langs:
        words = json.loads((QUESTIONS / f"{lang}.json").read_text(encoding="utf-8"))
        b = bible(lang)
        whole = None
        for q in index:
            where = f"{lang} {q['id']}"
            w = words.get(q["id"])
            if w is None:
                problems.append(f"{where}: not translated")
                continue
            if not w.get("question") or not w.get("about") or not w.get("think"):
                problems.append(f"{where}: question, about or think missing")
            options = w.get("options", [])
            if len(options) != 4 or len(set(options)) != 4:
                problems.append(f"{where}: needs four different options")
            text = passage_text(b, q["passage"])
            if text is None:
                problems.append(f"{where}: passage {q['passage']} not in this Bible")
                continue
            if q.get("names") and options:
                if not found(options[0], text):
                    problems.append(f"{where}: answer '{options[0]}' is not in {q['passage']}")
                if whole is None:
                    whole = " ".join(v for book in b["chapters"].values() for ch in book for v in ch)
                for other in options[1:]:
                    if not found(other, whole):
                        problems.append(f"{where}: '{other}' is nowhere in this Bible")
        extra = set(words) - set(ids)
        if extra:
            problems.append(f"{lang}: words for unknown questions {sorted(extra)}")
    for p in problems:
        print(p)
    print(f"{len(index)} questions, {len(langs)} languages: {'all good' if not problems else f'{len(problems)} problems'}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
