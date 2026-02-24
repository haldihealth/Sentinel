# MVVM Architecture Guide for Sentinel
## Strict Enforcement - All Code Must Follow This Pattern

---

## Core MVVM Principles

**MVVM** = Model-View-ViewModel

```
┌──────────┐         ┌──────────────┐         ┌───────────┐
│   View   │ ◄───────│  ViewModel   │ ◄───────│   Model   │
│ (SwiftUI)│         │ (Observable) │         │  (Data)   │
└──────────┘         └──────────────┘         └───────────┘
     │                      │                       │
  User Actions        State Management        Business Logic
  Bindings            Transforms Data         Data Persistence
  UI Only             Validation              Calculations
```

**Golden Rule**: Views NEVER access Models directly. All communication through ViewModels.

---

## Model Layer

**Location**: `Models/`

**Purpose**: Pure data structures and business logic

**Rules**:
- ✅ Structs/Classes with Codable, Identifiable
- ✅ Business validation logic
- ✅ NO SwiftUI imports
- ✅ NO @Published, @State, or UI-related code

```swift
// Models/CheckIn.swift
import Foundation

struct CheckIn: Identifiable, Codable {
    let id: UUID
    let date: Date
    let cssrResponses: [Bool]
    let moodScore: Int
    let sleepData: SleepMetrics?
    let hrvData: HRVMetrics?
    
    // Business logic in Model
    var riskTier: RiskTier {
        if cssrResponses[3] || cssrResponses[4] { return .crisis }
        if cssrResponses[5] { return .highMonitoring }
        if cssrResponses[1] { return .moderate }
        return .low
    }
}

enum RiskTier: Int, Codable, Comparable {
    case low = 0
    case moderate = 1  
    case highMonitoring = 2
    case crisis = 3
}
```

---

## ViewModel Layer

**Location**: `ViewModels/`

**Purpose**: Presentation logic, state management, coordination

**Rules**:
- ✅ Conforms to `ObservableObject`
- ✅ Uses `@Published` for state Views observe
- ✅ Handles async operations
- ✅ Coordinates Services
- ✅ NO SwiftUI views (Button, Text, etc.)
- ✅ All marked `@MainActor` for thread safety

```swift
// ViewModels/CheckInViewModel.swift
import Foundation
import Combine

@MainActor
final class CheckInViewModel: ObservableObject {
    // MARK: - Published State
    @Published var cssrResponses: [Bool] = Array(repeating: false, count: 6)
    @Published var currentQuestion: Int = 0
    @Published var moodScore: Int = 5
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showCrisisAlert: Bool = false
    
    // MARK: - Dependencies
    private let healthKitManager: HealthKitManager
    private let medgemmaEngine: MedGemmaEngine
    private let storage: LocalStorage
    
    init(
        healthKitManager: HealthKitManager = .shared,
        medgemmaEngine: MedGemmaEngine = .shared,
        storage: LocalStorage = .shared
    ) {
        self.healthKitManager = healthKitManager
        self.medgemmaEngine = medgemmaEngine
        self.storage = storage
    }
    
    // MARK: - User Actions
    func answerQuestion(_ questionIndex: Int, answer: Bool) {
        cssrResponses[questionIndex] = answer
        
        if isCrisisResponse() {
            showCrisisAlert = true
        } else if currentQuestion < 5 {
            currentQuestion += 1
        }
    }
    
    func submitCheckIn() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let sleep = try await healthKitManager.fetchSleep()
            let hrv = try await healthKitManager.fetchHRV()
            
            let checkIn = CheckIn(
                id: UUID(),
                date: Date(),
                cssrResponses: cssrResponses,
                moodScore: moodScore,
                sleepData: sleep,
                hrvData: hrv
            )
            
            try await storage.save(checkIn)
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Private Helpers
    private func isCrisisResponse() -> Bool {
        cssrResponses[3] || cssrResponses[4]
    }
}
```

---

## View Layer

**Location**: `Views/`

**Purpose**: UI presentation and user interactions

**Rules**:
- ✅ SwiftUI views only
- ✅ Observe ViewModel via `@StateObject` or `@ObservedObject`
- ✅ NO business logic
- ✅ NO direct Model access
- ✅ Use `.task` or `.onAppear` for lifecycle
- ✅ Local UI state uses `@State`

```swift
// Views/CheckInView.swift
import SwiftUI

struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            headerView
            questionView
            answerButtons
            submitButton
        }
        .padding()
        .alert("Crisis Detected", isPresented: $viewModel.showCrisisAlert) {
            Button("Call 988", role: .destructive) {
                // Navigate to crisis view
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
    
    private var headerView: some View {
        Text("Daily Check-In")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    private var questionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(viewModel.currentQuestion + 1) of 6")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(cssrQuestions[viewModel.currentQuestion])
                .font(.title3)
        }
    }
    
    private var answerButtons: some View {
        HStack(spacing: 16) {
            Button("No") {
                viewModel.answerQuestion(viewModel.currentQuestion, answer: false)
            }
            .buttonStyle(.bordered)
            
            Button("Yes") {
                viewModel.answerQuestion(viewModel.currentQuestion, answer: true)
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var submitButton: some View {
        Button("Submit") {
            Task {
                await viewModel.submitCheckIn()
            }
        }
        .disabled(viewModel.isLoading)
    }
    
    private let cssrQuestions = [
        "Have you wished you were dead?",
        "Have you had thoughts of killing yourself?",
        // ... rest of questions
    ]
}
```

---

## Service Layer

**Location**: `Services/`

**Purpose**: External integrations

**Rules**:
- ✅ Called by ViewModels ONLY
- ✅ Return Models
- ✅ Use `actor` for thread safety when needed
- ✅ Handle errors properly

```swift
// Services/HealthKitManager.swift
import HealthKit

actor HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    func fetchSleep() async throws -> SleepMetrics {
        // Implementation
    }
    
    func fetchHRV() async throws -> HRVMetrics {
        // Implementation
    }
}
```

---

## File Structure

```
Sentinel/
├── Models/
│   ├── CheckIn.swift
│   ├── RiskTier.swift
│   ├── SafetyPlan.swift
│   └── Baseline.swift
├── ViewModels/
│   ├── CheckInViewModel.swift
│   ├── MissionStatusViewModel.swift
│   └── CrisisViewModel.swift
├── Views/
│   ├── CheckIn/
│   │   ├── CheckInView.swift
│   │   └── CSSRQuestionView.swift
│   ├── MissionStatus/
│   │   └── MissionStatusView.swift
│   └── Crisis/
│       └── CrisisView.swift
└── Services/
    ├── HealthKitManager.swift
    ├── MedGemmaEngine.swift
    └── LocalStorage.swift
```

---

## Common Mistakes to Avoid

### ❌ BAD: Business Logic in View
```swift
struct CheckInView: View {
    var body: some View {
        Button("Submit") {
            let risk = calculateRisk() // ❌ NO
        }
    }
}
```

### ✅ GOOD: Business Logic in ViewModel
```swift
class CheckInViewModel: ObservableObject {
    func calculateRisk() -> RiskTier {
        // ✅ YES
    }
}
```

### ❌ BAD: View Accessing Model Directly
```swift
struct ListView: View {
    @State var items = LocalStorage.shared.fetch() // ❌ NO
}
```

### ✅ GOOD: View Through ViewModel
```swift
struct ListView: View {
    @StateObject var viewModel = ListViewModel()
}
```

---

## Testing

```swift
@MainActor
class CheckInViewModelTests: XCTestCase {
    func testCrisisDetection() {
        let vm = CheckInViewModel()
        vm.answerQuestion(3, answer: true)
        XCTAssertTrue(vm.showCrisisAlert)
    }
}
```
