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
| `f` | Grammatical form | "abl.s" |
| `p` | Part of speech | "n" |

**Part of speech abbreviations:** `n` (noun), `v` (verb), `adj`, `adv`, `prep`, `conj`, `pron`, `num`

**Format:**
```
words[N]{t,l,g,f,p}:
word1,lemma1,gloss1,form1,pos1
word2,,,,
...
```

**Example:**
```
words[5]{t,l,g,f,p}:
In,,in (+abl),,prep
Italiā,Italia,Italy,abl.s,n
multae,multus,many,nom.pl.f,adj
sunt,sum,are,3pl,v
.,,,,
```

### Polysemous Words

For words with genuinely distinct Latin meanings (not just slight translation variants), use pipe `|` separation in the `g` field. The **context-correct gloss comes first**, followed by 2–4 real alternatives:

```
petit,petō,seeks|attacks|asks for|heads toward,pres.3s,v
agit,agō,drives|does|acts|leads,pres.3s,v
```

**Rules:**
- Only for words with genuinely distinct meanings in Latin — not near-synonyms
- Context-correct gloss always first
- 2–4 alternatives (total 3–5 options including the correct one)
- Grammar table words: always single gloss (no pipe separation)
- Common function words (est, et, in, etc.): single gloss unless truly ambiguous in context

### 4. Write Updated Chapter

Add `toon` field to each text block. Preserve all existing data.

### 5. Report Summary

```
Annotation complete:
- Chapter: ch-06 - Via Latina
- Text blocks annotated: 12
- Total words: 847
```
