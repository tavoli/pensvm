#!/usr/bin/env python3
"""Extract illustrations from LLPSI pages.

Commands (no AI - Claude provides coordinates):
- info: Get image dimensions
- crop: Crop image to exact pixel coordinates
- split: Split 2-page spread into left/right pages

Commands (uses Gemini):
- margin: Crop margin strip (Gemini detects boundary)
- inline: Extract inline illustrations (Gemini detects objects)

Trimming workflow:
- Claude reads margin image, visually determines trim coordinates
- Claude calls: crop <margin.png> <output.png> 0 <top_y> <width> <bottom_y>
- Claude verifies result, adjusts if text was cut
"""

import sys
import json
import base64
from io import BytesIO
from pathlib import Path
from PIL import Image

# Default margin ratio (used as fallback if Gemini detection fails)
DEFAULT_MARGIN_RATIO = 0.25


# =============================================================================
# Simple operations (no AI) - Claude provides coordinates
# =============================================================================

def get_image_info(image_path: str) -> dict:
    """Get image dimensions and basic info.

    Args:
        image_path: Path to the image

    Returns:
        Dict with width, height, and format
    """
    image = Image.open(image_path)
    return {
        "width": image.width,
        "height": image.height,
        "format": image.format,
        "mode": image.mode
    }


def crop_region(image_path: str, output_path: str, x1: int, y1: int, x2: int, y2: int) -> dict:
    """Crop image to specified pixel coordinates.

    Args:
        image_path: Path to source image
        output_path: Path to save cropped image
        x1, y1: Top-left corner
        x2, y2: Bottom-right corner

    Returns:
        Dict with output path and dimensions
    """
    image = Image.open(image_path)

    # Ensure bounds are valid
    x1 = max(0, min(x1, image.width))
    y1 = max(0, min(y1, image.height))
    x2 = max(x1, min(x2, image.width))
    y2 = max(y1, min(y2, image.height))

    cropped = image.crop((x1, y1, x2, y2))

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    cropped.save(output_path)

    return {
        "file": output_path,
        "width": cropped.width,
        "height": cropped.height,
        "crop_box": {"x1": x1, "y1": y1, "x2": x2, "y2": y2}
    }


def split_spread(image_path: str, output_dir: str, split_x: int) -> dict:
    """Split a 2-page spread at the given x coordinate.

    Args:
        image_path: Path to source spread image
        output_dir: Directory to save left and right pages
        split_x: X coordinate where pages meet

    Returns:
        Dict with paths to left and right page images
    """
    image = Image.open(image_path)
    width, height = image.size

    # Ensure split_x is valid
    split_x = max(1, min(split_x, width - 1))

    left_page = image.crop((0, 0, split_x, height))
    right_page = image.crop((split_x, 0, width, height))

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    left_path = output_path / "left.png"
    right_path = output_path / "right.png"

    left_page.save(left_path)
    right_page.save(right_path)

    return {
        "left": {
            "file": str(left_path),
            "width": left_page.width,
            "height": left_page.height
        },
        "right": {
            "file": str(right_path),
            "width": right_page.width,
            "height": right_page.height
        },
        "split_x": split_x
    }


# =============================================================================
# AI-powered operations (uses Gemini)
# =============================================================================

def _get_genai_client():
    """Lazy import and create Gemini client."""
    from google import genai
    return genai.Client()


def detect_margin_boundary(image_path: str, side: str = "left") -> int:
    """Use Gemini to detect the margin column boundary.

    Args:
        image_path: Path to the source page image
        side: "left" for left margin, "right" for right margin

    Returns:
        The x-coordinate (in pixels) of the margin boundary, or None if detection fails
    """
    client = _get_genai_client()
    image = Image.open(image_path)
    width, height = image.size

    if side == "left":
        prompt = """Analyze this LLPSI (Lingua Latina) textbook page layout.

Find the RIGHT EDGE of the LEFT MARGIN COLUMN - this is the vertical line that separates:
- LEFT: The margin area (contains vocabulary illustrations, labels, notes)
- RIGHT: The main text area (contains the Latin prose paragraphs)

The margin boundary is typically where the main text block begins.

Return a JSON object with:
- "margin_x": the x-coordinate (normalized 0-1000) of the right edge of the left margin column
- "confidence": "high", "medium", or "low"

Example: {"margin_x": 280, "confidence": "high"}"""
    else:  # right margin
        prompt = """Analyze this LLPSI (Lingua Latina) textbook page layout.

Find the LEFT EDGE of the RIGHT MARGIN COLUMN - this is the vertical line that separates:
- LEFT: The main text area (contains the Latin prose paragraphs)
- RIGHT: The margin area (contains vocabulary illustrations, labels, notes)

The margin boundary is typically where the main text block ends and margin notes/illustrations begin.
Be conservative - if vocabulary notes or illustrations extend left, include them in the margin.

Return a JSON object with:
- "margin_x": the x-coordinate (normalized 0-1000) of the left edge of the right margin column
- "confidence": "high", "medium", or "low"

Example: {"margin_x": 720, "confidence": "high"}"""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=[image, prompt],
            config={
                "response_mime_type": "application/json",
                "thinking_config": {"thinking_budget": 0}
            }
        )

        result = json.loads(response.text)
        margin_x_normalized = result.get("margin_x", 250 if side == "left" else 750)

        # Convert normalized (0-1000) to pixels
        margin_x_pixels = int(margin_x_normalized * width / 1000)

        return margin_x_pixels

    except Exception as e:
        print(f"Warning: Margin detection failed: {e}", file=sys.stderr)
        return None


def crop_margin_strip(image_path: str, output_path: str, side: str = "left", use_ai: bool = True) -> dict:
    """Crop a margin column using Gemini to detect the boundary.

    The margin column in LLPSI pages contains both illustrations and text labels.
    Rather than trying to separate them, we crop the entire margin as one strip.

    Args:
        image_path: Path to the source page image
        output_path: Path to save the cropped margin strip
        side: "left" for left margin, "right" for right margin
        use_ai: If True, use Gemini to detect margin boundary; otherwise use fixed ratio

    Returns:
        Dict with output path and margin boundary info
    """
    image = Image.open(image_path)
    width, height = image.size

    margin_x = None
    detection_method = "fallback"

    if use_ai:
        try:
            margin_x = detect_margin_boundary(image_path, side=side)
            if margin_x:
                detection_method = "gemini"
        except Exception as e:
            print(f"Warning: AI margin detection failed: {e}", file=sys.stderr)
            margin_x = None

    # Fallback to fixed ratio if AI detection failed
    if margin_x is None:
        if side == "left":
            margin_x = int(width * DEFAULT_MARGIN_RATIO)
        else:
            margin_x = int(width * (1 - DEFAULT_MARGIN_RATIO))
        detection_method = "fallback"

    # Crop margin column
    if side == "left":
        # Left margin: (0, 0) to (margin_x, height)
        margin = image.crop((0, 0, margin_x, height))
    else:
        # Right margin: (margin_x, 0) to (width, height)
        margin = image.crop((margin_x, 0, width, height))

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    margin.save(output_path)

    return {
        "file": output_path,
        "side": side,
        "margin_x": margin_x,
        "margin_ratio": round(margin_x / width, 3) if side == "left" else round((width - margin_x) / width, 3),
        "detection_method": detection_method
    }


def extract_inline_illustrations(image_path: str, output_dir: str, exclude_left: int = None, exclude_right: int = None) -> list:
    """Extract inline illustrations from the main text area only.

    Uses Gemini to detect header illustrations, scene illustrations, and other
    inline images that appear in the main text area. Margin columns are excluded.

    Args:
        image_path: Path to the source image
        output_dir: Directory to save extracted illustrations
        exclude_left: Exclude content where x < this value (left margin boundary in pixels)
        exclude_right: Exclude content where x > this value (right margin boundary in pixels)

    Returns:
        List of dicts with index, label, file path, and bounding box info
    """
    client = _get_genai_client()  # Uses GOOGLE_API_KEY env var

    image = Image.open(image_path)
    width, height = image.size

    # Build exclusion zones for the prompt
    exclusion_rules = []
    left_boundary = 0
    right_boundary = 1000

    if exclude_left is not None and exclude_left > 0:
        left_boundary = int(exclude_left * 1000 / width)
        left_percent = int(left_boundary / 10)
        exclusion_rules.append(f"- LEFT MARGIN: x < {left_boundary} (left ~{left_percent}% of page)")

    if exclude_right is not None and exclude_right < width:
        right_boundary = int(exclude_right * 1000 / width)
        right_percent = int((1000 - right_boundary) / 10)
        exclusion_rules.append(f"- RIGHT MARGIN: x > {right_boundary} (right ~{right_percent}% of page)")

    exclusion_text = "\n".join(exclusion_rules) if exclusion_rules else "- No margins to exclude"

    prompt = f"""Detect inline illustrations in the MAIN TEXT AREA of this LLPSI (Lingua Latina) textbook page.

This is a Latin textbook page. It has TWO distinct areas:
1. MAIN TEXT AREA: Contains Latin prose paragraphs and large scene illustrations
2. MARGIN COLUMN: Contains vocabulary aids - small illustrations with Latin labels below them

MARGIN CONTENT TO NEVER EXTRACT (typically on left OR right edge of page):
- Small vocabulary illustrations (single objects, people, or scenes)
- Illustrations with Latin vocabulary labels directly below them (e.g., "equus", "lectica", "servus")
- Grammar notes and explanations
- Small diagrams showing word relationships (arrows, equals signs)
- Any illustration that has explanatory Latin text immediately adjacent to it

COORDINATE-BASED EXCLUSION ZONES:
{exclusion_text}

ONLY EXTRACT these from the MAIN TEXT AREA ({left_boundary} <= x <= {right_boundary}):
- Large header illustrations (maps, wide scene illustrations at top of page, spanning most of text width)
- Large scene illustrations embedded within Latin prose (showing multiple characters in action)
- Full-width diagrams or maps that are part of the lesson narrative

CRITICAL RULES:
1. If an illustration has a Latin vocabulary word as a label (like "equus", "via", "porta"), it is MARGIN CONTENT - DO NOT extract
2. If an illustration is small and positioned at the edge of the page, it is MARGIN CONTENT - DO NOT extract
3. Only extract illustrations that are clearly WITHIN the main text column, not at the edges
4. When in doubt, DO NOT extract - it's better to miss an illustration than to extract margin vocabulary

Output JSON list with "box_2d" [ymin, xmin, ymax, xmax] normalized 0-1000 and "label" describing the illustration.
Only include illustrations where {left_boundary} <= xmin AND xmax <= {right_boundary}.
Return empty list [] if no valid main-text illustrations are found.
Do NOT include masks."""

    # Use streaming to avoid truncation of large base64 mask responses
    response_stream = client.models.generate_content_stream(
        model="gemini-2.5-flash",
        contents=[image, prompt],
        config={
            "response_mime_type": "application/json",
            "thinking_config": {"thinking_budget": 0}  # Disable for better masks
        }
    )

    # Accumulate all chunks from stream
    chunks = []
    for chunk in response_stream:
        if chunk.text:
            chunks.append(chunk.text)
    text = "".join(chunks)

    # Parse the response
    try:
        detections = json.loads(text)
    except json.JSONDecodeError:
        print(f"Warning: Could not parse Gemini response as JSON", file=sys.stderr)
        print(f"Response: {text[:500]}", file=sys.stderr)
        return []

    if not isinstance(detections, list):
        print(f"Warning: Expected list but got {type(detections)}", file=sys.stderr)
        return []

    results = []
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    for i, item in enumerate(detections):
        if "box_2d" not in item:
            print(f"Warning: Item {i} missing box_2d, skipping", file=sys.stderr)
            continue

        y0, x0, y1, x1 = item["box_2d"]

        # Skip items that are in margin areas
        if x0 < left_boundary:
            print(f"Skipping item {i} in left margin (x0={x0} < {left_boundary})", file=sys.stderr)
            continue
        if x1 > right_boundary:
            print(f"Skipping item {i} in right margin (x1={x1} > {right_boundary})", file=sys.stderr)
            continue

        # Convert normalized coordinates (0-1000) to pixels
        px_x0 = int(x0 * width / 1000)
        px_y0 = int(y0 * height / 1000)
        px_x1 = int(x1 * width / 1000)
        px_y1 = int(y1 * height / 1000)

        # Ensure valid bounds
        px_x0 = max(0, min(px_x0, width - 1))
        px_y0 = max(0, min(px_y0, height - 1))
        px_x1 = max(px_x0 + 1, min(px_x1, width))
        px_y1 = max(px_y0 + 1, min(px_y1, height))

        # Crop original image to bounding box
        cropped = image.crop((px_x0, px_y0, px_x1, px_y1)).convert("RGBA")

        # Decode and apply mask if present
        mask_data = item.get("mask", "")
        if mask_data:
            try:
                # Handle data URL format
                if "base64," in mask_data:
                    mask_data = mask_data.split("base64,")[1]

                mask_bytes = base64.b64decode(mask_data)
                mask_img = Image.open(BytesIO(mask_bytes)).convert("L")

                # Resize mask to match crop dimensions
                mask_img = mask_img.resize(cropped.size, Image.LANCZOS)

                # Binarize at threshold 127
                mask_img = mask_img.point(lambda p: 255 if p > 127 else 0)

                # Apply as alpha channel
                cropped.putalpha(mask_img)
            except Exception as e:
                print(f"Warning: Could not apply mask for item {i}: {e}", file=sys.stderr)
                # Continue without mask - just use cropped rectangle

        # Save the extracted illustration (inline-{index}.png naming)
        inline_index = len(results)
        out_file = output_path / f"inline-{inline_index}.png"
        cropped.save(out_file)

        results.append({
            "index": inline_index,
            "label": item.get("label", ""),
            "file": str(out_file),
            "box": {
                "x": px_x0,
                "y": px_y0,
                "w": px_x1 - px_x0,
                "h": px_y1 - px_y0
            }
        })

    return results


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: extract_illustrations.py <command> <args...>", file=sys.stderr)
        print("\nSimple commands (no AI - Claude provides coordinates):", file=sys.stderr)
        print("  info <image>                           - Get image dimensions", file=sys.stderr)
        print("  crop <image> <output> <x1> <y1> <x2> <y2>  - Crop to pixel coordinates", file=sys.stderr)
        print("  split <image> <output_dir> <split_x>   - Split spread into left/right pages", file=sys.stderr)
        print("\nAI commands (uses Gemini - requires GOOGLE_API_KEY):", file=sys.stderr)
        print("  margin <image> <output> [--side left|right]  - Crop margin strip (Gemini detects)", file=sys.stderr)
        print("  inline <image> <dir> [--exclude-left X] [--exclude-right X]  - Extract inline illustrations", file=sys.stderr)
        sys.exit(1)

    command = sys.argv[1]

    # -------------------------------------------------------------------------
    # Simple commands (no AI)
    # -------------------------------------------------------------------------

    if command == "info":
        if len(sys.argv) != 3:
            print("Usage: extract_illustrations.py info <image>", file=sys.stderr)
            sys.exit(1)
        image_path = sys.argv[2]

        if not Path(image_path).exists():
            print(f"Error: Image not found: {image_path}", file=sys.stderr)
            sys.exit(1)

        result = get_image_info(image_path)
        print(json.dumps(result, indent=2))

    elif command == "crop":
        if len(sys.argv) != 8:
            print("Usage: extract_illustrations.py crop <image> <output> <x1> <y1> <x2> <y2>", file=sys.stderr)
            sys.exit(1)
        image_path = sys.argv[2]
        output_path = sys.argv[3]
        x1, y1, x2, y2 = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7])

        if not Path(image_path).exists():
            print(f"Error: Image not found: {image_path}", file=sys.stderr)
            sys.exit(1)

        result = crop_region(image_path, output_path, x1, y1, x2, y2)
        print(json.dumps(result, indent=2))

    elif command == "split":
        if len(sys.argv) != 5:
            print("Usage: extract_illustrations.py split <image> <output_dir> <split_x>", file=sys.stderr)
            sys.exit(1)
        image_path = sys.argv[2]
        output_dir = sys.argv[3]
        split_x = int(sys.argv[4])

        if not Path(image_path).exists():
            print(f"Error: Image not found: {image_path}", file=sys.stderr)
            sys.exit(1)

        result = split_spread(image_path, output_dir, split_x)
        print(json.dumps(result, indent=2))

    # -------------------------------------------------------------------------
    # AI commands (uses Gemini)
    # -------------------------------------------------------------------------

    elif command == "margin":
        if len(sys.argv) < 4:
            print("Usage: extract_illustrations.py margin <image> <output_path> [--side left|right]", file=sys.stderr)
            print("  --side left   Crop left margin (default)", file=sys.stderr)
            print("  --side right  Crop right margin", file=sys.stderr)
            sys.exit(1)
        image_path = sys.argv[2]
        output_path = sys.argv[3]

        # Parse optional --side argument
        side = "left"
        if len(sys.argv) > 4:
            if sys.argv[4] == "--side" and len(sys.argv) > 5:
                side = sys.argv[5]
                if side not in ["left", "right"]:
                    print(f"Error: --side must be 'left' or 'right', got '{side}'", file=sys.stderr)
                    sys.exit(1)
            elif sys.argv[4] in ["left", "right"]:
                # Allow shorthand: margin img out right
                side = sys.argv[4]

        if not Path(image_path).exists():
            print(f"Error: Image not found: {image_path}", file=sys.stderr)
            sys.exit(1)

        result = crop_margin_strip(image_path, output_path, side=side)
        print(json.dumps({"margin_strip": result}, indent=2))

    elif command == "inline":
        if len(sys.argv) < 4:
            print("Usage: extract_illustrations.py inline <image> <output_dir> [--exclude-left X] [--exclude-right X]", file=sys.stderr)
            print("  --exclude-left X   Exclude left margin (x < X pixels)", file=sys.stderr)
            print("  --exclude-right X  Exclude right margin (x > X pixels)", file=sys.stderr)
            sys.exit(1)
        image_path = sys.argv[2]
        output_dir = sys.argv[3]

        # Parse optional arguments
        exclude_left = None
        exclude_right = None
        i = 4
        while i < len(sys.argv):
            if sys.argv[i] == "--exclude-left" and i + 1 < len(sys.argv):
                exclude_left = int(sys.argv[i + 1])
                i += 2
            elif sys.argv[i] == "--exclude-right" and i + 1 < len(sys.argv):
                exclude_right = int(sys.argv[i + 1])
                i += 2
            else:
                # Legacy support: single number means exclude-left
                try:
                    exclude_left = int(sys.argv[i])
                    i += 1
                except ValueError:
                    print(f"Unknown argument: {sys.argv[i]}", file=sys.stderr)
                    sys.exit(1)

        if not Path(image_path).exists():
            print(f"Error: Image not found: {image_path}", file=sys.stderr)
            sys.exit(1)

        result = extract_inline_illustrations(image_path, output_dir, exclude_left=exclude_left, exclude_right=exclude_right)
        print(json.dumps({"inline_illustrations": result}, indent=2))

    else:
        print(f"Unknown command: {command}", file=sys.stderr)
        print("Use: info, crop, split, margin, or inline", file=sys.stderr)
        sys.exit(1)
