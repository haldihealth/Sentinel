# Handoff to Claude Desktop Coding Agent
## Complete Knowledge Transfer for Sentinel iOS Development

---

## 📋 Quick Start for Coding Agent

### 1. Essential Files to Review (IN ORDER):

**Read these first**:
1. `agent_docs/README.md` - Start here (overview + workflow)
2. `agent_docs/01_MVVM_ARCHITECTURE.md` - **MANDATORY** - Architecture rules
3. `Sentinel_PRD_v1.0_FINAL.md` - Product requirements

**Reference during development**:
4. `agent_docs/06_QUICK_REFERENCE.md` - Code templates
5. `agent_docs/02_IOS_DESIGN_GUIDELINES.md` - Styling rules
6. `agent_docs/05_MEDGEMMA_INTEGRATION.md` - LLM setup

---

## 🎯 Your Mission

Build **Sentinel** - An iOS app for veteran suicide prevention using:
- **MedGemma-4B** (on-device LLM, 4-bit quantized)
- **C-SSRS** screening (deterministic safety floor)
- **Multimodal data** (Sleep, Activity, HRV, Voice, Mood)
- **100% on-device** (no cloud, privacy-first)

**Target**: iPhone 15+, iOS 17+, Swift 5.9+, SwiftUI

**Timeline**: 3 weeks (Kaggle competition)

---

## ⚡ Critical Rules (NON-NEGOTIABLE)

### Architecture
- ✅ **MVVM STRICTLY** - Views → ViewModels → Models (never View → Model)
- ✅ All ViewModels: `@MainActor final class X: ObservableObject`
- ✅ Dependency injection (not singletons in ViewModels)
- ✅ No business logic in Views
- ✅ No SwiftUI in Models

### iOS Design
- ✅ **Semantic fonts ONLY**: `.font(.headline)` NOT `.font(.system(size: 17))`
- ✅ **Semantic colors**: `.foregroundStyle(.primary)` NOT `.foregroundColor(.black)`
- ✅ **8-point grid**: spacing 8, 16, 24, 32
- ✅ Test **light AND dark mode**
- ✅ Accessibility labels on all images/buttons

### Build & Test
- ✅ **Always compile using iPhone 17 simulator**
- ✅ Verify builds succeed before committing

### Quality
- ✅ No force unwrapping (`!`) without guard
- ✅ Error handling via `@Published var errorMessage: String?`
- ✅ All public APIs documented
- ✅ MARK sections for organization
- ✅ No compiler warnings

---

## 📁 Project Structure to Create

```
Sentinel/
├── SentinelApp.swift
├── ContentView.swift
├── Models/
│   ├── CheckIn.swift
│   ├── RiskTier.swift
│   ├── SafetyPlan.swift
│   ├── Baseline.swift
│   ├── HRVMetrics.swift
│   └── UserProfile.swift
├── ViewModels/
│   ├── CheckInViewModel.swift
│   ├── MissionStatusViewModel.swift
│   ├── CrisisViewModel.swift
│   └── SafetyPlanViewModel.swift
├── Views/
│   ├── CheckIn/
│   │   ├── CheckInView.swift
│   │   └── CSSRQuestionView.swift
│   ├── MissionStatus/
│   │   └── MissionStatusView.swift
│   ├── Crisis/
│   │   └── CrisisView.swift
│   └── SafetyPlan/
│       └── SafetyPlanView.swift
├── Services/
│   ├── HealthKitManager.swift
│   ├── MedGemmaEngine.swift
│   └── LocalStorage.swift
└── Resources/
    └── medgemma-4b.gguf (2.2GB - download separately)
```

---

## 🚀 Development Priority (Week 1)

### Day 1-2: Setup + C-SSRS
```swift
// Create these first:
Models/RiskTier.swift           // enum: low, moderate, highMonitoring, crisis
Models/CheckIn.swift            // struct with C-SSRS responses
ViewModels/CheckInViewModel.swift
Views/CheckIn/CheckInView.swift
```

**Key features**:
- C-SSRS 6 questions (Yes/No buttons)
- Q4/Q5 (Intent/Plan) → RED crisis screen
- Q6 (Recent attempt) → ORANGE monitoring (NOT red)
- Professional help follow-up if Q6=Yes

### Day 3-4: Data Collection
```swift
// Add these:
Services/HealthKitManager.swift  // Fetch sleep, activity, HRV
Models/HRVMetrics.swift          // NEW - heart rate variability
Models/Baseline.swift            // 30-day rolling average
```

**Key features**:
- Request HealthKit permissions (sleep, steps, HRV)
- Fetch previous 24 hours data
- Calculate 30-day baseline + z-scores

### Day 5-7: MedGemma Integration
```swift
// Critical files:
Services/MedGemmaEngine.swift
Services/PromptBuilder.swift
```

**Setup**:
1. Add llama.cpp via SPM: `https://github.com/ggerganov/llama.cpp`
2. Download model: `medgemma-1.5-4b-it.Q4_K_M.gguf` (2.2GB)
3. Enable Metal acceleration
4. See `agent_docs/05_MEDGEMMA_INTEGRATION.md` for complete code

---

## 🔑 Key Technical Decisions

### 1. Orange vs Red (CRITICAL)
```swift
// Q6 (recent attempt) does NOT lock app:
enum RiskTier {
    case low
    case moderate  
    case highMonitoring  // ORANGE - Q6, UNLOCKED
    case crisis          // RED - Q4/Q5, LOCKED
}

// Logic:
if q4Intent || q5Plan { return .crisis }      // RED
if q6RecentAttempt { return .highMonitoring } // ORANGE
```

### 2. HRV Integration (NEW)
```swift
// Add to HealthKit request:
HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

// Why: Objective biomarker, drops 3-7 days before symptoms
// Clinical evidence: Kemp 2010, Pyne 2016, Sakaki 2016
```

### 3. No Dashboard (REMOVED)
```swift
// WRONG - Don't create this:
struct DashboardView { }  // ❌ Removed

// RIGHT - Create this instead:
struct MissionStatusView {
    // Traffic light (Green/Yellow/Orange/Red)
    // Streak counter (7/30/90 days)
    // Action buttons (NOT data viz)
}
```

### 4. Crisis Resolution (NEW)
```swift
// After 988 call:
"Are you safe?" 
→ Yes → Safety Mode (not home)
→ 4-hour mandatory check-in
→ If missed → Re-lock + notify battle buddy
```

---

## 📝 Code Templates (Copy These)

### ViewModel Template
```swift
import Foundation
import Combine

@MainActor
final class MyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var data: [Item] = []
    
    private let service: MyService
    
    init(service: MyService = .shared) {
        self.service = service
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            data = try await service.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### View Template
```swift
import SwiftUI

struct MyView: View {
    @StateObject private var viewModel = MyViewModel()
    
    var body: some View {
        contentView
            .task {
                await viewModel.loadData()
            }
    }
    
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            List(viewModel.data) { item in
                Text(item.name)
            }
        }
    }
}
```

---

## 🎨 Sentinel Design System

### Colors (Define in Assets.xcassets)
```swift
Color("SentinelGreen")   // Mission Status - Low risk
Color("SentinelYellow")  // Moderate risk
Color("SentinelOrange")  // High monitoring (Q6)
Color("SentinelRed")     // Crisis
```

### Typography (Use These Exactly)
```swift
.font(.largeTitle)   // 34pt - Screen titles
.font(.title2)       // 22pt - Section headers
.font(.headline)     // 17pt - Important labels
.font(.body)         // 17pt - Primary content
.font(.subheadline)  // 15pt - Secondary content
```

### Spacing
```swift
.padding()              // 16pt default
VStack(spacing: 16)     // Standard
VStack(spacing: 24)     // Large
VStack(spacing: 8)      // Tight
```

---

## ⚠️ Common Mistakes to Avoid

### ❌ DON'T DO THIS:
```swift
// Business logic in View
struct MyView: View {
    var body: some View {
        Button("Submit") {
            let risk = calculateRisk()  // ❌ NO
        }
    }
}

// Hardcoded fonts
Text("Title").font(.system(size: 28))  // ❌ NO

// Hardcoded colors (won't adapt to dark mode)
.foregroundColor(.black)  // ❌ NO

// Force unwrap
let name = user!.name  // ❌ NO
```

### ✅ DO THIS:
```swift
// Business logic in ViewModel
class MyViewModel: ObservableObject {
    func calculateRisk() -> RiskTier { }  // ✅ YES
}

// Semantic fonts
Text("Title").font(.title)  // ✅ YES

// Semantic colors
.foregroundStyle(.primary)  // ✅ YES

// Safe unwrap
guard let name = user?.name else { return }  // ✅ YES
```

---

## 📚 Where to Find Answers

| Question | File |
|----------|------|
| How do I structure code? | `agent_docs/01_MVVM_ARCHITECTURE.md` |
| What font/color to use? | `agent_docs/02_IOS_DESIGN_GUIDELINES.md` |
| @State vs @StateObject? | `agent_docs/03_SWIFTUI_BEST_PRACTICES.md` |
| Where does file go? | `agent_docs/04_PROJECT_STRUCTURE.md` |
| How to use MedGemma? | `agent_docs/05_MEDGEMMA_INTEGRATION.md` |
| Show me example code | `agent_docs/06_QUICK_REFERENCE.md` |
| What features to build? | `Sentinel_PRD_v1.0_FINAL.md` |

---

## ✅ Quality Checklist (Before Every Commit)

```markdown
### Pre-Commit Checklist

#### Architecture
- [ ] Follows MVVM (no business logic in Views)
- [ ] ViewModel is @MainActor ObservableObject
- [ ] Dependencies injected (not hardcoded)

#### UI/UX  
- [ ] Semantic fonts (.font(.headline))
- [ ] Semantic colors (.foregroundStyle(.primary))
- [ ] 8-point spacing grid
- [ ] Tested light AND dark mode
- [ ] Accessibility labels added

#### Code Quality
- [ ] MARK sections organized
- [ ] No force unwrapping
- [ ] Error handling via @Published
- [ ] No compiler warnings
```

---

## 🎯 Success Criteria

### Minimum Viable Demo (3 weeks):
- ✅ C-SSRS daily check-in (6 questions)
- ✅ Orange/Red crisis logic working
- ✅ HealthKit integration (sleep, activity, HRV)
- ✅ MedGemma-4B on-device inference
- ✅ Mission Status screen (traffic light)
- ✅ Crisis screen (988 integration)
- ✅ Safety Plan (Stanley-Brown protocol)

### Bonus (if time):
- ✅ Streak gamification
- ✅ Immediate actionable tips
- ✅ Battle Buddy SMS prompts
- ✅ Liquid Glass effects

---

## 🚨 Critical Reminders

1. **Read `agent_docs/01_MVVM_ARCHITECTURE.md` FIRST**
2. **Use semantic fonts/colors** (not hardcoded)
3. **Test light AND dark mode** (every screen)
4. **Q6 = Orange (not Red)** - This is critical for UX
5. **Load MedGemma on app launch** (background thread)
6. **No feature bloat** - Focus on P0 features only

---

## 📞 Getting Started Commands

```bash
# 1. Create new Xcode project
# File → New → Project → iOS → App
# Name: Sentinel
# Interface: SwiftUI
# Language: Swift
# Minimum: iOS 17.0

# 2. Add llama.cpp
# File → Add Package Dependencies
# URL: https://github.com/ggerganov/llama.cpp
# Branch: master

# 3. Download MedGemma model (separately)
# Place in Resources/medgemma-4b.gguf

# 4. Start coding following MVVM architecture!
```

---

## 💡 Pro Tips

1. **Start simple**: Get C-SSRS working first, then add complexity
2. **Test early**: Run on real device (iPhone 15+) by Day 3
3. **Commit often**: Small commits with clear messages
4. **Reference docs**: When stuck, check `agent_docs/06_QUICK_REFERENCE.md`
5. **Profile performance**: Use Instruments to check memory/battery

---

## 🎉 You're Ready!

**All knowledge from the planning chat is now in these files:**
- ✅ PRD with all decisions
- ✅ Complete agent documentation (7 files)
- ✅ Code templates
- ✅ Architecture rules
- ✅ Design guidelines

**Start with**: `agent_docs/README.md` → `01_MVVM_ARCHITECTURE.md` → Code!

**Good luck building Sentinel! 🚀**

---

*Last updated: January 29, 2026*
*Planning chat ID: [This conversation]*
