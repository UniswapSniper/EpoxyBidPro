# Phase 3 Progress — AI Bidding Engine

## Completed in this checkpoint

- Added a reusable pricing engine service implementing the roadmap formula for material, labor, overhead, markup, tax, and Good/Better/Best tier outputs.
- Added bid pricing preview API endpoint to provide live pricing, margin, and shopping list data before saving bids.
- Added bidding settings APIs so each business can configure labor rate, markup, overhead, tax, waste factors, mobilization fee, and minimum job price.
- Replaced placeholder AI bidding suggestions with an OpenAI-backed service that falls back to rule-based recommendations when no API key is configured.
- Expanded materials APIs to support seeded epoxy material defaults, supplier price-update reminders, and coating-system-aware filtering.

## Next immediate tasks

1. Persist and version pricing presets by job archetype (garage, commercial bay, showroom).
2. Add historical win/loss weighting to AI request payloads.
3. Build iOS Bid Builder UI wiring for live pricing and AI suggestions panel.
4. Add automated route tests for pricing preview and settings update validation.
