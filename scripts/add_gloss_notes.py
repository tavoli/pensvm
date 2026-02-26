#!/usr/bin/env python3
"""Add glossNotes to polysemous words in ch-10 based on context."""

import json
import os

chapter_path = os.path.expanduser(
    "~/Library/Application Support/PENSVM/chapters/ch-10/chapter.json"
)

with open(chapter_path) as f:
    chapter = json.load(f)


def get_poly_indices(toon_str):
    """Return {word_index: (word, correct_gloss)} for polysemous words."""
    lines = toon_str.split("\n")
    result = {}
    for idx, line in enumerate(lines[1:]):
        if not line.strip():
            continue
        parts = line.split(",")
        if len(parts) > 2 and "|" in parts[2]:
            glosses = parts[2].split("|")
            result[idx] = (parts[0], glosses[0])
    return result


# Context-aware explanations keyed by (page_index, block_index_within_page, word_text, correct_gloss)
# We'll match on these to assign notes
EXPLANATIONS = {
    # Page 0, Block 1: "...quae aliās bēstiās capiunt et edunt..."
    ("capiunt", "catch"): "Predators hunting prey — they catch other animals",
    ("edunt", "eat"): "After catching prey, the beasts eat them",
    ("timent", "fear"): "Inhabitants dread lions because lions kill",
    ("capit", "catches"): "The eagle hunts small birds, catching them",
    ("edit", "eats"): "The eagle catches and then eats small birds",

    # Page 0, Block 2: "Avis duās ālās habet..."
    ("habet", "has"): "Describing body parts — a bird has two wings",
    ("habent", "have"): "Describing body parts that creatures possess",
    ("movet", "moves"): "Physical motion — flapping wings or stepping feet",
    ("moventur", "are moved"): "Passive: wings/feet are moved during flight or walking",

    # Page 1: Mercurius, fish, etc.
    ("portat", "carries"): "Mercury conveys the gods' commands to humans",
    ("emit", "buys"): "A merchant buys and sells goods for trade",
    ("facit", "makes"): "Describes earning money or producing footprints",
    ("faciunt", "make"): "Birds build nests — they make them in trees",
    ("aspicit", "watches"): "The dog gazes at birds flying among the trees",
    ("vīvunt", "live"): "Fish dwell in water, animals dwell on land",
    ("vīvit", "lives"): "A human lives as long as he breathes",
    ("intrat", "enters"): "Air goes into the lungs during breathing",
    ("exit", "exits"): "Air comes back out of the lungs",
    ("exits", "goes out"): "Julius leaves the house into the garden",

    # Page 2: children playing, Quintus falls
    ("tenet", "holds"): "Julia is holding the ball in her hands",
    ("quaerunt", "seek"): "The boys search for nests in the trees",
    ("Cape", "catch!"): "Julia tells Margarita to catch the thrown ball",
    ("rīdet", "laughs"): "The happy girl laughs with joy",
    ("canit", "sings"): "The girl produces a melody — she sings",
    ("audiunt", "hear"): "The boys perceive the girl singing",
    ("Audī", "listen!"): "Quintus tells Marcus to pay attention to Julia's voice",
    ("videt", "sees"): "Visual perception — the dog sees the bird above",
    ("vident", "see"): "Marcus and Julia see that Quintus is alive",
    ("capere", "to catch"): "The dog wants to catch the bird flying above",
    ("lātrat", "barks"): "The angry dog makes its natural sound",
    ("canunt", "sing"): "Birds produce song, unlike fish which have no voice",
    ("occultant", "hide"): "Small birds conceal themselves among leaves from the eagle",
    ("quaerit", "seeks"): "The eagle searches for food over the garden",
    ("reperit", "finds"): "Marcus discovers a nest in the tree",
    ("vocat", "calls"): "Marcus summons Quintus to come see the nest",
    ("Venī", "come!"): "Marcus tells Quintus to approach the tree",
    ("Accurrit", "runs up"): "Quintus hurries over to where Marcus is",
    ("Age", "come on!"): "Marcus urges Quintus to act — climb the tree",
    ("Ascende", "climb!"): "Marcus tells Quintus to go up into the tree",
    ("ascendit", "climbs"): "Quintus physically goes up into the tree",
    ("interrogat", "asks"): "Marcus poses a question about the eggs in the nest",
    ("sustinet", "supports"): "The branch physically holds up the nest",
    ("cadit", "falls"): "The branch breaks and drops to the ground",
    ("Rīdētne", "does he laugh?"): "Asking whether Marcus laughs — no, he's terrified",
    ("movent", "move"): "Neither the boy nor chicks stir after the fall",
    ("currit", "runs"): "Marcus runs to the house in terror",
    ("clāmat", "shouts"): "Marcus cries out loudly for his father",
    ("audit", "hears"): "Julius perceives the boy calling from the garden",
    ("accurrit", "runs up"): "Julia hurries to where Quintus lies",
    ("aperit", "opens"): "Quintus opens his eyes, showing he's alive",
    ("cadere", "to fall"): "Marcus sees Quintus falling from the tree",

    # Page 3: grammar section
    ("facit", "does"): "Asking what Marcus does — his action, not making something",
    ("exit", "goes out"): "Julius leaves the house to go into the garden",
    ("agere", "to do"): "Listed as a 3rd conjugation infinitive example",
    ("capere", "to seize"): "Listed as a 3rd conjugation infinitive example",
    ("vīdē", "see"): "Imperative: directing the reader to look at chapter XI",
}

total_notes = 0
total_blocks = 0

for page in chapter["pages"]:
    for block in page["content"]:
        toon = block.get("toon")
        if not toon:
            continue
        if block.get("style") == "grammar-table":
            continue

        polys = get_poly_indices(toon)
        if not polys:
            continue

        notes = {}
        for idx, (word, correct) in polys.items():
            key = (word, correct)
            if key in EXPLANATIONS:
                notes[str(idx)] = EXPLANATIONS[key]

        if notes:
            block["glossNotes"] = notes
            total_notes += len(notes)
            total_blocks += 1

with open(chapter_path, "w") as f:
    json.dump(chapter, f, indent=2, ensure_ascii=False)

print(f"Done! {total_notes} explanations across {total_blocks} blocks")
# Show coverage
all_polys = 0
for page in chapter["pages"]:
    for block in page["content"]:
        toon = block.get("toon", "")
        for line in toon.split("\n")[1:]:
            parts = line.split(",")
            if len(parts) > 2 and "|" in parts[2]:
                all_polys += 1
print(f"Coverage: {total_notes}/{all_polys} polysemous words have explanations")
