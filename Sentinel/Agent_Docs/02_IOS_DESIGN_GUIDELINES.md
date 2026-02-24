# iOS Human Interface Guidelines for Sentinel
## Apple Design Standards - Must Follow for App Store Approval

---

## Core Design Principles

### 1. Clarity
- **Text**: Use SF Pro (system font) - never custom fonts for body text
- **Size**: Minimum 17pt for body text (accessibility)
- **Contrast**: WCAG AA minimum (4.5:1 for normal text)
- **Iconography**: Use SF Symbols whenever possible

### 2. Deference
- **Content First**: UI defers to content (minimal chrome)
- **Translucency**: Use system materials (`.ultraThinMaterial`)
- **White Space**: Generous padding (minimum 16pt)

### 3. Depth
- **Layering**: Use shadows and materials for hierarchy
- **Motion**: Smooth animations (0.3s default duration)
- **Feedback**: Haptics for important actions

---

## Typography

### SF Pro Font Scales (Use These Exactly)

```swift
// Semantic Styles (ALWAYS use these, not hardcoded sizes)
.font(.largeTitle)      // 34pt, Bold - Screen titles only
.font(.title)           // 28pt, Regular - Section headers
.font(.title2)          // 22pt, Regular - Subsections
.font(.title3)          // 20pt, Regular - Card headers
.font(.headline)        // 17pt, Semibold - List items, buttons
.font(.body)            // 17pt, Regular - Primary content
.font(.callout)         // 16pt, Regular - Secondary content
.font(.subheadline)     // 15pt, Regular - Metadata
.font(.footnote)        // 13pt, Regular - Fine print
.font(.caption)         // 12pt, Regular - Labels
.font(.caption2)        // 11pt, Regular - Smallest text (use sparingly)
```

**Rules**:
- ✅ ALWAYS use semantic font styles
- ❌ NEVER hardcode font sizes like `.font(.system(size: 17))`
- ✅ Support Dynamic Type (text scales with user preference)

```swift
// GOOD
Text("Mission Status")
    .font(.largeTitle)
    .fontWeight(.bold)

// BAD
Text("Mission Status")
    .font(.system(size: 34))  // ❌ Don't do this
```

---

## Color System

Color System
Sentinel utilizes a custom "Tactical" palette designed for high legibility in the field. These colors must be defined in your Assets.xcassets as named colors with specific values for Light and Dark modes.

1. Tactical Backgrounds & Surfaces

Used to create depth and hierarchy without relying on standard system grays.

Name	Light Hex	Dark Hex	Usage
TacticalBackground	#F9FAFA	#16181D	Main screen background
TacticalSurface	#FFFFFF	#1E2126	Cards, modals, and buttons
TacticalSurfaceHover	#F1F3F4	#252930	Active/Highlighted states
2. Brand & Action Colors

The primary identity colors for Sentinel.

SentinelPrimary: #1B9898 (Primary Teal)

SentinelPrimaryDark: #136D6D

SentinelRed: #EF4444 (Used for emergency/crisis buttons)

3. Implementation Rules

Shadows (Tactical Glow): High-priority interactive elements (like the active progress bar or primary buttons) should use a primary-colored glow rather than a standard black shadow.

Swift
.shadow(color: Color("SentinelPrimary").opacity(0.6), radius: 10)
Background Layering: Always use TacticalBackground for the root view and TacticalSurface for elevated containers or cards.

Adaptive Text: Use system Color.primary and Color.secondary. These will automatically adapt to remain legible against the tactical backgrounds.---

## Spacing & Layout

### Standard Spacing Units

```swift
// Apple's 8-point grid system
let spacing4: CGFloat = 4    // Tight spacing
let spacing8: CGFloat = 8    // Default between related items
let spacing12: CGFloat = 12  // Small spacing
let spacing16: CGFloat = 16  // Default padding (most common)
let spacing20: CGFloat = 20  // Medium spacing
let spacing24: CGFloat = 24  // Large spacing
let spacing32: CGFloat = 32  // Extra large spacing
let spacing40: CGFloat = 40  // Section breaks
```

**Padding Rules**:
```swift
VStack(spacing: 16) {  // ✅ Related items
    Text("Title")
        .padding(.horizontal, 16)  // ✅ Screen edges
    
    // Content
}
.padding()  // ✅ Default 16pt all sides
```

### Safe Areas
```swift
// ALWAYS respect safe areas
VStack {
    // Content
}
.ignoresSafeArea(.keyboard)  // OK for specific cases
// Never .ignoresSafeArea() without reason
```

---

## Navigation

### Navigation Patterns for Sentinel

#### 1. TabView (Root Navigation)
```swift
TabView {
    MissionStatusView()
        .tabItem {
            Label("Status", systemImage: "shield.fill")
        }
    
    CheckInView()
        .tabItem {
            Label("Check-In", systemImage: "checkmark.circle.fill")
        }
    
    SafetyPlanView()
        .tabItem {
            Label("Safety Plan", systemImage: "heart.text.square.fill")
        }
}
```

**Rules**:
- ✅ 3-5 tabs maximum
- ✅ Always use SF Symbols for icons
- ✅ Keep labels short (1-2 words)

#### 2. NavigationStack (Hierarchical)
```swift
NavigationStack {
    MissionStatusView()
        .navigationTitle("Mission Status")
        .navigationBarTitleDisplayMode(.large)
}
```

**Title Display Modes**:
- `.large` - Scrolling screens with content
- `.inline` - Modal sheets, detail views

#### 3. Sheet (Modal Presentation)
```swift
.sheet(isPresented: $showSettings) {
    SettingsView()
        .presentationDetents([.medium, .large])  // iOS 16+
}
```

---

## Buttons & Actions

### Button Styles

```swift
// Primary Action (Most Important)
Button("Submit Check-In") {
    viewModel.submit()
}
.buttonStyle(.borderedProminent)  // ✅ Filled button

// Secondary Action
Button("View Details") {
    viewModel.showDetails()
}
.buttonStyle(.bordered)  // ✅ Outline button

// Tertiary Action
Button("Cancel") {
    dismiss()
}
.buttonStyle(.plain)  // ✅ Text button

// Destructive Action
Button("Delete", role: .destructive) {
    viewModel.delete()
}
.buttonStyle(.borderedProminent)
```

### Button Sizing
```swift
// Minimum tap target: 44x44 points (Apple requirement)
Button("Action") {
    // ...
}
.frame(minHeight: 44)  // Ensure accessibility
```

### SF Symbols in Buttons
```swift
Button {
    // Action
} label: {
    Label("Call 988", systemImage: "phone.fill")
}
```

---

## Lists & Scrolling

### List Styles

```swift
// Modern iOS Style (Recommended for Sentinel)
List {
    Section("Recent Check-Ins") {
        ForEach(checkIns) { checkIn in
            CheckInRow(checkIn: checkIn)
        }
    }
}
.listStyle(.insetGrouped)  // ✅ Modern, card-style

// Alternative for full-width
.listStyle(.plain)
```

### ScrollView with Lazy Loading
```swift
ScrollView {
    LazyVStack(spacing: 16) {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
    .padding()
}
```

---

## Forms & Input

### TextField Standards
```swift
TextField("Enter your name", text: $name)
    .textFieldStyle(.roundedBorder)
    .autocorrectionDisabled()
    .textInputAutocapitalization(.words)
```

### Picker
```swift
Picker("Risk Level", selection: $riskLevel) {
    ForEach(RiskTier.allCases) { tier in
        Text(tier.displayName).tag(tier)
    }
}
.pickerStyle(.segmented)  // For 2-4 options
// or
.pickerStyle(.menu)       // For 5+ options
```

### Toggle
```swift
Toggle("Enable Notifications", isOn: $notificationsEnabled)
    .tint(.accentColor)  // Use app's accent color
```

---

## Loading & Progress

### Activity Indicator
```swift
if viewModel.isLoading {
    ProgressView()
        .controlSize(.large)  // For prominent loading
}
```

### Progress Bar
```swift
ProgressView(value: progress, total: 1.0) {
    Text("Analyzing...")
}
.progressViewStyle(.linear)
```

### Overlay Pattern
```swift
.overlay {
    if viewModel.isLoading {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
        
        ProgressView("Analyzing...")
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
    }
}
```

---

## Alerts & Dialogs

### Alert (Simple Choices)
```swift
.alert("Crisis Detected", isPresented: $showAlert) {
    Button("Call 988", role: .destructive) {
        // Primary action
    }
    Button("Cancel", role: .cancel) { }
} message: {
    Text("Your responses indicate you may be in crisis.")
}
```

### Confirmation Dialog (3+ Options)
```swift
.confirmationDialog("Choose Action", isPresented: $showDialog) {
    Button("Call Battle Buddy") { }
    Button("View Safety Plan") { }
    Button("Call 988") { }
    Button("Cancel", role: .cancel) { }
}
```

---

## Animations

### Standard Durations
```swift
// Quick feedback
withAnimation(.easeInOut(duration: 0.2)) {
    isExpanded.toggle()
}

// Standard transition
withAnimation(.easeInOut(duration: 0.3)) {
    showDetail = true
}

// Spring animations (preferred for natural feel)
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
    scale = 1.2
}
```

### Transitions
```swift
Text("Message")
    .transition(.move(edge: .bottom).combined(with: .opacity))
```

---

## Haptics

```swift
// Use for important feedback
let haptic = UIImpactFeedbackGenerator(style: .medium)
haptic.impactOccurred()

// Success feedback
let success = UINotificationFeedbackGenerator()
success.notificationOccurred(.success)

// Error feedback
let error = UINotificationFeedbackGenerator()
error.notificationOccurred(.error)
```

**When to Use**:
- ✅ Button taps (critical actions)
- ✅ Success/error confirmations
- ✅ Selection changes
- ❌ NOT for every interaction (overwhelming)

---

## Accessibility

### VoiceOver Support
```swift
Image(systemName: "phone.fill")
    .accessibilityLabel("Call 988")
    .accessibilityHint("Calls the Veterans Crisis Line")

Button("Submit") {
    // ...
}
.accessibilityIdentifier("submitButton")  // For UI testing
```

### Dynamic Type
```swift
// ALWAYS use semantic fonts (scales automatically)
Text("Title")
    .font(.headline)

// For custom layouts that need to adapt:
@ScaledMetric var spacing: CGFloat = 16
```

### Color Contrast
```swift
// Test with accessibility inspector
// Minimum ratios:
// - Normal text: 4.5:1
// - Large text (18pt+): 3:1
// - UI components: 3:1
```

---

## Sentinel-Specific Design Patterns

### Mission Status Screen
```swift
VStack(spacing: 24) {
    // Status Indicator (Traffic Light)
    ZStack {
        Circle()
            .fill(statusColor)
            .frame(width: 80, height: 80)
            .shadow(radius: 8)
        
        Image(systemName: "shield.fill")
            .font(.system(size: 40))
            .foregroundStyle(.white)
    }
    
    Text("GREEN - All Systems Nominal")
        .font(.title2)
        .fontWeight(.semibold)
    
    Text("Last Check-In: Today, 9:15 AM")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    
    // Streak
    HStack(spacing: 8) {
        Image(systemName: "flame.fill")
            .foregroundStyle(.orange)
        Text("7 day streak")
            .font(.headline)
    }
}
.padding()
```

### Crisis Button (Always Accessible)
```swift
Button {
    // Immediate action
} label: {
    Label("988 Veterans Crisis Line", systemImage: "phone.fill")
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red)
        .foregroundStyle(.white)
        .cornerRadius(12)
}
.shadow(radius: 4)
```

### Liquid Glass Effect (iOS 18)
```swift
.background(.ultraThinMaterial)  // Frosted glass
.background(.regularMaterial)    // Less transparent
.background(.thickMaterial)      // Most opaque
```

---

## Checklist for Every Screen

- [ ] Uses semantic font styles (not hardcoded sizes)
- [ ] Colors adapt to light/dark mode
- [ ] Spacing follows 8-point grid
- [ ] Respects safe areas
- [ ] Minimum 44pt tap targets
- [ ] VoiceOver labels on images/buttons
- [ ] Supports Dynamic Type
- [ ] Animations feel natural (0.2-0.3s)
- [ ] Loading states shown for async operations
- [ ] Error messages are clear and actionable

---

## Common Mistakes

### ❌ BAD
```swift
Text("Title")
    .font(.system(size: 28))  // Hardcoded
    .foregroundColor(.black)  // Won't adapt to dark mode

VStack(spacing: 15) {  // Not on 8pt grid
    // ...
}
```

### ✅ GOOD
```swift
Text("Title")
    .font(.title)  // Semantic
    .foregroundStyle(.primary)  // Adaptive

VStack(spacing: 16) {  // 8pt grid
    // ...
}
```

---

## Resources

- **Apple HIG**: https://developer.apple.com/design/human-interface-guidelines/
- **SF Symbols**: https://developer.apple.com/sf-symbols/
- **WWDC Sessions**: Search "SwiftUI" on developer.apple.com

**Test on Real Devices**: Simulator doesn't show true colors, haptics, or performance.
