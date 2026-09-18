import FamilyControls
import SwiftData
import SwiftUI

/// Full Aura profile editor. Name, world, stop method, blocked apps, websites, physical NFC
/// unlocks, schedule, timed breaks, emergency unblocks, and notifications, all backed by the foqos
/// engine. Copy is lowercase, one clause per caption, commas not periods, no terminal period.
struct LoqinProfileEditorView: View {
  let profile: BlockedProfiles?  // nil = new profile

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @StateObject private var draft: BlockedProfileDraft

  @State private var showingStrategyPicker = false
  @State private var showingActivityPicker = false
  @State private var showingDomainPicker = false
  @State private var showingSchedulePicker = false
  @State private var showingTimerSettings = false
  @State private var errorMessage: String?

  init(profile: BlockedProfiles?) {
    self.profile = profile
    _draft = StateObject(wrappedValue: BlockedProfileDraft(profile: profile))
  }

  var body: some View {
    NavigationStack {
      ZStack {
        LoqinScreenBackground(theme: .aura, accent: AuraTheme.accent)

        Form {
          nameSection
          themeSection
          strategySection
          appsSection
          domainsSection
          physicalUnlocksSection
          scheduleSection
          breaksSection
          stopOptionsSection
          notificationsSection
        }
        .scrollContentBackground(.hidden)
        .tint(AuraTheme.accent)
      }
      .navigationTitle(profile == nil ? "new profile" : "edit profile")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancel") { dismiss() }
            .foregroundStyle(AuraTheme.textSecondary)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("save") { save() }
            .fontWeight(.semibold)
            .foregroundStyle(AuraTheme.accent)
            .disabled(!draft.isValid)
        }
      }
      .sheet(isPresented: $showingStrategyPicker) {
        LoqinStrategyPicker(
          strategies: StrategyManager.loqinStrategies,
          selectedStrategy: $draft.selectedStrategy
        )
      }
      .sheet(isPresented: $showingActivityPicker) {
        AppPicker(
          selection: $draft.selectedActivity,
          isPresented: $showingActivityPicker,
          allowMode: draft.enableAllowMode
        )
      }
      .sheet(isPresented: $showingDomainPicker) {
        DomainPicker(
          domains: $draft.domains,
          isPresented: $showingDomainPicker,
          allowMode: draft.enableAllowModeDomain
        )
      }
      .sheet(isPresented: $showingSchedulePicker) {
        SchedulePicker(
          schedule: $draft.schedule,
          isPresented: $showingSchedulePicker
        )
      }
      .sheet(isPresented: $showingTimerSettings) {
        TimerDurationView(
          profileName: draft.name.isEmpty ? "this profile" : draft.name,
          initialConfiguration: StrategyTimerData.decode(draft.strategyData),
          actionTitle: "save",
          showsDisableStopButton: false
        ) { configuration in
          draft.strategyData = StrategyTimerData.toData(from: configuration)
        }
        .presentationDetents([.medium, .large])
      }
      .alert(
        "couldn't save profile",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { if !$0 { errorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "something went wrong")
      }
      .onAppear {
        if profile == nil {
          draft.enableLiveActivity = true
        }
      }
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Sections

  private var nameSection: some View {
    Section {
      TextField("profile name", text: $draft.name)
        .foregroundStyle(AuraTheme.textPrimary)
        .textContentType(.none)
        .editorRow()
    } header: {
      LoqinSectionLabel(text: "name", theme: .aura)
    }
  }

  /// The full-bleed picker from the create-profile flow, dropped into the form so editing a
  /// profile's world is the same "stand in it" choice instead of the old 92×96pt scroll cards.
  private var themeSection: some View {
    Section {
      LoqinWorldPicker(
        themeId: $draft.themeId,
        accentHex: $draft.themeAccentHex,
        accentPlacement: .below
      )
      .frame(height: 400)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .listRowInsets(EdgeInsets())
      .listRowBackground(Color.clear)
    } header: {
      LoqinSectionLabel(text: "world", theme: .aura)
    }
  }

  private var strategySection: some View {
    Section {
      Button {
        showingStrategyPicker = true
      } label: {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(selectedStrategyName)
              .foregroundStyle(AuraTheme.textPrimary)
            Text(selectedStrategyDescription)
              .font(.caption)
              .foregroundStyle(AuraTheme.textSecondary)
              .lineLimit(2)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AuraTheme.textTertiary)
        }
      }
      .foregroundStyle(.primary)
      .editorRow()

      if draft.selectedStrategy?.hasTimer == true {
        Button {
          showingTimerSettings = true
        } label: {
          HStack {
            Text("duration")
            Spacer()
            Text(durationLabel)
              .foregroundStyle(AuraTheme.textSecondary)
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(AuraTheme.textTertiary)
          }
        }
        .foregroundStyle(.primary)
        .editorRow()
      }
    } header: {
      LoqinSectionLabel(text: "stops with", theme: .aura)
    }
  }

  private var appsSection: some View {
    Section {
      Button {
        showingActivityPicker = true
      } label: {
        HStack {
          Text(draft.enableAllowMode ? "apps to allow" : "apps to block")
            .foregroundStyle(AuraTheme.textPrimary)
          Spacer()
          Text(appCountLabel)
            .foregroundStyle(AuraTheme.textSecondary)
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AuraTheme.textTertiary)
        }
      }
      .foregroundStyle(.primary)
      .editorRow()

      LoqinSegmentedControl(
        options: ["block these", "allow only these"],
        selection: allowModeSelection,
        theme: .aura,
        accent: AuraTheme.accent
      )
      .onChange(of: draft.enableAllowMode) { _, newValue in
        draft.selectedActivity = FamilyActivitySelection(includeEntireCategory: newValue)
      }
      .editorRow()

      LoqinToggle(
        title: "block websites in safari",
        description: "also block the sites behind your blocked apps",
        isOn: $draft.enableSafariBlocking
      )
      .editorRow()
    } header: {
      LoqinSectionLabel(text: "blocks", theme: .aura)
    }
  }

  private var domainsSection: some View {
    Section {
      Button {
        showingDomainPicker = true
      } label: {
        HStack {
          Text(draft.enableAllowModeDomain ? "sites to allow" : "sites to block")
            .foregroundStyle(AuraTheme.textPrimary)
          Spacer()
          Text(domainCountLabel)
            .foregroundStyle(AuraTheme.textSecondary)
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AuraTheme.textTertiary)
        }
      }
      .foregroundStyle(.primary)
      .editorRow()

      LoqinToggle(
        title: "allow only these sites",
        description: "every other site is blocked",
        isOn: $draft.enableAllowModeDomain
      )
      .editorRow()
    } header: {
      LoqinSectionLabel(text: "websites", theme: .aura)
    }
  }

  private var physicalUnlocksSection: some View {
    Section {
      LoqinPhysicalUnlockSelector(physicalUnblockItems: $draft.physicalUnblockItems)
        .editorRow()
    } header: {
      LoqinSectionLabel(text: "unlock tags", theme: .aura)
    } footer: {
      Text("only tags added here can unlock this profile, all other tags are rejected")
    }
  }

  private var scheduleSection: some View {
    Section {
      Button {
        showingSchedulePicker = true
      } label: {
        HStack {
          Text("set schedule")
            .foregroundStyle(AuraTheme.textPrimary)
          Spacer()
          Text(scheduleSummary)
            .foregroundStyle(AuraTheme.textSecondary)
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AuraTheme.textTertiary)
        }
      }
      .foregroundStyle(.primary)
      .editorRow()
    } header: {
      LoqinSectionLabel(text: "schedule", theme: .aura)
    }
  }

  private var breaksSection: some View {
    Section {
      if draft.selectedStrategyAllowsTimedBreaks {
        LoqinToggle(
          title: "allow timed breaks",
          description: "a short pause that ends on its own",
          isOn: $draft.enableBreaks
        )
        .editorRow()

        if draft.enableBreaks {
          Stepper(value: $draft.breakTimeInMinutes, in: 5...60, step: 5) {
            HStack {
              Text("break duration")
              Spacer()
              Text(DateFormatters.formatMinutes(draft.breakTimeInMinutes))
                .foregroundStyle(AuraTheme.textSecondary)
            }
          }
          .editorRow()

          LoqinToggle(
            title: "allow multiple breaks",
            description: "split your break time into more than one pause",
            isOn: $draft.allowMultipleBreaks
          )
          .editorRow()
        }
      } else {
        Text("not available with this stop method")
          .font(.caption)
          .foregroundStyle(AuraTheme.textSecondary)
          .editorRow()
      }
    } header: {
      LoqinSectionLabel(text: "breaks", theme: .aura)
    }
  }

  private var stopOptionsSection: some View {
    Section {
      LoqinToggle(
        title: "emergency unblock",
        description: "end a session early in an emergency",
        isOn: $draft.enableEmergencyUnblock
      )
      .editorRow()
    } header: {
      LoqinSectionLabel(text: "stop options", theme: .aura)
    }
  }

  private var notificationsSection: some View {
    Section {
      Toggle("live activity", isOn: $draft.enableLiveActivity)
        .tint(AuraTheme.accent)
        .editorRow()
      Toggle("reminder", isOn: $draft.enableReminder)
        .tint(AuraTheme.accent)
        .editorRow()
    } header: {
      LoqinSectionLabel(text: "notifications", theme: .aura)
    }
  }

  // MARK: - Helpers

  private var selectedStrategyName: String {
    guard let strategy = draft.selectedStrategy else { return "nfc tag" }
    return Self.loqinStrategyName(strategy)
  }

  private var selectedStrategyDescription: String {
    guard let strategy = draft.selectedStrategy else { return "" }
    return Self.loqinStrategyDescription(strategy)
  }

  private var appCountLabel: String {
    FamilyActivityUtil.getCountDisplayText(draft.selectedActivity, allowMode: draft.enableAllowMode)
  }

  private var allowModeSelection: Binding<Int> {
    Binding(
      get: { draft.enableAllowMode ? 1 : 0 },
      set: { newValue in
        draft.enableAllowMode = newValue == 1
      }
    )
  }

  private var domainCountLabel: String {
    let count = draft.domains.count
    if count == 0 { return "none" }
    return "\(count) \(count == 1 ? "site" : "sites")"
  }

  private var durationLabel: String {
    let minutes = StrategyTimerData.decode(draft.strategyData).durationInMinutes
    let hours = minutes / 60
    let remainder = minutes % 60
    if hours == 0 { return "\(remainder)m" }
    if remainder == 0 { return "\(hours)h" }
    return "\(hours)h \(remainder)m"
  }

  private var scheduleSummary: String {
    draft.schedule.isActive ? draft.schedule.summaryText : "none"
  }

  private func save() {
    do {
      _ = try draft.save(existingProfile: profile, in: context)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  // MARK: - Strategy copy

  /// Lowercase labels for the four loqin strategies, matching the app's voice.
  static func loqinStrategyName(_ strategy: BlockingStrategy) -> String {
    switch strategy.getIdentifier() {
    case ManualBlockingStrategy.id: return "manual"
    case NFCBlockingStrategy.id: return "nfc tag"
    case NFCManualBlockingStrategy.id: return "manual + nfc"
    case NFCTimerBlockingStrategy.id: return "timer"
    default: return strategy.name
    }
  }

  static func loqinStrategyDescription(_ strategy: BlockingStrategy) -> String {
    switch strategy.getIdentifier() {
    case ManualBlockingStrategy.id: return "tap to begin and end"
    case NFCBlockingStrategy.id: return "scan same tag to begin and end"
    // "hold", not "tap": the home screen gates this strategy behind `entryGesture == .hold`.
    case NFCManualBlockingStrategy.id: return "hold to begin, scan tag to end"
    case NFCTimerBlockingStrategy.id: return "run for a set time, scan tag to end early"
    default: return strategy.description
    }
  }
}

private extension View {
  /// A translucent panel fill for editor rows, so the form reads as part of the themed world
  /// instead of default grey system cards.
  func editorRow() -> some View {
    listRowBackground(LoqinSurface.rowFill(.aura))
  }
}

/// Aura-styled toggle with a title and a muted description line, tinted with the Aura accent.
private struct LoqinToggle: View {
  let title: String
  let description: String
  @Binding var isOn: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Toggle(title, isOn: $isOn)
        .tint(AuraTheme.accent)

      Text(description)
        .font(.caption)
        .foregroundStyle(AuraTheme.textSecondary)
        .padding(.vertical, 4)
        .padding(.trailing, 40)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// NFC-only physical unlock selector. "set" scans a tag when empty; each saved tag can be removed.
/// Saved tags are the tags allowed to unlock this profile while a session is active.
private struct LoqinPhysicalUnlockSelector: View {
  @Binding var physicalUnblockItems: [PhysicalUnblockItem]

  @State private var showingError = false
  @State private var errorMessage = ""

  private let physicalReader = PhysicalReader()

  private var nfcItems: [PhysicalUnblockItem] {
    physicalUnblockItems.filter { $0.type == .nfc }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if nfcItems.isEmpty {
        Button(action: addNFCTag) {
          HStack(spacing: 8) {
            Image(systemName: "wave.3.right.circle.fill")
            Text("set nfc tag")
              .fontWeight(.semibold)
            Spacer()
            Image(systemName: "plus")
          }
          .padding(.vertical, 6)
        }
        .foregroundStyle(AuraTheme.accent)
      } else {
        ForEach(nfcItems) { item in
          HStack(spacing: 10) {
            Image(systemName: "wave.3.right.circle.fill")
              .foregroundStyle(AuraTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
              Text(item.name)
                .foregroundStyle(AuraTheme.textPrimary)
              Text(shortCodeValue(item.codeValue))
                .font(.caption)
                .foregroundStyle(AuraTheme.textSecondary)
                .lineLimit(1)
            }
            Spacer()
            Menu {
              Button(role: .destructive) {
                removeItem(item.id)
              } label: {
                Label("delete", systemImage: "trash")
              }
            } label: {
              Image(systemName: "ellipsis.circle")
                .foregroundStyle(AuraTheme.accent)
            }
          }
        }

        Button(action: addNFCTag) {
          HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
            Text("add tag")
              .fontWeight(.semibold)
            Spacer()
          }
          .padding(.vertical, 6)
        }
        .foregroundStyle(AuraTheme.accent)
      }
    }
    .alert("couldn't add tag", isPresented: $showingError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }

  private func addNFCTag() {
    physicalReader.readNFCTag(
      onSuccess: { codeValue in
        addItem(codeValue: codeValue)
      }
    )
  }

  private func addItem(codeValue: String) {
    let normalizedCodeValue = PhysicalUnblockItem.normalizedCodeValue(codeValue, type: .nfc)

    guard !normalizedCodeValue.isEmpty else {
      errorMessage = "that tag is empty"
      showingError = true
      return
    }

    guard
      !physicalUnblockItems.contains(where: {
        $0.type == .nfc && $0.codeValue == normalizedCodeValue
      })
    else {
      errorMessage = "that tag is already added"
      showingError = true
      return
    }

    physicalUnblockItems.append(
      PhysicalUnblockItem(
        name: "NFC Tag \(nfcItems.count + 1)",
        type: .nfc,
        codeValue: normalizedCodeValue
      )
    )
  }

  private func removeItem(_ id: UUID) {
    physicalUnblockItems.removeAll { $0.id == id }
  }

  private func shortCodeValue(_ codeValue: String) -> String {
    guard codeValue.count > 28 else { return codeValue }
    return "\(codeValue.prefix(12))...\(codeValue.suffix(8))"
  }
}

/// Simple Aura-styled strategy picker limited to the three loqin strategies.
private struct LoqinStrategyPicker: View {
  @Environment(\.dismiss) private var dismiss

  let strategies: [BlockingStrategy]
  @Binding var selectedStrategy: BlockingStrategy?

  var body: some View {
    NavigationStack {
      List {
        ForEach(0..<strategies.count, id: \.self) { index in
          let strategy = strategies[index]
          Button {
            selectedStrategy = strategy
            dismiss()
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(LoqinProfileEditorView.loqinStrategyName(strategy))
                  .font(.headline)
                  .foregroundStyle(AuraTheme.textPrimary)
                Spacer()
                if strategy.getIdentifier() == selectedStrategy?.getIdentifier() {
                  Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AuraTheme.accent)
                }
              }
              Text(LoqinProfileEditorView.loqinStrategyDescription(strategy))
                .font(.subheadline)
                .foregroundStyle(AuraTheme.textSecondary)
                .lineLimit(3)
            }
            .padding(.vertical, 4)
          }
          .listRowBackground(AuraTheme.panel)
        }
      }
      .scrollContentBackground(.hidden)
      .background(AuraTheme.void.ignoresSafeArea())
      .navigationTitle("stops with")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("cancel") { dismiss() }
            .foregroundStyle(AuraTheme.textSecondary)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
}
