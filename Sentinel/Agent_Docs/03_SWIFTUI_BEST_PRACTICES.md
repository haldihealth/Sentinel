# SwiftUI Best Practices for Sentinel
## Modern iOS Development Standards (iOS 17+)

---

## Property Wrappers - When to Use What

### @State
**Use for**: Local, view-owned state

```swift
struct CheckInView: View {
    @State private var isExpanded = false  // ✅ UI-only state
    @State private var showAlert = false   // ✅ Local boolean
    
    var body: some View {
        Button("Toggle") {
            isExpanded.toggle()
        }
    }
}
```

**Rules**:
- ✅ Mark as `private` (not shared outside view)
- ✅ Use for UI animations, toggles, local state
- ❌ NOT for business data (use ViewModel instead)

---

### @StateObject
**Use for**: Creating and owning an ObservableObject

```swift
struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()  // ✅ View owns it
    
    var body: some View {
        // View survives across redraws
    }
}
```

**Rules**:
- ✅ Use when THIS view creates the ViewModel
- ✅ ViewModel persists across view updates
- ❌ NOT when ViewModel is passed from parent

---

### @ObservedObject
**Use for**: Observing an ObservableObject passed from parent

```swift
struct CheckInView: View {
    @ObservedObject var viewModel: CheckInViewModel  // ✅ Passed from parent
    
    init(viewModel: CheckInViewModel) {
        self.viewModel = viewModel
    }
}
```

**Rules**:
- ✅ Use when parent passes ViewModel
- ❌ NOT when creating ViewModel (use @StateObject)

---

### @Binding
**Use for**: Two-way connection between parent and child

```swift
struct MoodScale: View {
    @Binding var value: Int  // ✅ Child modifies parent's state
    
    var body: some View {
        Slider(value: .constant(Double(value)), in: 1...10)
    }
}

// Parent:
struct CheckInView: View {
    @State private var mood = 5
    
    var body: some View {
        MoodScale(value: $mood)  // Pass binding with $
    }
}
```

---

### @Environment
**Use for**: System or app-wide values

```swift
struct CheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button("Done") {
            dismiss()  // ✅ Dismiss this view
        }
    }
}
```

---

### @EnvironmentObject
**Use for**: App-wide shared state

```swift
@main
struct SentinelApp: App {
    @StateObject private var appState = AppStateManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)  // Inject globally
        }
    }
}

struct AnyView: View {
    @EnvironmentObject var appState: AppStateManager  // Access anywhere
    
    var body: some View {
        Text("Mode: \(appState.mode)")
    }
}
```

---

## View Composition

### Extract Subviews for Clarity

```swift
// BAD: Everything in one view
struct CheckInView: View {
    var body: some View {
        VStack {
            Text("Title").font(.title).padding()
            HStack {
                Button("No") { }.buttonStyle(.bordered)
                Button("Yes") { }.buttonStyle(.borderedProminent)
            }
            Text("Footer").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// GOOD: Extracted subviews
struct CheckInView: View {
    var body: some View {
        VStack(spacing: 24) {
            headerView
            answerButtons
            footerView
        }
    }
    
    private var headerView: some View {
        Text("Title")
            .font(.title)
            .padding()
    }
    
    private var answerButtons: some View {
        HStack(spacing: 16) {
            Button("No") { }
                .buttonStyle(.bordered)
            Button("Yes") { }
                .buttonStyle(.borderedProminent)
        }
    }
    
    private var footerView: some View {
        Text("Footer")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

**When to Extract**:
- ✅ View body > 15 lines
- ✅ Repeated UI patterns
- ✅ Complex layouts

---

## Async/Await with Tasks

### Use .task for Async Work

```swift
struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()
    
    var body: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
        .task {
            // ✅ Automatically cancelled when view disappears
            await viewModel.loadData()
        }
    }
}
```

**Advantages**:
- ✅ Auto-cancellation
- ✅ Handles task lifecycle
- ✅ Cleaner than .onAppear with Task { }

---

### Refresh Control

```swift
List(items) { item in
    ItemRow(item: item)
}
.refreshable {
    await viewModel.refresh()  // ✅ Pull to refresh
}
```

---

## Performance Optimization

### LazyVStack/LazyHStack for Long Lists

```swift
// BAD: Creates all views immediately
ScrollView {
    VStack {
        ForEach(0..<1000) { i in
            RowView(index: i)  // ❌ Creates 1000 views at once
        }
    }
}

// GOOD: Lazy loading
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(0..<1000) { i in
            RowView(index: i)  // ✅ Creates views as needed
        }
    }
}
```

---

### Equatable for Performance

```swift
struct CheckInRow: View, Equatable {
    let checkIn: CheckIn
    
    static func == (lhs: CheckInRow, rhs: CheckInRow) -> Bool {
        lhs.checkIn.id == rhs.checkIn.id
    }
    
    var body: some View {
        // ...
    }
}

// Use with .equatable()
ForEach(checkIns) { checkIn in
    CheckInRow(checkIn: checkIn)
        .equatable()  // ✅ Only redraws when checkIn changes
}
```

---

### @ViewBuilder for Conditional Views

```swift
@ViewBuilder
func riskIndicator(for tier: RiskTier) -> some View {
    switch tier {
    case .low:
        Label("Green", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case .moderate:
        Label("Yellow", systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(.yellow)
    case .highMonitoring:
        Label("Orange", systemImage: "exclamationmark.octagon.fill")
            .foregroundStyle(.orange)
    case .crisis:
        Label("Red", systemImage: "xmark.octagon.fill")
            .foregroundStyle(.red)
    }
}
```

---

## Navigation Patterns (iOS 16+)

### NavigationStack (Recommended)

```swift
struct ContentView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            List(items) { item in
                NavigationLink(value: item) {
                    Text(item.name)
                }
            }
            .navigationDestination(for: Item.self) { item in
                DetailView(item: item)
            }
            .navigationTitle("Items")
        }
    }
}
```

**Advantages**:
- ✅ Programmatic navigation
- ✅ Deep linking support
- ✅ State restoration

---

## Error Handling

### Present Errors with Alerts

```swift
struct CheckInView: View {
    @StateObject private var viewModel = CheckInViewModel()
    
    var body: some View {
        // Content
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// In ViewModel:
@Published var errorMessage: String?

func submit() async {
    do {
        try await service.submit()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

---

## Previews

### Multiple Previews for Testing

```swift
#Preview("Light Mode") {
    CheckInView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    CheckInView()
        .preferredColorScheme(.dark)
}

#Preview("With Data") {
    CheckInView()
        .environmentObject(AppStateManager.mock)
}

#Preview("Loading State") {
    CheckInView()
        .environmentObject(AppStateManager.mockLoading)
}
```

---

## Modifiers Order Matters

```swift
// ❌ BAD - Padding after background
Text("Hello")
    .background(.blue)
    .padding()  // Creates padding around blue background

// ✅ GOOD - Padding before background
Text("Hello")
    .padding()
    .background(.blue)  // Blue fills the padded area
```

**Rule**: Order matters! Apply modifiers in logical sequence.

---

## Custom View Modifiers

```swift
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

// Usage:
VStack {
    Text("Content")
}
.cardStyle()  // ✅ Reusable
```

---

## Sentinel-Specific Patterns

### Mission Status Card

```swift
struct MissionStatusCard: View {
    let status: RiskTier
    
    var body: some View {
        VStack(spacing: 16) {
            statusIndicator
            statusText
            lastCheckIn
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(status.color)
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
    }
    
    private var statusText: some View {
        Text(status.displayText)
            .font(.title2)
            .fontWeight(.semibold)
    }
    
    private var lastCheckIn: some View {
        Text("Last Check-In: Today, 9:15 AM")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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
                .frame(maxWidth: .infinity)
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .cornerRadius(12)
        }
        .shadow(radius: 4)
    }
}
```

---

## Testing Views

### Snapshot Testing (Recommended)

```swift
import SnapshotTesting

class CheckInViewTests: XCTestCase {
    func testLightMode() {
        let view = CheckInView()
        assertSnapshot(matching: view, as: .image)
    }
    
    func testDarkMode() {
        let view = CheckInView()
            .preferredColorScheme(.dark)
        assertSnapshot(matching: view, as: .image)
    }
}
```

---

## Common Pitfalls

### ❌ Avoid Heavy Work in body

```swift
// BAD
struct ListView: View {
    var body: some View {
        let sorted = items.sorted()  // ❌ Computed every redraw!
        List(sorted) { item in
            Text(item.name)
        }
    }
}

// GOOD
struct ListView: View {
    var sortedItems: [Item] {  // ✅ Computed property
        items.sorted()
    }
    
    var body: some View {
        List(sortedItems) { item in
            Text(item.name)
        }
    }
}
```

### ❌ Don't Create ObservableObjects in body

```swift
// BAD
struct MyView: View {
    var body: some View {
        let vm = MyViewModel()  // ❌ Created on every render!
        Text(vm.data)
    }
}

// GOOD
struct MyView: View {
    @StateObject private var vm = MyViewModel()  // ✅ Persists
    
    var body: some View {
        Text(vm.data)
    }
}
```

---

## Quick Reference

| Task | Use |
|------|-----|
| Local UI state | `@State` |
| Create ViewModel | `@StateObject` |
| Receive ViewModel from parent | `@ObservedObject` |
| Two-way binding | `@Binding` |
| Access system values | `@Environment` |
| App-wide state | `@EnvironmentObject` |
| Async work on appear | `.task { }` |
| Long lists | `LazyVStack` |
| Navigation | `NavigationStack` |
| Modal | `.sheet` |

---

## Checklist

- [ ] Property wrappers used correctly
- [ ] Subviews extracted for clarity
- [ ] Async work in `.task`
- [ ] LazyVStack for long lists
- [ ] Equatable for performance-critical views
- [ ] Preview tests for light/dark modes
- [ ] No heavy work in `body`
- [ ] Custom modifiers for repeated patterns
