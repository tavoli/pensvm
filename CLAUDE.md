# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PENSVM is a native macOS app for practicing Latin exercises from "Lingua Latina per se Illustrata" (LLPSI). Users drag & drop images of PENSVM A exercises, the app uses Claude CLI to extract and structure the content, then presents an interactive fill-in-the-gap interface.

## Tech Stack

- **Platform:** macOS 13+ (Ventura)
- **Framework:** SwiftUI
- **Language:** Swift 5.9+
- **AI:** Claude CLI (invoked as subprocess)

## Architecture

```
Views (SwiftUI)
├── DropZoneView      → Initial drag & drop screen
├── LoadingView       → Processing state
├── ExerciseView      → Main practice interface
├── ReferencePanel    → Latin cases/conjugations overlay
└── SummaryView       → Results screen

ViewModels
└── ExerciseViewModel → Manages exercise state and flow

Models
├── Exercise          → Collection of sentences
├── Sentence          → Parts array (text + gaps)
├── SentencePart      → Enum: .text(String) or .gap(Gap)
└── Gap               → stem, correctEnding, dictionaryForm, wordType, userAnswer

Services
└── ClaudeCLIService  → Invokes Claude CLI for image → JSON parsing
```

## Data Model

Gap validation is case-insensitive and accepts answers with or without macrons (ā = a).

## Design Rules (Strict)

- **Colors:** White (#FFFFFF), Black (#000000), Green (#00FF00) only
- **Borders:** 1px solid black
- **Typography:** System defaults only
- **Animations:** None
- **State changes:** Binary swap (white ↔ green)
- **Target:** Under 50 lines of CSS equivalent styling

## Keyboard Navigation

- Tab/Shift+Tab: Navigate between gaps
- Enter: Check answers (1st press) → Advance to next sentence (2nd press)
- Cmd+R or ?: Open reference panel
- Esc: Close modals
- Cmd+O: Open new image

## Claude CLI Integration

The app invokes Claude CLI as a subprocess with these flags:
- `-p <prompt>` — Prompt with image path
- `--output-format json` — Structured JSON output
- `--json-schema <schema>` — Enforces response structure
- `--allowedTools Read` — Permits Claude to read the image file
- `--no-session-persistence` — Stateless invocation

Claude CLI path resolution (in order):
1. `~/.local/bin/claude` (native binary - recommended)
2. `~/.nvm/versions/node/<latest>/bin/claude` (legacy npm install)
3. `/usr/local/bin/claude` (system fallback)

Expected response format (via `structured_output`):
```json
{
  "sentences": [
    {
      "parts": [
        {"type": "text", "content": "Roma in "},
        {"type": "gap", "stem": "Itali", "correctEnding": "ā", "dictionaryForm": "Italia", "wordType": "noun (1st decl)"},
        {"type": "text", "content": " est."}
      ]
    }
  ]
}
```

## Key Behaviors

- Accepts PNG, JPG, JPEG images
- Processing target: < 15 seconds
- Answer comparison: case-insensitive, macron-tolerant
- Correct answers: green background
- Incorrect answers: white background with correct answer shown in parentheses below
- Debug mode: Uses mock data in DEBUG builds for fast iteration
