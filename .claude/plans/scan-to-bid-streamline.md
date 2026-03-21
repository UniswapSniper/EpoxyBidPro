# Streamline Scan-to-Bid Flow

## Problem
The 8-step BidBuilder wizard is too many steps when coming from a scan. Users want a fast path: Scan → Pick Coating → Get Price → Save Bid.

## Current State (Already Good)
ScanResultView already has:
- Inline coating picker with real-time pricing
- 3-tier selector (GOOD/BETTER/BEST)
- **"Quick Bid — Save Draft"** one-tap action
- "Customize Bid" → opens full 8-step wizard

## What Needs Improvement

### 1. ScanResultView needs inline pricing displayed BEFORE coating selection
Currently pricing only shows after selecting a coating. Show a "most popular" default.

### 2. BidBuilder from scan still has too many steps
When "Customize Bid" is tapped, user faces: Coating → Prep → Pricing → AI → Line Items → Review (6 steps). Should collapse to 3-4 steps.

### 3. Scanning entry point is buried
"Scan Space" is inside a menu on Pipeline. Needs to be a prominent button.

---

## Implementation Plan

### Phase 1: Prominent Scan Entry in PipelineView
**File: `Features/Pipeline/PipelineView.swift`**

- Add a prominent "Scan & Bid" hero button at the top of the Bids segment (above the workflow command deck)
- Large gradient button with ruler icon: "Scan Garage Floor"
- Tapping opens the scan fullScreenCover (same as existing)
- This makes scanning the #1 visible action for bid creation

### Phase 2: Enhance ScanResultView with Auto-Pricing
**File: `Features/Scan/ScanResultView.swift`**

- Auto-select "Two Coat Flake" as default coating (most common for garages)
- Show pricing immediately on load (no need to pick coating first)
- Make the "Quick Bid" button the primary hero action (bigger, top of actions)
- Add client picker inline (optional, collapsible) — currently Quick Bid creates bid with no client
- Add surface condition quick-pick (4 icons: Excellent/Good/Fair/Poor) inline — defaults to Good
- Rename "Customize Bid" → "Advanced Options" to reduce its visual weight

### Phase 3: Collapse BidBuilder Steps for Scan Flow
**File: `Features/Bids/BidBuilder/BidBuilderView.swift`**
**File: `Features/Bids/BidBuilder/BidBuilderViewModel.swift`**

When `initialMeasurement` is provided (scan flow), use a condensed 4-step wizard:

| Current 8 Steps | Condensed 4 Steps |
|---|---|
| 1. Client | **1. Coating & Prep** (combined) |
| 2. Measurement | _(auto-filled from scan)_ |
| 3. Coating | **1. Coating & Prep** (combined) |
| 4. Prep | **1. Coating & Prep** (combined) |
| 5. Pricing | **2. Pricing** (auto-calculated on enter) |
| 6. AI Insights | **3. Review** (collapsed section) |
| 7. Line Items | **3. Review** (collapsed section) |
| 8. Review | **3. Review + Save** |

Implementation:
- Add `var isQuickMode: Bool` computed from `initialMeasurement != nil`
- Define `quickSteps: [BidBuilderStep] = [.coating, .pricing, .review]` (3 steps)
- When `isQuickMode`, use `quickSteps` array for navigation instead of `allCases`
- Merge prep options INTO the coating step view (show as expandable "Surface Details" section below coating grid)
- On the Review step, show AI insights and line items as expandable disclosure groups
- Auto-trigger `calculatePricing()` when entering pricing step
- Update progress bar to show only the active steps (3 dots instead of 8)
- Client selection available as optional link on Review step ("+ Add Client")

### Phase 4: Combined Coating + Prep Step View
**File: `Features/Bids/BidBuilder/BidBuilderSteps3_4.swift`**

- Create a new `BidBuilderCoatingAndPrepStep` view (or modify existing)
- Shows coating grid at top (existing)
- Below coating grid, add collapsible "Surface Details" section:
  - Surface condition (4-icon picker, default: Good)
  - Prep complexity (3-option segmented, default: Standard)
  - Access difficulty (3-option segmented, default: Normal)
  - Complex layout toggle (default: off)
- This section is collapsed by default with smart defaults pre-applied
- Users who just want to pick coating and move on can skip it entirely

### Phase 5: Enhanced Review Step for Quick Mode
**File: `Features/Bids/BidBuilder/BidBuilderSteps8_Review.swift`**

When `isQuickMode`:
- Show measurement summary card (from scan data)
- Show selected coating + pricing prominently
- Add DisclosureGroup sections for:
  - "AI Insights" — generated on-the-fly, expandable
  - "Line Items" — auto-generated, expandable with edit capability
  - "Client" — optional picker, expandable
  - "Scope Notes" — optional text field, expandable
- "Save Bid" button is prominent at bottom
- All the customization is still accessible, just not forced

---

## Files Changed Summary

| File | Change |
|---|---|
| `Features/Pipeline/PipelineView.swift` | Add prominent "Scan Garage Floor" button |
| `Features/Scan/ScanResultView.swift` | Auto-select default coating, show pricing on load, add inline client picker + surface condition |
| `Features/Bids/BidBuilder/BidBuilderView.swift` | Add quick mode with 3-step navigation, condensed progress bar |
| `Features/Bids/BidBuilder/BidBuilderViewModel.swift` | Add `isQuickMode`, auto-calculate on step entry |
| `Features/Bids/BidBuilder/BidBuilderSteps3_4.swift` | Create combined Coating+Prep step view |
| `Features/Bids/BidBuilder/BidBuilderSteps8_Review.swift` | Enhanced review with disclosure groups for quick mode |

## Execution Order
1. Phase 1 (Pipeline scan button) — quick win, independent
2. Phase 2 (ScanResultView enhancements) — improves Quick Bid path
3. Phase 3 (BidBuilder quick mode) — core architecture change
4. Phase 4 (Combined coating+prep view) — depends on Phase 3
5. Phase 5 (Enhanced review) — depends on Phase 3

## User Flow After Changes

### Fast Path (80% of users):
```
Pipeline → "Scan Garage Floor" → AR Scan → ScanResultView
  → Coating auto-selected (Two Coat Flake)
  → Pricing shown immediately
  → Tap "Quick Bid" → Bid saved as DRAFT ✓
```

### Customize Path (20% of users):
```
Pipeline → "Scan Garage Floor" → AR Scan → ScanResultView
  → Pick different coating
  → Tap "Advanced Options"
  → 3-step wizard: Coating+Prep → Pricing → Review+Save ✓
```

### Full Manual Path (edge case):
```
Pipeline → "+" menu → "New Bid"
  → Full 8-step wizard (unchanged)
```
