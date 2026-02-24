# Sentinel iOS Development Documentation
## Complete Guide for AI Coding Agents

---

## 📚 Documentation Overview

This folder contains comprehensive guidelines for developing the Sentinel iOS app. **All code must follow these standards.**

---

## 📖 Documents

### 1. [MVVM Architecture](./01_MVVM_ARCHITECTURE.md)
**Read First** - Mandatory architecture pattern

- ✅ Model-View-ViewModel separation
- ✅ Dependency injection
- ✅ State management rules
- ✅ Common mistakes to avoid

**Key Principle**: Views NEVER access Models directly. All communication through ViewModels.

---

### 2. [iOS Design Guidelines](./02_IOS_DESIGN_GUIDELINES.md)
Apple Human Interface Guidelines compliance

- Typography (SF Pro font scales)
- Color system (semantic colors, dark mode)
- Spacing (8-point grid)
- Navigation patterns
- Buttons, lists, forms
- Animations & haptics
- Accessibility requirements

**Critical**: Use semantic fonts (`.font(.body)`) not hardcoded sizes.

---

### 3. [SwiftUI Best Practices](./03_SWIFTUI_BEST_PRACTICES.md)
Modern SwiftUI patterns for iOS 17+

- Property wrappers (@State, @StateObject, @Binding)
- View composition
- Async/await with .task
- Performance optimization
- Navigation (NavigationStack)
- Error handling
- Testing patterns

**Critical**: Use `@StateObject` when creating ViewModels, `@ObservedObject` when receiving from parent.

---

### 4. [Project Structure](./04_PROJECT_STRUCTURE.md)
File organization and coding standards

- Folder structure
- Naming conventions
- Code style (spacing, braces, optionals)
- Documentation with MARK
- Git commit messages
- Code review checklist

**Critical**: Follow standard folder structure (Models/, ViewModels/, Views/, Services/).

---

### 5. [MedGemma Integration](./05_MEDGEMMA_INTEGRATION.md)
On-device LLM with llama.cpp

- Setup instructions
- MedGemmaEngine implementation
- Prompt building
- Performance optimization
- Testing strategies
- Troubleshooting

**Critical**: Load model on app launch (background thread), enable Metal acceleration.

---

### 6. [Quick Reference](./06_QUICK_REFERENCE.md)
Common patterns and code snippets

- ViewModel/View/Service templates
- Sentinel-specific components (Status indicator, Crisis button, Streak view)
- HealthKit patterns
- Testing helpers
- Animation helpers
- Extensions

**Use this**: Copy-paste starting points for new features.

---

## 🎯 Quick Start Workflow

### For New Features:

1. **Read**: MVVM Architecture (01) ← Mandatory
2. **Design**: iOS Design Guidelines (02) ← Check typography, colors, spacing
3. **Code**: 
   - Create Model (pure Swift, no UI)
   - Create ViewModel (ObservableObject, @Published state)
   - Create View (SwiftUI, observes ViewModel)
4. **Reference**: Quick Reference (06) ← Copy templates
5. **Review**: Project Structure (04) ← Check naming, organization

### For Styling:

1. Use semantic fonts: `.font(.headline)` not `.font(.system(size: 17))`
2. Use semantic colors: `.foregroundStyle(.primary)` not `.foregroundColor(.black)`
3. Use 8-point grid: spacing 8, 16, 24, 32
4. Test light AND dark mode

### For ViewModels:

```swift
@MainActor
final class MyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadData() async {
        // Async work here
    }
}
```

### For Views:

```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()
    
    var body: some View {
        // UI here
    }
}
```

---

## ⚠️ Critical Rules

### MUST Follow:

1. ✅ **MVVM** - Views → ViewModels → Models (never View → Model)
2. ✅ **Semantic Fonts** - Use `.font(.headline)` not hardcoded sizes
3. ✅ **Semantic Colors** - Use `.foregroundStyle(.primary)` for dark mode
4. ✅ **8-Point Grid** - Spacing: 8, 16, 24, 32
5. ✅ **@MainActor** - All ViewModels marked `@MainActor`
6. ✅ **Error Handling** - Use `do-catch`, expose errors via `@Published`
7. ✅ **Accessibility** - Add `.accessibilityLabel()` to images/buttons
8. ✅ **Testing** - Test light/dark mode, real device

### NEVER Do:

1. ❌ Business logic in Views
2. ❌ Hardcoded font sizes (`.system(size: 17)`)
3. ❌ Hardcoded colors that don't adapt to dark mode
4. ❌ Force unwrapping (`!`) without guard
5. ❌ Heavy work in View `body`
6. ❌ Create ObservableObject in View `body`
7. ❌ Import SwiftUI in Models

---

## 📋 Checklist for Every Feature

Copy this for each feature:

```markdown
### [Feature Name] Checklist

#### Architecture
- [ ] Model created (pure Swift, no SwiftUI)
- [ ] ViewModel created (ObservableObject, @MainActor)
- [ ] View observes ViewModel (@StateObject or @ObservedObject)
- [ ] No business logic in View
- [ ] Services injected into ViewModel

#### UI/UX
- [ ] Uses semantic fonts (not hardcoded)
- [ ] Uses semantic colors (adapts to dark mode)
- [ ] Follows 8-point spacing grid
- [ ] Minimum 44pt tap targets
- [ ] Accessibility labels added
- [ ] Tested in light mode
- [ ] Tested in dark mode

#### Code Quality
- [ ] MARK sections organized
- [ ] Public APIs documented
- [ ] No force unwrapping
- [ ] Error handling in place
- [ ] No compiler warnings

#### Testing
- [ ] Unit tests for ViewModel
- [ ] Tested on real device (not just simulator)
- [ ] Edge cases handled
```

---

## 🔍 How to Find What You Need

| Question | Document |
|----------|----------|
| How do I structure my code? | [01_MVVM_ARCHITECTURE](./01_MVVM_ARCHITECTURE.md) |
| What font size should I use? | [02_IOS_DESIGN_GUIDELINES](./02_IOS_DESIGN_GUIDELINES.md) |
| @State vs @StateObject? | [03_SWIFTUI_BEST_PRACTICES](./03_SWIFTUI_BEST_PRACTICES.md) |
| Where does this file go? | [04_PROJECT_STRUCTURE](./04_PROJECT_STRUCTURE.md) |
| How do I use MedGemma? | [05_MEDGEMMA_INTEGRATION](./05_MEDGEMMA_INTEGRATION.md) |
| Show me example code | [06_QUICK_REFERENCE](./06_QUICK_REFERENCE.md) |

---

## 🎨 Sentinel Design Language

### Colors

```swift
Color.primary           // Adaptive text (light/dark)
Color("SentinelGreen")  // Mission Status - Low risk
Color("SentinelYellow") // Mission Status - Moderate
Color("SentinelOrange") // Mission Status - High monitoring
Color("SentinelRed")    // Crisis
```

### Typography

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
VStack(spacing: 16)     // Standard spacing
VStack(spacing: 24)     // Large spacing
VStack(spacing: 8)      // Tight spacing
```

---

## 🚀 Ready to Code

### Start Here:

1. Read [01_MVVM_ARCHITECTURE.md](./01_MVVM_ARCHITECTURE.md)
2. Skim [02_IOS_DESIGN_GUIDELINES.md](./02_IOS_DESIGN_GUIDELINES.md)
3. Reference [06_QUICK_REFERENCE.md](./06_QUICK_REFERENCE.md) for templates

### When Building:

1. Model first (data structure)
2. ViewModel second (logic)
3. View last (UI)
4. Test on device

---

## 📞 Support

If documentation is unclear or incomplete:
1. Check Quick Reference for examples
2. Reference Apple HIG: https://developer.apple.com/design/
3. Check SwiftUI documentation: https://developer.apple.com/documentation/swiftui/

---

## ✅ Quality Standards

All code must:
- ✅ Follow MVVM architecture
- ✅ Use semantic fonts and colors
- ✅ Support light and dark mode
- ✅ Include accessibility labels
- ✅ Have error handling
- ✅ Be tested on real device
- ✅ Pass SwiftLint (if configured)
- ✅ Have no compiler warnings

---

**Last Updated**: January 29, 2026  
**Version**: 1.0 - Initial release for Sentinel MVP

---

## 📚 Additional Resources

- **Apple HIG**: https://developer.apple.com/design/human-interface-guidelines/
- **SF Symbols**: https://developer.apple.com/sf-symbols/
- **SwiftUI Tutorials**: https://developer.apple.com/tutorials/swiftui/
- **WWDC Sessions**: Search "SwiftUI" on developer.apple.com
