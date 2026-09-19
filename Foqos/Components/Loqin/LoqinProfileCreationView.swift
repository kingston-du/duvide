import FamilyControls
import SwiftData
import SwiftUI

/// Creating a profile, as four full-bleed steps over the live world instead of a nine-section
/// form: name → world → blocks → ends with. Everything rarer (websites, schedule, breaks, unlock
/// tags, notifications, emergency unblock) lives behind "advanced" on the last step, which saves
/// what's been chosen so far and opens the existing `LoqinProfileEditorView` to refine it — same
/// plumbing, same validation, just reached differently.
struct LoqinProfileCreationView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @StateObject private var draft = BlockedProfileDraft()
  @State private var step: Step = .name
  @State private var breathing = false
  @State private var showingActivityPicker = false
  @State private var errorMessage: String?
  @State private var createdProfile: BlockedProfiles?
  @FocusState private var nameFocused: Bool

  private enum Step: Int, CaseIterable {
    case name, world, blocks, endsWith

    var previous: Step? { Step(rawValue: rawValue - 1) }
    var next: Step? { Step(rawValue: rawValue + 1) }
  }

  private var theme: LoqinTheme { LoqinTheme(rawValue: draft.themeId) ?? .blueHour }
  private var accent: Color { theme.resolveAccent(from: draft.themeAccentHex) }

  var body: some View {
    ZStack {
      backgroundLayer

      LoqinStepScaffold(
        theme: theme,
        accent: accent,
        stepIndex: step.rawValue,
        stepCount: Step.allCases.count,
        canAdvance: canAdvance,
        forwardLabel: step == .endsWith ? "create" : "next",
        onBack: back,
        onAdvance: advance
      ) {
        stepContent
      }
    }
    .ignoresSafeArea()
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
    .interactiveDismissDisabled()
    .alert(
      "Couldn't Save Profile",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage ?? "An unknown error occurred.")
    }
    .sheet(item: $createdProfile) { profile in
      LoqinProfileEditorView(profile: profile)
    }
    .onChange(of: createdProfile) { oldValue, newValue in
      // The "advanced" editor was opened on the freshly created profile; once it's dismissed the
      // profile already exists, so the creation flow itself is done.
      if oldValue != nil, newValue == nil {
        dismiss()
      }
    }
    .onAppear { nameFocused = true }
  }

  // MARK: - Background

  @ViewBuilder
  private var backgroundLayer: some View {
    switch step {
    case .world:
      LoqinWorldPicker(themeId: $draft.themeId, accentHex: $draft.themeAccentHex)
    default:
      theme.background(state: .free, accent: accent, breathing: breathing)
        .onAppear {
          withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
            breathing = true
          }
        }
    }
  }

  // MARK: - Steps

  @ViewBuilder
  private var stepContent: some View {
    switch step {
    case .name: nameStep
    case .world: SwiftUI.EmptyView()
    case .blocks: blocksStep
    case .endsWith: endsWithStep
    }
  }

  private var nameStep: some View {
    VStack(spacing: 16) {
      LoqinSectionLabel(text: "name", theme: theme)
      TextField(
        "", text: $draft.name,
        prompt: Text("name this flow").foregroundStyle(theme.textTertiary)
      )
      .font(theme.menuFont(size: 28))
      .foregroundStyle(theme.textPrimary)
      .multilineTextAlignment(.center)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled()
      .focused($nameFocused)
      .submitLabel(.next)
      .onSubmit(advance)
      .frame(maxWidth: 300)
    }
  }

  private var blocksStep: some View {
    VStack(spacing: 18) {
      LoqinSectionLabel(text: "blocks", theme: theme)

      LoqinPickerRow(
        title: appCount == 1 ? "1 app selected" : "\(appCount) apps selected",
        subtitle: "tap to choose",
        theme: theme,
        accent: accent
      ) {
        showingActivityPicker = true
      }
      .padding(.horizontal, 32)

      LoqinSegmentedControl(
        options: ["block these", "allow only these"],
        selection: allowModeSelection,
        theme: theme,
        accent: accent
      )
      .padding(.horizontal, 32)
    }
    .sheet(isPresented: $showingActivityPicker) {
      AppPicker(
        selection: $draft.selectedActivity,
        isPresented: $showingActivityPicker,
        allowMode: draft.enableAllowMode
      )
    }
  }

  private var allowModeSelection: Binding<Int> {
    Binding(
      get: { draft.enableAllowMode ? 1 : 0 },
      set: { newValue in
        let newAllowMode = newValue == 1
        guard newAllowMode != draft.enableAllowMode else { return }
        draft.enableAllowMode = newAllowMode
        draft.selectedActivity = FamilyActivitySelection(includeEntireCategory: newAllowMode)
      }
    )
  }

  private var endsWithStep: some View {
    VStack(spacing: 0) {
      LoqinSectionLabel(text: "ends with", theme: theme)
        .padding(.bottom, 24)

      VStack(spacing: 20) {
        ForEach(StrategyManager.loqinStrategies, id: \.name) { strategy in
          strategyRow(strategy)
        }
      }
      .padding(.horizontal, 32)

      Button(action: openAdvanced) {
        HStack(spacing: 8) {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 14, weight: .semibold))
          Text("advanced")
            .font(.system(size: 15, weight: .semibold))
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .opacity(0.7)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
          Capsule(style: .continuous)
            .fill(LoqinSurface.rowFill(theme))
        )
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Capsule(style: .continuous))
      }
      .buttonStyle(LoqinRowButtonStyle(theme: theme))
      .padding(.top, 28)
    }
  }

  private func strategyRow(_ strategy: BlockingStrategy) -> some View {
    let isSelected = strategy.getIdentifier() == draft.selectedStrategy?.getIdentifier()
    return VStack(alignment: .leading, spacing: 6) {
      Button {
        withAnimation(LoqinMotion.settle) {
          draft.selectedStrategy = strategy
        }
      } label: {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 3) {
            Text(LoqinProfileEditorView.loqinStrategyName(strategy))
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(isSelected ? accent : theme.textPrimary)
            Text(LoqinProfileEditorView.loqinStrategyDescription(strategy))
              .font(.system(size: 12.5))
              .foregroundStyle(theme.textTertiary)
          }
          Spacer()
          if isSelected {
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(accent)
              .padding(.top, 3)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(LoqinRowButtonStyle(theme: theme))

      // A timer profile asks for its length every time it starts, so this stepper sets the value
      // that prompt opens on rather than the length of the session. Labelled as the default so it
      // doesn't read as a decision that's already been made.
      //
      // Range matches `TimerDurationView`'s own floor of 15m — the old 5m lower bound could store
      // a default the start prompt has no way to show.
      if isSelected, strategy.hasTimer {
        Stepper(value: timerDurationBinding, in: 15...480, step: 5) {
          Text("default \(durationLabel), asked each start")
            .font(.system(size: 13))
            .foregroundStyle(theme.textSecondary)
        }
        .tint(accent)
        .padding(.top, 2)
        .transition(.opacity)
      }
    }
  }

  // MARK: - Helpers

  private var appCount: Int {
    FamilyActivityUtil.countSelectedActivities(draft.selectedActivity, allowMode: draft.enableAllowMode)
  }

  private var timerDurationBinding: Binding<Int> {
    Binding(
      get: { StrategyTimerData.decode(draft.strategyData).durationInMinutes },
      set: { minutes in
        var configuration = StrategyTimerData.decode(draft.strategyData)
        configuration.durationInMinutes = minutes
        draft.strategyData = StrategyTimerData.toData(from: configuration)
      }
    )
  }

  private var durationLabel: String {
    let minutes = StrategyTimerData.decode(draft.strategyData).durationInMinutes
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    if remainder == 0 { return "\(hours)h" }
    return "\(hours)h \(remainder)m"
  }

  private var canAdvance: Bool {
    switch step {
    case .name: return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .world: return true
    case .blocks: return true
    case .endsWith: return draft.selectedStrategy != nil
    }
  }

  private func back() {
    if let previous = step.previous {
      withAnimation(LoqinMotion.enter) { step = previous }
    } else {
      dismiss()
    }
  }

  private func advance() {
    guard canAdvance else { return }
    if let next = step.next {
      withAnimation(LoqinMotion.enter) { step = next }
      if next == .name { nameFocused = true }
    } else {
      save()
    }
  }

  private func save() {
    do {
      _ = try draft.save(existingProfile: nil, in: context)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func openAdvanced() {
    do {
      createdProfile = try draft.save(existingProfile: nil, in: context)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
