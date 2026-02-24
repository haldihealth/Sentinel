# Quick Reference Guide
## Common Patterns & Code Snippets for Sentinel

---

## ViewModel Template

```swift
import Foundation
import Combine

@MainActor
final class MyViewModel: ObservableObject {
    // MARK: - Published State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var data: [Item] = []
    
    // MARK: - Dependencies
    private let service: MyService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(service: MyService = .shared) {
        self.service = service
    }
    
    // MARK: - Public Methods
    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            data = try await service.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Actions
    func handleAction() {
        // User-triggered action
    }
    
    // MARK: - Private Methods
    private func validate() -> Bool {
        // Validation logic
        return true
    }
}
```

---

## View Template

```swift
import SwiftUI

struct MyView: View {
    @StateObject private var viewModel = MyViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        contentView
            .navigationTitle("Title")
            .task {
                await viewModel.loadData()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }
    
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.data.isEmpty {
            emptyStateView
        } else {
            listView
        }
    }
    
    private var listView: some View {
        List(viewModel.data) { item in
            ItemRow(item: item)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No data yet")
                .font(.title3)
        }
    }
}

#Preview {
    MyView()
}
```

---

## Service Template

```swift
import Foundation

actor MyService {
    static let shared = MyService()
    
    private let baseURL = "https://api.example.com"
    
    func fetch() async throws -> [Item] {
        // Implementation
        []
    }
    
    func save(_ item: Item) async throws {
        // Implementation
    }
}
```

---

## Common Patterns

### Loading State

```swift
.overlay {
    if viewModel.isLoading {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Analyzing...")
                    .font(.headline)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }
}
```

### Empty State

```swift
private var emptyState: some View {
    ContentUnavailableView(
        "No Check-Ins",
        systemImage: "checkmark.circle",
        description: Text("Complete your first daily check-in to get started")
    )
}
```

### Error Handling

```swift
// In ViewModel
@Published var errorMessage: String?

func performAction() async {
    do {
        try await riskyOperation()
    } catch {
        errorMessage = error.localizedDescription
    }
}

// In View
.alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
    Button("OK") {
        viewModel.errorMessage = nil
    }
} message: {
    Text(viewModel.errorMessage ?? "Unknown error")
}
```

### Pull to Refresh

```swift
List(items) { item in
    ItemRow(item: item)
}
.refreshable {
    await viewModel.refresh()
}
```

### Search

```swift
struct MyView: View {
    @State private var searchText = ""
    
    var filteredItems: [Item] {
        if searchText.isEmpty {
            return viewModel.items
        }
        return viewModel.items.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        List(filteredItems) { item in
            ItemRow(item: item)
        }
        .searchable(text: $searchText)
    }
}
```

---

## Sentinel-Specific Components

### Traffic Light Status Indicator

```swift
struct StatusIndicator: View {
    let tier: RiskTier
    
    var body: some View {
        ZStack {
            Circle()
                .fill(tier.color)
                .frame(width: 80, height: 80)
                .shadow(radius: 8)
            
            Image(systemName: "shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
        }
    }
}

extension RiskTier {
    var color: Color {
        switch self {
        case .low: return .green
        case .moderate: return .yellow
        case .highMonitoring: return .orange
        case .crisis: return .red
        }
    }
}
```

### Crisis Button

```swift
struct CrisisButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label("988 Veterans Crisis Line", systemImage: "phone.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .cornerRadius(12)
        }
        .shadow(color: .red.opacity(0.3), radius: 8)
    }
}
```

### Streak Counter

```swift
struct StreakView: View {
    let days: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            
            Text("\(days) day streak")
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange.opacity(0.1))
        .cornerRadius(20)
    }
}
```

### CSSR Question Card

```swift
struct CSSRQuestionCard: View {
    let questionNumber: Int
    let question: String
    let onAnswer: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Question \(questionNumber) of 6")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(question)
                .font(.title3)
            
            HStack(spacing: 16) {
                Button("No") {
                    onAnswer(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Yes") {
                    onAnswer(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}
```

### Breathing Exercise Timer

```swift
struct BreathingExerciseView: View {
    @State private var phase: BreathPhase = .inhale
    @State private var countdown: Int = 4
    @State private var isRunning = false
    
    enum BreathPhase {
        case inhale, hold, exhale
        
        var instruction: String {
            switch self {
            case .inhale: return "Breathe In"
            case .hold: return "Hold"
            case .exhale: return "Breathe Out"
            }
        }
        
        var duration: Int {
            switch self {
            case .inhale: return 4
            case .hold: return 7
            case .exhale: return 8
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Text(phase.instruction)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("\(countdown)")
                .font(.system(size: 80, weight: .thin))
                .monospacedDigit()
            
            Button(isRunning ? "Pause" : "Start") {
                isRunning.toggle()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .task(id: isRunning) {
            if isRunning {
                await runTimer()
            }
        }
    }
    
    private func runTimer() async {
        countdown = phase.duration
        
        while countdown > 0 {
            try? await Task.sleep(for: .seconds(1))
            countdown -= 1
        }
        
        // Next phase
        phase = nextPhase()
        if isRunning {
            await runTimer()
        }
    }
    
    private func nextPhase() -> BreathPhase {
        switch phase {
        case .inhale: return .hold
        case .hold: return .exhale
        case .exhale: return .inhale
        }
    }
}
```

---

## HealthKit Patterns

### Request Permissions

```swift
import HealthKit

actor HealthKitManager {
    func requestAuthorization() async throws {
        let healthStore = HKHealthStore()
        
        let typesToRead: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        ]
        
        try await healthStore.requestAuthorization(
            toShare: [],
            read: typesToRead
        )
    }
}
```

### Fetch Sleep Data

```swift
func fetchSleep() async throws -> SleepMetrics {
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    let predicate = HKQuery.predicateForSamples(
        withStart: Calendar.current.startOfDay(for: Date()),
        end: Date()
    )
    
    let samples = try await withCheckedThrowingContinuation { continuation in
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
        }
        HKHealthStore().execute(query)
    }
    
    let duration = calculateDuration(from: samples)
    return SleepMetrics(duration: duration, date: Date())
}
```

---

## Testing Helpers

### Mock Data

```swift
extension CheckIn {
    static var mock: CheckIn {
        CheckIn(
            id: UUID(),
            date: Date(),
            cssrResponses: [false, false, false, false, false, false],
            moodScore: 7,
            sleepData: .mock,
            hrvData: .mock
        )
    }
}

extension UserProfile {
    static var mock: UserProfile {
        UserProfile(
            id: UUID(),
            age: 32,
            gender: "Male",
            diagnoses: ["PTSD", "Depression"]
        )
    }
}
```

### Mock Services

```swift
class MockHealthKitManager: HealthKitManager {
    var mockSleep: SleepMetrics?
    var mockHRV: HRVMetrics?
    
    override func fetchSleep() async throws -> SleepMetrics {
        if let mock = mockSleep {
            return mock
        }
        throw NSError(domain: "test", code: 0)
    }
    
    override func fetchHRV() async throws -> HRVMetrics {
        mockHRV ?? HRVMetrics(sdnn: 65, date: Date(), sampleCount: 10)
    }
}
```

---

## Animation Helpers

### Smooth Transitions

```swift
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    isExpanded.toggle()
}
```

### Fade In/Out

```swift
Text("Message")
    .transition(.opacity)
```

### Slide and Fade

```swift
Text("Message")
    .transition(
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    )
```

---

## Extensions

### Date Formatting

```swift
extension Date {
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
```

### Color Extensions

```swift
extension Color {
    static let sentinelGreen = Color("SentinelGreen")
    static let sentinelYellow = Color("SentinelYellow")
    static let sentinelOrange = Color("SentinelOrange")
    static let sentinelRed = Color("SentinelRed")
}
```

### View Extensions

```swift
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}
```

---

## Debugging

### Print Statements

```swift
// Development only
#if DEBUG
print("Debug: \(value)")
#endif
```

### View Debugging

```swift
struct MyView: View {
    var body: some View {
        Text("Hello")
            .onAppear {
                print("View appeared")
            }
            .onDisappear {
                print("View disappeared")
            }
    }
}
```

### Memory Leaks

```swift
// Use Instruments → Leaks to detect
// Common cause: retain cycles in closures
Task { [weak self] in
    await self?.loadData()
}
```

---

## Checklist Template

```markdown
## Feature Checklist: [Feature Name]

### Implementation
- [ ] Model created
- [ ] ViewModel created
- [ ] View created
- [ ] Services integrated
- [ ] Error handling added

### UI/UX
- [ ] Follows iOS HIG
- [ ] Light mode tested
- [ ] Dark mode tested
- [ ] Accessibility labels added
- [ ] Dynamic Type supported

### Testing
- [ ] Unit tests written
- [ ] UI tests written
- [ ] Tested on real device
- [ ] Edge cases handled

### Code Quality
- [ ] Follows MVVM
- [ ] MARK sections added
- [ ] Documentation added
- [ ] SwiftLint warnings fixed
- [ ] Code reviewed
```
