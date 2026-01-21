# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PENSVM is a native macOS app for practicing Latin exercises from "Lingua Latina per se Illustrata" (LLPSI). Users drag & drop images of PENSVM A exercises, the app uses OpenAI Vision API to extract and structure the content, then presents an interactive fill-in-the-gap interface.

## Tech Stack

- **Platform:** macOS 13+ (Ventura)
- **Framework:** SwiftUI
- **Language:** Swift 5.9+
- **AI:** OpenAI Vision API (GPT-4o)
- **API Key:** Read from environment variable `OPENAI_API_KEY`

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
└── Gap               → stem, correctEnding, userAnswer

Services
└── OpenAIVisionService → Handles image → JSON parsing via API
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

## OpenAI Integration

Endpoint: `POST https://api.openai.com/v1/chat/completions`

Expected response format:
```json
{
  "sentences": [
    {
      "parts": [
        {"type": "text", "content": "Roma in "},
        {"type": "gap", "stem": "Itali", "correctEnding": "ā"},
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
