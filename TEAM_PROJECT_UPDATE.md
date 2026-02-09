# Project Update: New Direction — Hybrid Stress Detection

**Date:** Feb 8, 2026

## TL;DR

Pure ML stress detection doesn't work with our data size (22 subjects). Published studies with 33 subjects only got 55-64%. So we're pivoting to a **hybrid approach** that combines ML where it works (activity classification) with formulas and rules where ML fails (stress scoring). The good news: most of the code is already done.

---

## Why We're Pivoting

Our original plan was to train an ML model to predict stress levels from wearable data. Here's what happened:

- **Stress regression**: R² = -0.035 (worse than just guessing the average)
- **Binary stress classifier**: F1 = 0.46 (just predicts "not stressed" for everyone)
- **This is normal.** Velmovitsky (2022) had 33 subjects with Apple Watch and only got 55-64% accuracy. Bahameish got F1 = 56% for Stress vs Neutral. Our N=22 is even smaller.

The problem isn't our code — it's that stress is subtle and 22 subjects isn't enough data for ML to learn the pattern.

## The New Architecture: 3-Stage Hybrid Pipeline

Instead of one ML model trying to do everything, we split it into 3 stages that each use the right tool:

```
Apple Watch Data (HR, Steps, Sleep, HRV)
         |
   STAGE 1 (ML) — Activity Classifier
   "Is the user physically active or sitting still?"
   93.6% accuracy, trained on 22 subjects, CoreML model ready
         |
    PHYSICAL ──→ Skip stress detection (exercise ≠ stress)
         |
    COGNITIVE ──→ STAGE 2 (Rules) — Sleep Adjustment
                  "Did they sleep well last night?"
                  Bad sleep → lower the stress threshold (more sensitive)
                  Good sleep → raise it (more resilient)
                        |
                  STAGE 3 (Formulas) — Stress Score
                  DC/AC metrics from heart rate variability
                  Compares to personal baseline
                  Outputs stress score 0-100
                        |
                  Body Battery drains based on score
```

**Why this works better than pure ML:**
- Stage 1 has enough data (22 subjects, 2,449 windows) and the pattern is obvious (movement vs sitting)
- Stage 2 uses simple rules backed by research (Apple 2024 paper) — no training data needed
- Stage 3 uses established formulas from Bauer 2006 (DC/AC) — no training data needed
- Personal baselines adapt to each user over time (no population model needed)

**This is exactly what Tauhidur described in the Jan 21 meeting** before we even knew regression would fail.

---

## What Makes Our Project Different

Most stress detection research (and every other capstone we've seen) does this:

```
Wearable → ML Model → "You're stressed" → [End]
```

Our app does this:

```
Wearable → Activity Filter → Stress Score → Battery Drain → Recovery Suggestion →
Guided Session → HR/HRV Measured → Personal Baseline Updated → [Loop back]
```

**5 things that set us apart:**

1. **Motion-aware filtering** — Most apps think you're stressed when you're jogging (heart rate is high either way). Ours filters physical activity first at 93.6% accuracy, so stress detection only runs when you're still. Bonneval (2025) showed Apple Watch HRV has 93% error during movement — you literally can't skip this step.

2. **Duration-aware battery drain** — Other apps say "stressed" or "not stressed" as a snapshot. Ours tracks *how long* you've been stressed and drains your battery accordingly. 30 min at stress level 7 costs more than 5 min at stress level 7. This is already built into Dhyay's `calculateBatteryDrain()`.

3. **Actionable energy metaphor** — Instead of "your HRV is 28ms" (meaningless to most people), we show "you're at 45% battery." People intuitively understand battery. They know 45% means "be careful" and 15% means "stop and recharge."

4. **Guided recovery with measured validation** — When battery is low, the app suggests specific activities (breathing, walk, meditation, stretch, hydrate). During the session, it tracks your HR and HRV through HealthKit. After the session, it can compare: did your heart rate actually drop? Did HRV improve? This closes the loop between recommendation and measurable outcome.

5. **Personal baseline learning** — The stress threshold adapts to each user. Someone with naturally low HRV won't get constant false alerts. Sleep quality adjusts the threshold daily — bad sleep makes the system more sensitive. Over time, the app learns YOUR normal, not a population average.

**The closed loop (Detect → Quantify → Intervene → Validate → Learn) is what makes this a real digital twin, not just another stress app.**

---

## What the App Looks Like

### Dashboard (what Dhyay already built)

```
┌─────────────────────────────────┐
│  Today                          │
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐  │
│  │ ◉ 75%   Body Battery     │  │
│  │         "Good energy      │  │
│  │          levels"          │  │
│  │         Tap to manage →   │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ LIFESTYLE RECOMMENDATIONS │  │
│  │ 🛏 Prioritize Sleep       │  │
│  │ 🧘 Manage Your Stress     │  │
│  │ 7-DAY FORECAST            │  │
│  │ 📊 Stress: Stable         │  │
│  │ 📈 Activity: Trending up  │  │
│  │ 🔋 Recovery: Moderate     │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ♥ 72 BPM                 │  │
│  │   Heart Rate — Normal     │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌────────────┐ ┌────────────┐  │
│  │ 🚶 Steps   │ │ 🔥 Cals    │  │
│  │   8.2k     │ │   420 kcal │  │
│  └────────────┘ └────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ HRV — Stress Level       │  │
│  │ ██████░░░░ Moderate       │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ Activity History          │  │
│  │ (self-reported entries)   │  │
│  └───────────────────────────┘  │
│                                 │
│  Sleep · Distance · Weekly Bar  │
│                          [＋]   │
└─────────────────────────────────┘
```

### Body Battery Screen (tap the battery card)

```
┌─────────────────────────────────┐
│  Body Battery                   │
├─────────────────────────────────┤
│                                 │
│         ╭─────────╮             │
│        ╱  Human    ╲            │
│       │  figure     │           │
│       │  filled to  │           │
│       │  75% with   │           │
│       │  color      │           │
│        ╲           ╱            │
│         ╰─────────╯             │
│       "Good energy levels.      │
│     Pace yourself throughout    │
│           the day."             │
│                                 │
│  ┌───────────────────────────┐  │
│  │ ACTIVITY SIMULATOR        │  │
│  │ Type: [Cognitive ▼]       │  │
│  │ Duration: ──●──── 60 min  │  │
│  │ Stress:   ────●── 7/10   │  │
│  │ Est. drain: -8%           │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │ RECOVERY ACTIVITIES       │  │
│  │ ┌─────┐┌─────┐┌─────┐    │  │
│  │ │ 🌬  ││ 🚶  ││ 🧠  │    │  │
│  │ │Breathe│Walk ││Medit│    │  │
│  │ │ 5min ││15min││10min│    │  │
│  │ │ +8%  ││+12% ││+10% │    │  │
│  │ └─────┘└─────┘└─────┘    │  │
│  │ ┌─────┐┌─────┐           │  │
│  │ │ 🤸  ││ 💧  │           │  │
│  │ │Stretch│Hydrate│         │  │
│  │ │ 5min ││ 1min │          │  │
│  │ │ +6%  ││ +3%  │          │  │
│  │ └─────┘└─────┘           │  │
│  └───────────────────────────┘  │
│                                 │
│  30-Day Battery History Chart   │
│  ▁▃▅▇▆▄▃▅▇▅▃▂▄▆▇▅▃▁▃▅▇▆▄▃▅  │
│                                 │
└─────────────────────────────────┘
```

### What Changes After Week 3 (Pipeline Wired In)

The screens stay the same — Dhyay's UI doesn't need to change. What changes is **where the data comes from**:

| Feature | TODAY (manual) | AFTER WEEK 3 (automatic) |
|---------|---------------|--------------------------|
| Activity type | User taps [+] and self-reports | Pipeline auto-detects from Steps + HR |
| Stress level | User picks 1-10 on a slider | Pipeline computes 0-100 from DC/AC |
| Battery drain | Triggered when user logs activity | Runs automatically in background |
| HRV stress level | Hardcoded thresholds (HRV>50 = low) | Compared to personal baseline |
| Sleep adjustment | Not connected | Bad sleep = more sensitive threshold |

**Same UI, but now the data is real and automatic instead of self-reported.**

---

## Scope: What We're Executing Now vs Future Ideas

### Executing NOW (Weeks 2-4) — This is the capstone deliverable

- Auto-detect PHYSICAL vs COGNITIVE from Apple Watch (Stage 1)
- Calculate stress score from DC/AC metrics when still (Stage 3)
- Adjust stress sensitivity based on last night's sleep (Stage 2)
- Auto-drain Body Battery based on real stress scores
- Validate with N=10-20 participants (Baseline → Stroop → Walk protocol)
- Recovery activities with HR/HRV tracking (already working)
- Personal baseline that adapts over time (already in pipeline)

### Future Ideas (Phase 3 — NOT required for capstone)

These are ideas that would make the app even better but are **out of scope** for the next 3 weeks. They're documented here so we remember them for the report's "Future Work" section:

- Calendar integration — predict battery cost of scheduled meetings
- Morning briefing — "Battery at 82%, 3 meetings today, you'll end at ~45%"
- Proactive alerts — "Low battery, suggest moving your 3pm meeting"
- Learned personal drain rates — "Coffee shop work costs you less than home office"
- Learned recovery effectiveness — "Meditation works 20% better for you than walking"
- Location-aware context — different baselines for work vs home

**Don't worry about any of these right now just some ideas if we have time.** They're for the paper and future development. The capstone scope is clear: wire the pipeline, validate it works, write the report.

---

## What's Already Built

### Done (Camille — Feb 8)

| File | What It Does | Where |
|------|-------------|-------|
| `StressDetectionPipeline.swift` | Full iOS pipeline — all 3 stages in one file | `digital_twin_app/DigitalTwin/` |
| `ActivityClassifier.mlmodel` | CoreML model (93.6% accuracy, 528KB) | `models/` + `digital_twin_app/DigitalTwin/` |
| `ActivityClassifier_preprocessing.json` | Preprocessing params for the model | `models/` + `digital_twin_app/DigitalTwin/` |
| `export_stage1_model.py` | Script that trained and exported the model | repo root |
| `stage3_stress_formulas.py` | DC/AC formulas in Python (reference + validation) | repo root |
| `stage2_sleep_rules.py` | Sleep threshold rules in Python (reference) | repo root |
| `parse_apple_health.py` | Parses Apple Health export.xml into CSVs | repo root |

### Done (Dhyay — already existed)

| File | What It Does |
|------|-------------|
| `BodyBatteryView.swift` | Full body battery system — drain, recharge, 30-day history |
| `ActivityManager.swift` | Activity logging (Aerobic/Anaerobic/Cognitive) |
| `HealthKitManager.swift` | Reads HR, HRV, Steps, Sleep from Apple Watch |
| `ContentView.swift` | Dashboard with insights and recommendations |

#### The Key Point: about 80% of the app is built. The remaining work is wiring these pieces together.

---

## What Needs to Be Done

### Dhyay — iOS Integration 

The Swift pipeline file (`StressDetectionPipeline.swift`) is ready to use. It doesn't change anything in the app until you connect it. To connect:

```swift
let pipeline = StressDetectionPipeline(healthKitManager: healthKitManager)
let result = await pipeline.runFullPipeline()
// result.stressScore (0-100) → feed into Body Battery drain
// result.activityType (.physical or .cognitive) → log in ActivityManager
```

**3 things to wire up:**

1. **Steps data** (line ~504 in StressDetectionPipeline.swift) — Replace the hardcoded `stepsPerMin` placeholder with real step count from HealthKit for the last 5 minutes

2. **Sleep baseline** (line ~518) — Currently hardcoded to `baselineHours: 7.0`. The app already has `fetchLastNightSleep()` in HealthKitManager (line 342) that gets one night of sleep. Make a version that queries the last 30 days and averages them, then pass that average as the baseline. The 7.0 stays as fallback for new users.

3. **Save baselines** — The stress calculator builds up personal baseline values (`baselineDCValues`, `baselineSDNNValues`) but they reset when the app closes. Save them to UserDefaults so they persist.

Note: I renamed `ActivityType` to `ClassifiedActivityType` in the pipeline file so it doesn't conflict with the existing `ActivityType` in `ActivityManager.swift`.

There's a full integration example in the comments at the bottom of the Swift file.

### Person — DC/AC Validation 

- The Python formulas are in `stage3_stress_formulas.py` — tested and working
- `parse_apple_health.py` can parse any team member's Apple Health export
- Validate DC/AC stress scores on parsed Apple Health data
- Document IBI data quality findings

### Person & Person — Testing & Validation

- Test the full pipeline on a real device once Dhyay wires it up
- Design the validation study protocol: Baseline 5min → Stroop test 5min → Walk 2min
- Recruit N=10-20 participants for Week 4 validation
- Week 4: One stress question per participant to validate against pipeline scores

### Camille — Report & Research (Ongoing)

- Write Q2 report sections: Why regression failed, hybrid architecture, DC/AC results
- Prepare citations and bibliography

### Selina 
- Website development

### Dhyay


---

## How It All Connects (The Closed Loop)

This is what makes our project different from other stress detection apps:

```
DETECT (Stage 1-3)     →  Is the user stressed? Score 0-100
QUANTIFY (Body Battery) →  Battery drains based on stress score
INTERVENE (Recovery)    →  App suggests: breathing, walk, meditation, stretch, hydrate
VALIDATE (Sensors)      →  Watch tracks if HR/HRV actually improve after activity
LEARN (Baseline)        →  Personal baseline updates over time
```

No other capstone project(acutally need to check on this) or published study we've found does this full closed loop. Most just detect stress and stop. We detect, quantify, intervene, and validate — all automatically with zero self-reporting.

---

## Real Deadlines — All Deliverables

We have **4 deliverables** beyond the app itself:

| Deliverable | Due Date | Submit To | Who Submits |
|-------------|----------|-----------|-------------|
| **Report Checkpoint** | **Sat Feb 15** | Gradescope (PDF) | Essie |
| **Code Checkpoint** | **Sat Feb 15** | GitHub repo link | Camille |
| **Website Checkpoint** | **Sat Feb 22** | URL | Selina |
| **Poster Checkpoint** | **Sat Feb 22** | Gradescope | Levy |
| Final Report | Sat Mar 8 | Gradescope | Essie |
| Final Code | Sat Mar 8 | GitHub | Camille |
| Final Website | Sat Mar 8 | URL | Dhyay |
| Final Poster | Sat Mar 8 | Print-ready PDF | Essie |
| Presentation Slides(ignore) | Sat Mar 8 | — | All |
| **CAPSTONE SHOWCASE** | **Thu Mar 13** | In person | All |

---

## Updated Week-by-Week Plan

### This Week: Feb 10-15 — CHECKPOINT 1 (Report + Code)

**Tuesday Feb 10 — Team Meeting**
- [ ] Align on hybrid architecture (everyone reads this doc)
- [ ] Confirm work split below
- [ ] Everyone with an Apple Watch: start wearing it 24/7 including sleep

**By Wednesday Feb 12 — Code cleanup + Catch up**

| Task | Owner |
|------|-------|
| Plan for deliverables |ALL |
| Update README with new file guide + architecture | Camille |
| Clean up notebooks (remove dead code, add markdown headers) | All |
| Review `stage3_stress_formulas.py` + `parse_apple_health.py` | ALL |

**By Friday Feb 14 — Report draft**

| Task | Owner |
|------|-------|
| Abstract — rewrite for hybrid architecture | Camille |
| Introduction — problem statement, literature review  | Camille + Selina |
| Methods — 3-stage hybrid architecture, WISE preprocessing, LOSO validation | Camille |
| Results — Stage 1 (93.6%), why regression failed (R²=-0.035), DC/AC validation | Camille + Levy |
| Discussion — what this means, limitations, honest DC/AC finding (p=0.51) | Essie |
| App section — Body Battery system, digital twin concept, closed loop | Dhyay |
| Formatting, figures, references in LaTeX | Essie |

**Saturday Feb 15 — SUBMIT**
- [ ] Essie: Submit report PDF to Gradescope
- [ ] Camille: Submit GitHub repo link for code checkpoint

### Week 6: Feb 16-22 — CHECKPOINT 2 (Website + Poster)

| Task | Owner | Due |
|------|-------|-----|
| Build project website (GitHub Pages) | Selina | Feb 18 |
| Write website content (project summary, architecture diagram, results) | Camille + Selina | Feb 18 |
| App demo video or screenshots for website | Dhyay + Levy | Feb 20 |
| Design poster layout | Essie | Feb 19 |
| Poster content + figures (pipeline diagram, results table, app screenshots) | Camille | Feb 20 |
| Wire `StressDetectionPipeline.swift` into app (Dhyay's 3 TODOs) | Dhyay | Feb 20 |
| Validate DC/AC on parsed Apple Health data | Levy | Feb 20 |
| **SUBMIT: Website Checkpoint** | **Dhyay** | **Feb 22** |
| **SUBMIT: Poster Checkpoint** | **Essie** | **Feb 22** |

### Week 7: Feb 23 - Mar 1 — Polish Everything

| Task | Owner | Due |
|------|-------|-----|
| App final testing + bug fixes | Dhyay + Levy | Feb 26 |
| Website final polish | Selina | Feb 26 |
| Poster final design | Essie | Feb 27 |
| Report final revisions | Camille + Essie | Feb 28 |
| Presentation slides draft | All | Mar 1 |
| Validation study with N=5-10 participants (if time allows) | All | Mar 1 |

### Week 8: Mar 2-8 — FINAL SUBMISSIONS

| Task | Owner | Due |
|------|-------|-----|
| Final report review | All | Mar 4 |
| Final code cleanup | Camille | Mar 5 |
| Final website updates | Selina | Mar 6 |
| Final poster print-ready | Essie | Mar 6 |
| Practice presentation | All | Mar 7 |
| **SUBMIT: All Final Deliverables** | **All** | **Mar 8** |

### Mar 9-13: SHOWCASE WEEK

| Task | Owner | Due |
|------|-------|-----|
| Practice presentation 2-3 times | All | Mar 10-12 |
| Prepare demo for TAs/mentors | Levy + Dhyay | Mar 12 |
| **CAPSTONE SHOWCASE** | **All** | **Mar 13** |

---

## Data Collection (Start Now!)

Everyone with an Apple Watch should start wearing it **24/7 including sleep**:
- Charge during shower/morning routine (30-45 min is enough)
- No manual input needed — the watch collects everything automatically
- We need 7-14 days of baseline data before the validation study
- The more days we have, the better the personal baseline will be

---

## Notes:

The Python files (`stage3_stress_formulas.py`, `stage2_sleep_rules.py`) are reference implementations — they show the math and can be used for testing, but they don't go into the app. Only the Swift file + mlmodel + json go into Xcode.

