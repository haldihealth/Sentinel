# Project Structure & Coding Standards
## File Organization and Swift Style Guide

---

## Project Structure

```
Sentinel/
├── SentinelApp.swift                 # App entry point
├── ContentView.swift                 # Root view coordinator
│
├── Models/                           # Pure data structures
│   ├── Domain/
│   │   ├── CheckIn.swift
│   │   ├── RiskTier.swift
│   │   ├── SafetyPlan.swift
│   │   ├── Baseline.swift
│   │   └── UserProfile.swift
│   ├── HealthData/
│   │   ├── SleepMetrics.swift
│   │   ├── HRVMetrics.swift
│   │   ├── ActivityMetrics.swift
│   │   └── VoiceFeatures.swift
│   └── Responses/
│       └── MedGemmaResponse.swift
│
├── ViewModels/                       # Presentation logic
│   ├── CheckInViewModel.swift
│   ├── MissionStatusViewModel.swift
│   ├── CrisisViewModel.swift
│   ├── SafetyPlanViewModel.swift
│   └── OnboardingViewModel.swift
│
├── Views/                            # SwiftUI views
│   ├── CheckIn/
│   │   ├── CheckInView.swift
│   │   ├── CSSRQuestionView.swift
│   │   ├── MoodScaleView.swift
│   │   └── VoiceRecordingView.swift
│   ├── MissionStatus/
│   │   ├── MissionStatusView.swift
│   │   ├── StatusIndicatorView.swift
│   │   └── StreakView.swift
│   ├── Crisis/
│   │   ├── CrisisView.swift
│   │   ├── CrisisResolutionView.swift
│   │   └── PatternDetectionView.swift
│   ├── SafetyPlan/
│   │   ├── SafetyPlanView.swift
│   │   ├── SafetyPlanEditorView.swift
│   │   └── BreathingExerciseView.swift
│   ├── Onboarding/
│   │   └── OnboardingFlow.swift
│   └── Components/                   # Reusable UI components
│       ├── CrisisButton.swift
│       ├── StatusCard.swift
│       └── ActionButton.swift
│
├── Services/                         # External integrations
│   ├── HealthKit/
│   │   ├── HealthKitManager.swift
│   │   └── HealthKitPermissions.swift
│   ├── Storage/
│   │   ├── LocalStorage.swift
│   │   └── SecureStorage.swift
│   ├── AI/
│   │   ├── MedGemmaEngine.swift
│   │   └── PromptBuilder.swift
│   └── Audio/
│       ├── AudioRecorder.swift
│       └── AcousticFeatureExtractor.swift
│
├── Managers/                         # State/business logic coordinators
│   ├── AppStateManager.swift        # Global app state
│   ├── RiskAssessmentManager.swift  # Risk calculation
│   ├── BaselineManager.swift        # Baseline calculations
│   └── NotificationManager.swift    # Local notifications
│
├── Utilities/                        # Helpers
│   ├── Extensions/
│   │   ├── Date+Extensions.swift
│   │   ├── Color+Extensions.swift
│   │   └── View+Extensions.swift
│   ├── Constants/
│   │   ├── AppConstants.swift
│   │   └── CSSRQuestions.swift
│   └── Helpers/
│       └── ValidationHelpers.swift
│
├── Resources/                        # Assets
│   ├── Assets.xcassets/
│   │   ├── Colors/
│   │   └── Images/
│   ├── medgemma-4b.gguf            # 2.2GB model
│   └── Info.plist
│
└── Tests/
    ├── ViewModelTests/
    ├── ServiceTests/
    └── UITests/
```

---

## Naming Conventions

### Files
```
✅ CheckInViewModel.swift       # PascalCase, descriptive
✅ HealthKitManager.swift       # Role + Manager
✅ CrisisView.swift             # Feature + View

❌ checkin.swift                # lowercase
❌ VM.swift                     # Too short
❌ MyView.swift                 # Generic
```

### Classes/Structs
```swift
// PascalCase
class CheckInViewModel: ObservableObject { }
struct CheckIn: Identifiable { }
enum RiskTier: Int { }
protocol StorageService { }
```

### Properties/Variables
```swift
// camelCase
let userName: String
var isLoading: Bool
private var checkInHistory: [CheckIn]

// Bool prefixes
var isEnabled: Bool     // ✅ State
var hasData: Bool       // ✅ Possession
var shouldRefresh: Bool // ✅ Intention
```

### Functions
```swift
// camelCase, verb-based
func fetchData() async throws
func calculateBaseline() -> Baseline
func validate(input: String) -> Bool
func handleError(_ error: Error)
```

### Constants
```swift
// PascalCase for types, camelCase for instances
enum AppConstants {
    static let minimumSleepHours: Double = 4.0
    static let maxCSSRQuestions: Int = 6
}

// Or:
let defaultSpacing: CGFloat = 16
let primaryColor = Color.blue
```

---

## Code Style

### Spacing & Indentation

```swift
// 4 spaces (NOT tabs)
class MyClass {
    func myMethod() {
        if condition {
            doSomething()
        }
    }
}

// Blank lines between sections
class CheckInViewModel: ObservableObject {
    // MARK: - Properties
    @Published var data: String
    
    // MARK: - Initialization
    init() {
        // ...
    }
    
    // MARK: - Public Methods
    func submit() {
        // ...
    }
    
    // MARK: - Private Methods
    private func validate() {
        // ...
    }
}
```

### Braces

```swift
// Opening brace on same line
func myFunction() {
    if condition {
        doSomething()
    } else {
        doSomethingElse()
    }
}

// Exception: Closures
items.map { item in
    item.name
}
```

### Optionals

```swift
// Use guard for early returns
func process(data: String?) {
    guard let data = data else { return }
    // Use data safely
}

// Use if-let for single values
if let value = optionalValue {
    print(value)
}

// Use optional chaining
user?.profile?.name

// Avoid force unwrapping (!)
let name = user!.name  // ❌ Dangerous
```

### Error Handling

```swift
// Specific errors preferred
enum CheckInError: LocalizedError {
    case noHealthKitData
    case invalidResponse
    case storageFailure
    
    var errorDescription: String? {
        switch self {
        case .noHealthKitData:
            return "Unable to fetch health data"
        case .invalidResponse:
            return "Invalid check-in response"
        case .storageFailure:
            return "Failed to save data"
        }
    }
}

// Usage
func submit() async throws {
    guard let data = healthKit.data else {
        throw CheckInError.noHealthKitData
    }
    // ...
}
```

---

## Documentation

### Document Public APIs

```swift
/// Manages daily check-in workflow and risk assessment
///
/// This ViewModel coordinates C-SSRS questions, health data fetching,
/// and MedGemma analysis to determine veteran risk level.
@MainActor
final class CheckInViewModel: ObservableObject {
    
    /// Current question index (0-5)
    @Published var currentQuestion: Int = 0
    
    /// Submits completed check-in and triggers risk assessment
    /// - Throws: `CheckInError` if validation or storage fails
    func submitCheckIn() async throws {
        // Implementation
    }
    
    // Private methods don't need docs (implementation details)
    private func validate() -> Bool {
        // ...
    }
}
```

### Use MARK for Organization

```swift
class CheckInViewModel: ObservableObject {
    // MARK: - Properties
    @Published var data: String
    
    // MARK: - Published State
    @Published var isLoading: Bool
    
    // MARK: - Dependencies
    private let storage: LocalStorage
    
    // MARK: - Initialization
    init(storage: LocalStorage) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    func submit() { }
    
    // MARK: - Private Methods
    private func validate() { }
}
```

---

## MARK Sections (Standard Order)

```swift
class MyClass {
    // MARK: - Types (nested enums, structs)
    
    // MARK: - Properties
    
    // MARK: - Published State (for ViewModels)
    
    // MARK: - Dependencies
    
    // MARK: - Computed Properties
    
    // MARK: - Initialization
    
    // MARK: - Lifecycle (for Views: body, onAppear, etc.)
    
    // MARK: - Public Methods
    
    // MARK: - Actions (for ViewModels: user-triggered methods)
    
    // MARK: - Private Methods
    
    // MARK: - Helpers
}
```

---

## SwiftLint Rules (Recommended)

```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace  # Allow trailing spaces
  
opt_in_rules:
  - empty_count
  - explicit_init
  - force_unwrapping
  - implicitly_unwrapped_optional
  
line_length:
  warning: 120
  error: 150
  
function_body_length:
  warning: 50
  error: 100
  
type_body_length:
  warning: 300
  error: 500
  
identifier_name:
  min_length: 2
  max_length: 50
```

---

## Git Commit Messages

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructure
- `test`: Tests
- `chore`: Maintenance

### Examples

```
feat(check-in): add HRV data collection

- Integrate HealthKit HRV queries
- Calculate 30-day HRV baseline
- Add HRV deviation detection

Closes #23

---

fix(crisis): prevent duplicate 988 calls

Fixed bug where crisis button could be tapped multiple times,
causing multiple phone dialers to open.

---

refactor(viewmodels): extract common base class

Created BaseViewModel to reduce code duplication across
CheckInViewModel and MissionStatusViewModel.
```

---

## Code Review Checklist

### Before Submitting

- [ ] Follows MVVM architecture
- [ ] No business logic in Views
- [ ] ViewModels use `@MainActor`
- [ ] All async functions properly handled
- [ ] Error handling in place
- [ ] No force unwraps (`!`)
- [ ] Follows naming conventions
- [ ] MARK sections organized
- [ ] Public APIs documented
- [ ] No compiler warnings
- [ ] Tested on device (not just simulator)
- [ ] Light and dark mode tested
- [ ] Accessibility labels added

---

## Performance Guidelines

### Memory Management

```swift
// Use [weak self] in closures to avoid retain cycles
viewModel.fetchData { [weak self] result in
    self?.handle(result)
}

// Or structured concurrency (preferred)
Task {
    await viewModel.fetchData()
}
```

### Avoid Expensive Operations

```swift
// ❌ BAD: Heavy work in View body
struct MyView: View {
    var body: some View {
        let processed = items.map { expensiveTransform($0) }
        List(processed) { item in
            Text(item)
        }
    }
}

// ✅ GOOD: Computed property or ViewModel
struct MyView: View {
    @StateObject var viewModel: MyViewModel
    
    var body: some View {
        List(viewModel.processedItems) { item in
            Text(item)
        }
    }
}
```

---

## Testing Naming

```swift
// Pattern: test_<method>_<condition>_<expectedResult>

func test_submitCheckIn_withValidData_succeeds() async {
    // Arrange
    let viewModel = CheckInViewModel()
    
    // Act
    await viewModel.submitCheckIn()
    
    // Assert
    XCTAssertTrue(viewModel.isComplete)
}

func test_submitCheckIn_withMissingData_throwsError() async {
    // ...
}
```

---

## Quick Reference

### File Templates

**ViewModel Template**:
```swift
import Foundation
import Combine

@MainActor
final class MyViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let service: MyService
    
    // MARK: - Initialization
    init(service: MyService = .shared) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load data
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**View Template**:
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
        VStack {
            // Content
        }
    }
}

#Preview {
    MyView()
}
```

---

## Summary

✅ Follow MVVM strictly  
✅ Use MARK sections for organization  
✅ Document public APIs  
✅ camelCase for properties/methods  
✅ PascalCase for types  
✅ 4 spaces, no tabs  
✅ Guard for early returns  
✅ Avoid force unwrapping  
✅ Test light/dark modes  
✅ Add accessibility labels
