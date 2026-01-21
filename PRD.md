# PRD - Latin PENSVM Trainer

## Product Requirements Document
**Version:** 1.0
**Date:** January 2025
**Author:** Gustavo Jonathan (tavoli)

---

## 1. Overview

### 1.1 Product Name
**PENSVM** (suggested name - simple, direct, evokes the original exercise)

Alternatives considered:
- Latin PENSVM Trainer
- Lacūna (Latin for "gap/space")
- Scrībe (Latin for "write")

### 1.2 Problem Statement

Latin students using the "Lingua Latina per se Illustrata" (LLPSI) method face a significant barrier when practicing PENSVM A exercises:

| Current Situation | Impact |
|-------------------|--------|
| Manually copying text before practicing | ~2 days of work (1h/day) per exercise |
| No access to physical book = no practice | Learning interruption |
| Tedious process demotivates the student | Study abandonment |

### 1.3 Proposed Solution

Native macOS application that:
1. Receives PENSVM A image via drag & drop
2. Uses OpenAI Vision API to extract and structure the exercise
3. Presents interactive interface for immediate practice

**Time reduction:** From ~2 days to ~30 seconds to start practicing.

### 1.4 Target Audience

| Persona | Description | Main Need |
|---------|-------------|-----------|
| Self-taught student | Adult learning Latin alone | Efficient practice without physical book |
| Homeschooling parent | Teaches children with classical education | Quickly prepare exercises |
| Latin teacher | Uses LLPSI in classes | Create digital activities for students |

---

## 2. User Stories

### 2.1 Epic: Upload and Processing

```
US-001: Drag & Drop Upload
As a Latin student
I want to drag a PENSVM A image to the application
So that I can start practicing immediately

Acceptance Criteria:
- The entire app window is a drop area
- Accepts formats: PNG, JPG, JPEG
- Visual feedback during hover (background turns green)
- Also works with click to open file picker
- Image is sent for processing automatically
```

```
US-002: AI Processing
As a student
I want the AI to automatically extract text and identify gaps
So that I don't need to do any manual configuration

Acceptance Criteria:
- Extraction identifies complete words vs. gaps
- Gaps are marked where there are dashes (e.g., "vill-", "habit-")
- Punctuation and sentence structure are preserved
- Processing time < 15 seconds
- Plain text "Processing..." shown during processing
```

```
US-003: Upload Error Feedback
As a student
I want clear feedback if something goes wrong with upload/processing
So that I know how to correct it

Acceptance Criteria:
- Format error: "Unsupported format. Use PNG, JPG or JPEG."
- Connection error: "No connection. Check your internet."
- API error: "Could not process. Try again."
- Unreadable image: "Image too blurry. Try a sharper photo."
- "Try again" button always visible on errors
```

### 2.2 Epic: Exercise Interface

```
US-004: Sentence-by-Sentence Display
As a student
I want to see one sentence at a time on screen
So that I can focus without distraction

Acceptance Criteria:
- Single sentence centered on screen
- Progress indicator as plain text (e.g., "3 / 15")
- System default font
- Gap fields have 1px black border to distinguish from text
```

```
US-005: Gap Input Fields
As a student
I want text fields in the gaps to type the endings
So that I can complete the exercise

Acceptance Criteria:
- Inline field with the word (e.g., "vill[___]" where ___ is editable)
- Field sized for ~5 characters (typical endings)
- 1px solid black border indicating it's editable
- Cursor blinks in first field when sentence loads
```

```
US-006: Keyboard Navigation
As a student
I want to navigate between gaps using Tab and Shift+Tab
So that I keep my hands on keyboard and am faster

Acceptance Criteria:
- Tab: next gap (or Enter if last)
- Shift+Tab: previous gap
- Enter: check answers (1st) or advance (2nd)
- Clear visual focus on active field
- No "focus trap" - Tab on last gap doesn't return to start
```

### 2.3 Epic: Correction System

```
US-007: Answer Verification
As a student
I want to press Enter to check my answers
So that I know immediately if I got them right

Acceptance Criteria:
- Enter (1st time): reveals correction
- Correct answer: field background turns green
- Incorrect answer: field stays white, correct answer shown below in black text
- Fields become read-only after correction
```

```
US-008: Advance to Next Sentence
As a student
I want to press Enter again to go to the next sentence
So that the flow is continuous

Acceptance Criteria:
- Enter (2nd time): loads next sentence
- Instant screen change (no animations)
- Cursor already positioned in first gap
- If last sentence: goes to summary screen
```

### 2.4 Epic: Quick Reference

```
US-009: Cases/Conjugations Table
As a beginner student
I want to quickly access a reference table
So that I can look up endings when in doubt

Acceptance Criteria:
- Text button [?] always visible (screen corner)
- Keyboard shortcut: Cmd+R or ?
- Opens as overlay panel with 1px black border
- Content:
  | Case/Mode | Question | Singular | Plural |
  |-----------|----------|----------|--------|
  | Nominative | Who? (subject) | -a, -us, -um | -ae, -ī, -a |
  | Accusative | Whom/What? (object) | -am, -um | -ās, -ōs, -a |
  | Ablative | Where?/With what? | -ā, -ō | -īs |
  | Genitive | Whose? | -ae, -ī | -ārum, -ōrum |
  | Dative | To whom? | -ae, -ō | -īs |
  | Vocative | O...! | -a, -e, -um | -ae, -ī, -a |
  | Imperative | Command | -ā, -ē, -e, -ī | -āte, -ēte, -ite |
  | Indicative | He/she does | -at, -et, -it | -ant, -ent, -unt |
- Close with Esc or [Close] button
- White background, black text and borders
```

### 2.5 Epic: Completion

```
US-010: Summary Screen
As a student
I want to see a summary of my performance at the end
So that I know how I did

Acceptance Criteria:
- Displays as plain text: total gaps, correct, errors
- Percentage correct shown as number (e.g., "87%")
- Total exercise time
- Optional list of mistakes made
- Plain text buttons with black border: "New Exercise", "Review Errors"
```

---

## 3. Technical Specifications

### 3.1 Platform and Stack

| Component | Technology | Justification |
|-----------|------------|---------------|
| Platform | Native macOS | Better integration, performance |
| Framework | SwiftUI | Modern, declarative UI |
| Language | Swift 5.9+ | Apple standard |
| Minimum OS | macOS 13 (Ventura) | Mature SwiftUI |
| AI API | OpenAI Vision (GPT-4o) | High precision in OCR + comprehension |

### 3.2 Architecture

```
┌─────────────────────────────────────────────────────┐
│                    PENSVM App                        │
├─────────────────────────────────────────────────────┤
│  Views (SwiftUI)                                    │
│  ├── DropZoneView (initial screen)                 │
│  ├── LoadingView (processing)                      │
│  ├── ExerciseView (practice)                       │
│  ├── ReferencePanel (cases table)                  │
│  └── SummaryView (final result)                    │
├─────────────────────────────────────────────────────┤
│  ViewModels                                         │
│  ├── ExerciseViewModel                             │
│  └── OpenAIService                                 │
├─────────────────────────────────────────────────────┤
│  Models                                             │
│  ├── Exercise (set of sentences)                   │
│  ├── Sentence (sentence with gaps)                 │
│  └── Gap (individual gap)                          │
├─────────────────────────────────────────────────────┤
│  Services                                           │
│  └── OpenAIVisionService                           │
└─────────────────────────────────────────────────────┘
```

### 3.3 Data Model

```swift
struct Exercise {
    let id: UUID
    let sentences: [Sentence]
    let createdAt: Date
}

struct Sentence {
    let id: UUID
    let parts: [SentencePart]  // Alternation between text and gaps
}

enum SentencePart {
    case text(String)
    case gap(Gap)
}

struct Gap {
    let id: UUID
    let stem: String           // Word stem (e.g., "vill")
    let correctEnding: String  // Correct ending (e.g., "a")
    var userAnswer: String?    // User's answer

    var isCorrect: Bool? {
        guard let answer = userAnswer else { return nil }
        return answer.lowercased() == correctEnding.lowercased()
    }
}
```

### 3.4 OpenAI Vision Integration

**Endpoint:** `POST https://api.openai.com/v1/chat/completions`

**System Prompt:**
```
You are a Latin exercise parser. You will receive an image of a PENSVM A exercise
from "Lingua Latina per se Illustrata".

Your task:
1. Extract all text from the image
2. Identify words with blanks (indicated by dashes like "vill-", "habit-")
3. Determine the correct ending for each blank based on Latin grammar

Return a JSON array of sentences. Each sentence has "parts" alternating between
regular text and gaps.

Example output:
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

Important:
- Preserve all punctuation
- Use macrons (ā, ē, ī, ō, ū) when grammatically required
- If unsure about an ending, use the most common/expected form
```

**Model:** `gpt-4o` (best cost-benefit for vision)

**Configuration:**
```swift
struct OpenAIRequest: Codable {
    let model: String = "gpt-4o"
    let messages: [Message]
    let maxTokens: Int = 4096
    let responseFormat: ResponseFormat = .init(type: "json_object")
}
```

### 3.5 Local Storage

| Data | Storage | Reason |
|------|---------|--------|
| API Key | Keychain | Security |
| Last exercise | UserDefaults (JSON) | Quick recovery |
| History (future) | Core Data / SQLite | Complex queries |
| Preferences | UserDefaults | Apple standard |

---

## 4. Design and UX

### 4.1 Core Philosophy

**Styling slows down development by 3x.** The UI should look like a wireframe or whiteboard sketch. Prioritize function over form. Zero visual complexity.

### 4.2 Design Principles

1. **Function over form** - Make it work, not pretty
2. **Whiteboard aesthetic** - Should look like a sketch
3. **Keyboard-first** - 100% operable without mouse
4. **Instant feedback** - Binary state changes only
5. **Speed** - Prioritize readability and performance

### 4.3 Visual Rules

| Rule | Specification |
|------|---------------|
| Background | Plain white only (#FFFFFF) |
| Borders | Black, 1px solid |
| Colors | No gradients, no shadows |
| Animations | None |
| State changes | Binary color swap only (white ↔ green) |
| Typography | System defaults, no custom fonts |

### 4.4 Layout Rules

- Simple divs with solid colors
- Grid-based using basic squares/rectangles
- Vertical form layout: label stacked above input
- Only essential positioning and spacing
- No styling adornments

### 4.5 Color Palette (Strict)

| Use | Color | Hex |
|-----|-------|-----|
| Background | White | #FFFFFF |
| Text / Borders | Black | #000000 |
| Success state | Green | #00FF00 |

**That's it. No other colors.**

### 4.6 Typography

| Element | Specification |
|---------|---------------|
| All text | System default font |
| Sizes | Browser defaults |
| Weights | Normal only |

### 4.7 Interaction States

| State | Behavior |
|-------|----------|
| Default | White background |
| Hover | White → Green background |
| Active/Click | White → Green background |
| Focus | 1px black border (standard) |

**No transitions or animations between states.**

### 4.8 Descriptive Wireframes

#### Screen 1: Drop Zone (Initial)

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│                                                        │
│            ┌────────────────────────────┐             │
│            │                            │             │
│            │    Drop PENSVM image here  │             │
│            │        or click            │             │
│            │                            │             │
│            └────────────────────────────┘             │
│                                                        │
│                                                        │
│                                                        │
├────────────────────────────────────────────────────────┤
│  [Settings]                               [?]          │
└────────────────────────────────────────────────────────┘

- Background: white
- Drop area: 1px solid black border
- Hover: drop area background becomes green
- No icons, just text
```

#### Screen 2: Loading

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│                                                        │
│                                                        │
│                     Processing...                      │
│                                                        │
│                    [Cancel]                            │
│                                                        │
│                                                        │
│                                                        │
│                                                        │
│                                                        │
└────────────────────────────────────────────────────────┘

- Plain text "Processing..."
- Simple text button to cancel
- No spinner, no animation
```

#### Screen 3: Exercise

```
┌────────────────────────────────────────────────────────┐
│  PENSVM · Ch. I                              3 / 15   │
├────────────────────────────────────────────────────────┤
│                                                        │
│                                                        │
│                                                        │
│       Roma in Itali[____] est. Itali[____]            │
│                                                        │
│       in Europ[____] est.                             │
│                                                        │
│                                                        │
│                                                        │
├────────────────────────────────────────────────────────┤
│  Tab: next  |  Enter: check  |  ?: reference          │
└────────────────────────────────────────────────────────┘

- All borders: 1px solid black
- Input fields: white background, black border
- Focus: standard browser focus ring
- Text centered in content area
```

#### Screen 3b: Exercise (After Correction)

```
┌────────────────────────────────────────────────────────┐
│  PENSVM · Ch. I                              3 / 15   │
├────────────────────────────────────────────────────────┤
│                                                        │
│                                                        │
│                                                        │
│       Roma in Itali[ā ✓] est. Itali[e  ]              │
│                                    (ā)                 │
│       in Europ[ā ✓] est.                              │
│                                                        │
│                                                        │
│                                                        │
├────────────────────────────────────────────────────────┤
│                  Enter: next sentence                  │
└────────────────────────────────────────────────────────┘

- Correct: green background, black text
- Incorrect: white background, correct answer shown below in parentheses
- Fields become read-only
```

#### Screen 4: Summary

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│                   Exercise Complete                    │
│                                                        │
│                        87%                             │
│                                                        │
│                  26 of 30 correct                      │
│                  Time: 12:34                           │
│                                                        │
│              ┌──────────────────────┐                 │
│              │    New Exercise      │                 │
│              └──────────────────────┘                 │
│              ┌──────────────────────┐                 │
│              │    Review Errors     │                 │
│              └──────────────────────┘                 │
│                                                        │
└────────────────────────────────────────────────────────┘

- Buttons: white background, 1px black border
- Hover: green background
- Plain text, no icons
```

#### Screen 5: Reference Panel

```
┌────────────────────────────────────────────────────────┐
│  Reference                                    [Close] │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Case        | Question      | Sing.    | Plur.       │
│  ──────────────────────────────────────────────────── │
│  Nominative  | Who?          | -a -us   | -ae -ī      │
│  Accusative  | Whom?         | -am -um  | -ās -ōs     │
│  Ablative    | Where?        | -ā -ō    | -īs         │
│  Genitive    | Whose?        | -ae -ī   | -ārum -ōrum │
│  Dative      | To whom?      | -ae -ō   | -īs         │
│  Vocative    | O...!         | -a -e    | -ae -ī      │
│                                                        │
└────────────────────────────────────────────────────────┘

- Simple table with text
- 1px black borders
- Close button in corner
```

### 4.9 CSS Constraints

**Target: Entire app styling in under 50 lines of CSS**

```css
/* Example minimal CSS */
* { box-sizing: border-box; }
body { background: #fff; font-family: system-ui; }
button, input { border: 1px solid #000; background: #fff; }
button:hover, input:focus { background: #0f0; }
.correct { background: #0f0; }
```

### 4.10 Design DO's and DON'Ts

**DO:**
- Make it look like a whiteboard sketch
- Use plain everything
- Prioritize readability and speed
- Use browser defaults

**DON'T:**
- Add gradients or shadows
- Use animations or transitions
- Apply decorative styling
- Use colors beyond white, black, and green
- Use custom fonts
- Add icons where text suffices

---

## 5. Edge Cases and Error Handling

### 5.1 Upload and Processing

| Scenario | Behavior |
|----------|----------|
| Image too small (<200px) | "Image too small. Use a higher resolution." |
| Image too large (>20MB) | "File too large. Maximum 20MB." |
| Invalid format | "Unsupported format. Use PNG, JPG, or PDF." |
| PDF with multiple pages | Processes first page only, warns user |
| Image is not PENSVM | "Could not identify a PENSVM exercise. Check the image." |
| Blurry image | "Image not sharp enough. Try a clearer photo." |
| API timeout (>30s) | "Took longer than expected. Try again?" |
| Network error | "No internet connection." + retry button |
| Invalid API key | "Invalid API key. Check settings." |
| Quota exceeded | "API usage limit reached. Try again later." |

### 5.2 During Exercise

| Scenario | Behavior |
|----------|----------|
| User closes app during exercise | Saves progress, offers to resume on reopen |
| Answer with extra spaces | Automatic trim, accepts |
| Answer with uppercase | Case-insensitive comparison |
| Answer with macron vs without | Accepts both (á = ā) |
| Empty field when checking | Marks as error, shows answer |
| All gaps correct | Plain text "Perfect!" |
| All wrong | Plain text "Keep practicing!" |

### 5.3 Special Situations

| Scenario | Behavior |
|----------|----------|
| Gap in middle of word | Supported (e.g., "am-mus" → "ā") |
| Multiple valid answers | AI returns most common; future: accept variants |
| Text in CAPITALS (Roman style) | Normalizes to lowercase in exercise |
| Special characters (ẽ, æ) | Supported via Unicode |

---

## 6. Success Metrics

### 6.1 Technical Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Processing time | < 15 seconds | Timer in app |
| Extraction accuracy | > 95% | Manual comparative tests |
| Crash rate | < 0.1% | Analytics (future) |
| App size | < 10 MB | Final build |

### 6.2 User Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| Time to start practice | < 30 seconds | From drop to first gap |
| Completion rate | > 80% | Exercises started vs. finished |
| Average time per exercise | 15-25 minutes | Internal timer |
| NPS (future) | > 50 | In-app survey |

### 6.3 Business Metrics (Future)

| Metric | Target |
|--------|--------|
| Downloads (first week) | 100+ |
| Monthly active users | 500+ after 3 months |
| D7 retention | > 30% |

---

## 7. MVP Timeline

### Phase 1: Foundation (Week 1-2)
- [ ] Xcode project setup + SwiftUI
- [ ] Data model (Exercise, Sentence, Gap)
- [ ] Basic OpenAI Vision integration
- [ ] Functional drop zone screen

### Phase 2: Core Loop (Week 3-4)
- [ ] Exercise view with sentences
- [ ] Input fields for gaps
- [ ] Tab/Shift+Tab navigation
- [ ] Enter system for correction

### Phase 3: Polish (Week 5)
- [ ] Summary screen
- [ ] Reference table
- [ ] Complete error handling
- [ ] Keyboard navigation refinement

### Phase 4: Release (Week 6)
- [ ] Real user testing
- [ ] Final adjustments
- [ ] Distribution preparation (TestFlight or direct)
- [ ] Basic documentation

**Total estimated: 6 weeks**

---

## 8. Accessibility Considerations

### 8.1 Requirements

| Category | Implementation |
|----------|----------------|
| VoiceOver | Descriptive labels on all elements |
| Keyboard | 100% navigable without mouse |
| Contrast | High contrast (black on white) by default |
| Font size | Respects system Dynamic Type |
| Motion | No animations (accessible by design) |

### 8.2 Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Tab | Next gap |
| Shift+Tab | Previous gap |
| Enter | Check / Advance |
| Cmd+R or ? | Open reference |
| Esc | Close modals |
| Cmd+O | Open new image |
| Cmd+, | Settings |

---

## 9. Testing Strategy

### 9.1 Unit Tests

```swift
// Examples of critical tests

func testGapCorrectAnswer() {
    var gap = Gap(stem: "vill", correctEnding: "a")
    gap.userAnswer = "a"
    XCTAssertTrue(gap.isCorrect)
}

func testGapCaseInsensitive() {
    var gap = Gap(stem: "vill", correctEnding: "a")
    gap.userAnswer = "A"
    XCTAssertTrue(gap.isCorrect)
}

func testGapWithMacron() {
    var gap = Gap(stem: "Itali", correctEnding: "ā")
    gap.userAnswer = "a"  // Without macron
    XCTAssertTrue(gap.isCorrect)  // Should accept
}
```

### 9.2 Integration Tests

| Test | Description |
|------|-------------|
| OpenAI Parse | Send real image, validate JSON structure |
| Full Flow | Drop → Process → Exercise → Complete |
| Error Recovery | Simulate network failure, verify retry |

### 9.3 User Tests

**Scenario 1: First Use**
1. User opens app for the first time
2. Without instructions, tries to upload
3. Observe: can they figure it out alone?

**Scenario 2: Complete Exercise**
1. Upload real PENSVM Ch. I
2. Complete all sentences
3. Measure: total time, frustrations, confusions

**Scenario 3: Error Recovery**
1. Upload invalid image
2. Observe: is message clear? Do they know what to do?

---

## 10. Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Inaccurate OCR | Medium | High | Prompt engineering; manual fallback |
| High API cost | Low | Medium | Exercise caching; monitor usage |
| Incorrect macrons | Medium | Low | Accept versions without macron |
| App rejected from App Store | Low | High | Distribute via website/TestFlight |

---

## 11. Future Scope (Post-MVP)

### v1.1
- Click on word to see base form/infinitive
- Exercise history
- Export results to text file

### v1.2
- Pre-loaded chapters (I-X)
- iCloud sync
- Detailed statistics

### v2.0
- iOS/iPadOS
- Offline mode (local models?)
- Gamification (streaks, achievements)
- Community (share exercises)

---

## 12. Appendix

### A. OpenAI Response Example

```json
{
  "sentences": [
    {
      "parts": [
        {"type": "text", "content": "Roma in "},
        {"type": "gap", "stem": "Itali", "correctEnding": "ā"},
        {"type": "text", "content": " est."}
      ]
    },
    {
      "parts": [
        {"type": "gap", "stem": "Itali", "correctEnding": "a"},
        {"type": "text", "content": " in "},
        {"type": "gap", "stem": "Europ", "correctEnding": "ā"},
        {"type": "text", "content": " est."}
      ]
    },
    {
      "parts": [
        {"type": "gap", "stem": "Graeci", "correctEnding": "ī"},
        {"type": "text", "content": " in "},
        {"type": "gap", "stem": "Europ", "correctEnding": "ā"},
        {"type": "text", "content": " "},
        {"type": "gap", "stem": "habit", "correctEnding": "ant"},
        {"type": "text", "content": "."}
      ]
    }
  ]
}
```

### B. Complete Latin Cases Table

| Case | Function | 1st Decl. (f) | 2nd Decl. (m) | 2nd Decl. (n) |
|------|----------|---------------|---------------|---------------|
| **Nominative** | Subject | -a / -ae | -us / -ī | -um / -a |
| **Genitive** | Possession | -ae / -ārum | -ī / -ōrum | -ī / -ōrum |
| **Dative** | Indirect obj. | -ae / -īs | -ō / -īs | -ō / -īs |
| **Accusative** | Direct obj. | -am / -ās | -um / -ōs | -um / -a |
| **Ablative** | Circumstance | -ā / -īs | -ō / -īs | -ō / -īs |
| **Vocative** | Address | -a / -ae | -e / -ī | -um / -a |

### C. Verb Conjugations (Present Tense)

| Person | 1st Conj. (-āre) | 2nd Conj. (-ēre) | 3rd Conj. (-ere) | 4th Conj. (-īre) |
|--------|------------------|------------------|------------------|------------------|
| 1s | -ō | -eō | -ō | -iō |
| 2s | -ās | -ēs | -is | -īs |
| 3s | -at | -et | -it | -it |
| 1p | -āmus | -ēmus | -imus | -īmus |
| 2p | -ātis | -ētis | -itis | -ītis |
| 3p | -ant | -ent | -unt | -iunt |

---

*Document created January 2025. Subject to revisions during development.*
