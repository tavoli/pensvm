# Annotate Chapter

Add word-level grammatical annotations to a chapter using TOON format.

## Usage

```
/annotate-chapter <chapter-id>
```

## Arguments

- `$ARGUMENTS` - Chapter ID (e.g., `ch-06`)

## Instructions

### 1. Load Chapter

- Verify chapter exists at: `~/Library/Application Support/PENSVM/chapters/{chapter-id}/chapter.json`
- Read and parse the JSON

### 2. Process Text Blocks

For each ContentBlock with `type: "text"`:
- Skip if `toon` field already exists
- Annotate each word in ALL text blocks regardless of style
- **This includes ALL grammar styles:** `grammar`, `grammar-title`, and `grammar-subtitle` must be annotated — never skip grammar blocks

### 3. TOON Format

| Field | Description | Example |
|-------|-------------|---------|
| `t` | Word as it appears | "viā" |
| `l` | Lemma (empty if same as t) | "via" |
| `g` | English gloss (pipe-separated for polysemous words) | "road" or "seeks\|attacks\|asks for" |
| `f` | Grammatical form (never include gender here — use `gd` instead) | "abl.s", "acc.pl" |
| `p` | Part of speech | "n" |
| `gn` | Genitive singular form (nouns/adjectives only, empty otherwise) | "viae" |
| `gd` | Gender (nouns/adjectives only: f, m, n — empty otherwise) | "f" |
| `ir` | Irregular declension (1 = irregular, empty = regular) | "1" |

**Part of speech abbreviations:** `n` (noun), `v` (verb), `adj`, `adv`, `prep`, `conj`, `pron`, `num`

**Format:**
```
words[N]{t,l,g,f,p,gn,gd,ir}:
word1,lemma1,gloss1,form1,pos1,gen1,gender1,
word2,,,,,,,
...
```

**Example:**
```
words[5]{t,l,g,f,p,gn,gd,ir}:
In,,in (+abl),,prep,,,
Italiā,Italia,Italy,abl.s,n,Italiae,f,
multae,multus,many,nom.pl,adj,multī,f,
sunt,sum,are,3pl,v,,,
.,,,,,,,
```

**Genitive form rules:**
- For nouns: full genitive singular (e.g., "viae", "servī", "leōnis", "portūs", "diēī")
- For adjectives: genitive singular masculine (e.g., "multī", "bonī", "omnis")
- Empty for verbs, prepositions, conjunctions, etc.

**Gender rules:**
- `f` (feminine), `m` (masculine), `n` (neuter)
- For adjectives: use the gender matching the form in context (e.g., "multae" in "multae vīllae" → `f`)
- Empty for verbs, prepositions, conjunctions, etc.

**Irregular declension rules (`ir` field):**
- Set `ir` to `1` for pronomial adjectives that follow a mixed declension pattern (gen. sing. `-īus`, dat. sing. `-ī`): `alius`, `nūllus`, `sōlus`, `tōtus`, `ūnus`, `ūllus`, `neuter`, `alter`, `uter`
- Also for other irregular nouns/adjectives that don't fit standard declension tables
- Leave empty for all regular nouns, adjectives, verbs, and other parts of speech

### Polysemous Words

For words with genuinely distinct Latin meanings (not just slight translation variants), use pipe `|` separation in the `g` field. The **context-correct gloss comes first**, followed by 2–4 real alternatives:

```
petit,petō,seeks|attacks|asks for|heads toward,pres.3s,v,,,
agit,agō,drives|does|acts|leads,pres.3s,v,,,
```

**Rules:**
- Only for words with genuinely distinct meanings in Latin — not near-synonyms
- Context-correct gloss always first
- 2–4 alternatives (total 3–5 options including the correct one)
- Grammar table words: always single gloss (no pipe separation)
- Common function words (est, et, in, etc.): single gloss unless truly ambiguous in context

### Gloss Notes (glossNotes)

For each text block that has polysemous words, add a `glossNotes` dict alongside `toon`. Keys are the word's index (position in the TOON word list, 0-based), values are short explanations of why the correct gloss fits this context.

```json
{
  "toon": "words[7]{t,l,g,f,p,gn,gd,ir}:\n...\ncapiunt,capiō,catch|seize|take|capture,3pl,v,,,\n...",
  "glossNotes": {
    "3": "The wild beasts hunt other animals, so they catch them as prey"
  }
}
```

**Rules:**
- Only for polysemous words (those with `|` in gloss)
- One sentence, under 20 words
- Explain based on the surrounding Latin context — what clues in the sentence point to this meaning
- Do not translate the full sentence
- Skip if the correct meaning is obvious from the immediate context

### 4. Write Updated Chapter

Add `toon` field (and `glossNotes` where applicable) to each text block. Preserve all existing data.

### 5. Report Summary

```
Annotation complete:
- Chapter: ch-06 - Via Latina
- Text blocks annotated: 12
- Total words: 847
```
