#!/usr/bin/env python3
"""Add pipe-separated alternative glosses to polysemous words in chapter TOON data."""

import json
import sys
import re

# Polysemous word definitions: lemma → list of all real meanings
# When we find a word with this lemma, we keep its current gloss as correct
# and add the OTHER meanings as alternatives
POLYSEMOUS = {
    # Each list: all genuinely distinct meanings (conjugated + infinitive forms)
    # The script matches the form automatically
    "capiō": ["catch", "catches", "seize", "take", "capture", "to catch", "to seize", "to take"],
    "faciō": ["make", "makes", "do", "does", "produce", "cause", "to make", "to do"],
    "moveō": ["move", "moves", "stir", "affect", "shake", "to move", "are moved", "is moved"],
    "agō": ["come on!", "do", "drive", "act", "lead", "to do", "to drive", "to act"],
    "videō": ["see", "sees", "perceive", "observe", "notice", "to see", "is seen", "to be seen"],
    "audiō": ["hear", "hears", "listen to", "obey", "to hear", "is heard", "to be heard", "listen!"],
    "habeō": ["have", "has", "hold", "possess", "consider", "to have", "to hold"],
    "pōnō": ["place", "put", "set", "lay down", "to place", "is placed", "to be placed"],
    "dūcō": ["lead", "is drawn", "draw", "guide", "bring", "to be led"],
    "quaerō": ["seek", "look for", "ask", "investigate", "to seek"],
    "vocō": ["call", "summon", "name", "invite", "to call", "to be called"],
    "portō": ["carry", "bring", "convey", "transport", "to carry", "is carried", "to be carried"],
    "emō": ["buy", "purchase", "acquire", "to buy", "to be bought"],
    "currō": ["run", "hasten", "rush", "race", "to run"],
    "cadō": ["fall", "drop", "collapse", "perish", "to fall"],
    "aspiciō": ["watch", "look at", "observe", "behold", "to look at"],
    "edō": ["eat", "consume", "devour", "to eat", "to be eaten"],
    "canō": ["sing", "chant", "recite", "play (music)", "to sing"],
    "occultō": ["hide", "conceal", "cover", "keep secret", "are hidden"],
    "sustineō": ["support", "hold up", "endure", "bear", "to support"],
    "intrō": ["enter", "go into", "penetrate", "begin"],
    "timeō": ["fear", "dread", "be afraid of", "worry about", "to fear"],
    "reperiō": ["find", "discover", "learn", "obtain", "to find", "to be found"],
    "aperiō": ["open", "uncover", "reveal", "disclose", "to open", "to be opened"],
    "teneō": ["hold", "keep", "grasp", "restrain", "to hold", "to be held"],
    "iubeō": ["order", "command", "bid", "direct", "to order"],
    "vīvō": ["live", "dwell", "survive", "endure", "to live"],
    "veniō": ["come", "arrive", "approach", "come!"],
    "exeō": ["go out", "leave", "depart", "emerge"],
    "accurrō": ["run up", "hurry to", "rush to", "to run up"],
    "rīdeō": ["laugh", "smile", "mock", "to laugh"],
    "lātrō": ["bark", "howl", "bay", "snarl"],
    "clāmō": ["shout", "cry out", "proclaim", "call out"],
    "interrogō": ["ask", "question", "inquire", "examine"],
    "ascendō": ["climb", "go up", "mount", "ascend", "to climb"],
    "lūdō": ["play", "to play", "sport", "mock", "trick"],
}

# Words to SKIP (too common/functional, or not truly polysemous in context)
SKIP_LEMMAS = {"sum", "possum", "spīrō", "natō", "ambulō", "volō", "numerō"}

# Minimum number of alternatives to show (besides the correct one)
MIN_ALTS = 2
MAX_ALTS = 4


def normalize(g):
    """Normalize a gloss for comparison: strip prefixes like 'to ', '!', and lowercase."""
    g = g.lower().strip().rstrip("!").strip()
    g = g.removeprefix("to ").removeprefix("to be ")
    # Strip verb conjugation suffixes: catches→catch, carries→carri (ok for comparison)
    if g.endswith("es"):
        g = g[:-2]
    elif g.endswith("s"):
        g = g[:-1]
    return g


def pick_alternatives(lemma, current_gloss):
    """Pick alternative glosses for a polysemous word, excluding the current correct gloss."""
    if lemma in SKIP_LEMMAS:
        return []
    meanings = POLYSEMOUS.get(lemma, [])
    if not meanings:
        return []

    current_norm = normalize(current_gloss)
    # Determine if current gloss is an infinitive ("to X") or passive
    is_infinitive = current_gloss.lower().startswith("to ")
    is_passive = "is " in current_gloss.lower() or "are " in current_gloss.lower()

    alts = []
    seen_norms = {current_norm}
    for m in meanings:
        m_norm = normalize(m)
        # Skip if normalized form matches current or already seen
        if m_norm in seen_norms:
            continue
        # Skip "to X" forms when current is conjugated (and vice versa)
        m_is_inf = m.lower().startswith("to ")
        m_is_pass = "is " in m.lower() or "are " in m.lower()
        if is_infinitive != m_is_inf:
            continue
        if is_passive != m_is_pass:
            continue
        seen_norms.add(m_norm)
        alts.append(m)

    if len(alts) < MIN_ALTS:
        return []  # Not enough distinct alternatives

    # Pick up to MAX_ALTS alternatives, preferring shorter/simpler ones
    alts.sort(key=lambda x: len(x))
    return alts[:MAX_ALTS]


def process_toon(toon_str):
    """Process a TOON string and add pipe-separated glosses to polysemous words."""
    if not toon_str:
        return toon_str

    lines = toon_str.split("\n")
    if len(lines) < 2:
        return toon_str

    header = lines[0]
    # Parse header to find field positions
    m = re.search(r'\{([^}]+)\}', header)
    if not m:
        return toon_str
    fields = m.group(1).split(",")

    try:
        t_idx = fields.index("t")
        g_idx = fields.index("g")
        l_idx = fields.index("l")
    except ValueError:
        return toon_str

    p_idx = fields.index("p") if "p" in fields else None

    modified = False
    new_lines = [header]

    for line in lines[1:]:
        if not line.strip():
            new_lines.append(line)
            continue

        # Parse CSV (handling quoted fields)
        values = parse_csv(line)
        if len(values) <= max(t_idx, g_idx, l_idx):
            new_lines.append(line)
            continue

        text = values[t_idx]
        gloss = values[g_idx]
        lemma = values[l_idx] if values[l_idx] else text  # Use text as lemma if empty
        pos = values[p_idx] if p_idx is not None and p_idx < len(values) else ""

        # Skip punctuation, empty glosses, already pipe-separated
        if not gloss or "|" in gloss or not text.strip() or len(text.strip()) <= 1:
            new_lines.append(line)
            continue

        # Skip non-content words
        if pos in ("", "conj", "prep", "num"):
            new_lines.append(line)
            continue

        alts = pick_alternatives(lemma, gloss)
        if alts:
            # Replace the gloss field with pipe-separated version
            values[g_idx] = gloss + "|" + "|".join(alts)
            new_lines.append(",".join(values))
            modified = True
        else:
            new_lines.append(line)

    if modified:
        return "\n".join(new_lines)
    return toon_str


def parse_csv(line):
    """Parse a CSV line handling quoted fields."""
    values = []
    current = ""
    in_quotes = False
    for ch in line:
        if ch == '"':
            in_quotes = not in_quotes
            current += ch
        elif ch == ',' and not in_quotes:
            values.append(current)
            current = ""
        else:
            current += ch
    values.append(current)
    return values


def main():
    if len(sys.argv) < 2:
        print("Usage: python add_polysemous_glosses.py <chapter-id>")
        print("Example: python add_polysemous_glosses.py ch-10")
        sys.exit(1)

    chapter_id = sys.argv[1]
    import os
    chapter_path = os.path.expanduser(
        f"~/Library/Application Support/PENSVM/chapters/{chapter_id}/chapter.json"
    )

    if not os.path.exists(chapter_path):
        print(f"Error: {chapter_path} not found")
        sys.exit(1)

    with open(chapter_path, "r") as f:
        chapter = json.load(f)

    total_words_modified = 0
    total_blocks_modified = 0

    for page in chapter["pages"]:
        for block in page["content"]:
            if block.get("type") != "text":
                continue
            toon = block.get("toon")
            if not toon:
                continue

            # Skip grammar-table blocks
            if block.get("style") == "grammar-table":
                continue

            new_toon = process_toon(toon)
            if new_toon != toon:
                # Count modifications
                old_pipes = toon.count("|")
                new_pipes = new_toon.count("|")
                # But subtract pipes that are stem|ending markers in grammar tables
                words_added = sum(1 for line in new_toon.split("\n")[1:]
                                  if "|" in line.split(",")[2] if len(line.split(",")) > 2
                                  and "|" not in toon.split("\n")[new_toon.split("\n").index(line)]
                                  if line in new_toon.split("\n"))
                block["toon"] = new_toon
                total_blocks_modified += 1

    # Count actual polysemous words in final output
    poly_count = 0
    for page in chapter["pages"]:
        for block in page["content"]:
            toon = block.get("toon", "")
            if not toon:
                continue
            for line in toon.split("\n")[1:]:
                parts = line.split(",")
                if len(parts) > 2 and "|" in parts[2]:
                    # Make sure it's a gloss pipe, not a stem|ending
                    poly_count += 1

    # Write back
    with open(chapter_path, "w") as f:
        json.dump(chapter, f, indent=2, ensure_ascii=False)

    print(f"Done! Chapter: {chapter_id}")
    print(f"  Blocks modified: {total_blocks_modified}")
    print(f"  Polysemous words: {poly_count}")


if __name__ == "__main__":
    main()
