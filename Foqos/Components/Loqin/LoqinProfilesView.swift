import SwiftData
import SwiftUI

/// Profile list with tap-to-edit, swipe/Edit-mode delete, and drag-to-reorder.
struct LoqinProfilesView: View {
  @Environment(\.modelContext) private var context

  let theme: LoqinTheme
  let accent: Color
  let onBack: () -> Void

  @Query(sort: [SortDescriptor(\BlockedProfiles.order, order: .forward)])
  private var profiles: [BlockedProfiles]

  @State private var editingProfile: BlockedProfiles?
  @State private var showingNewProfile = false
  @State private var editMode: EditMode = .inactive
  @State private var showingActiveDeleteRefusal = false

  var body: some View {
    ZStack {
      LoqinScreenBackground(theme: theme, accent: accent)

      VStack(spacing: 0) {
        LoqinScreenHeader(title: "profiles", theme: theme, onBack: onBack) {
          if !profiles.isEmpty {
            Button(editMode.isEditing ? "done" : "edit") {
              withAnimation {
                editMode = editMode.isEditing ? .inactive : .active
              }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
          }
        }

        List {
          Section {
            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
              Button {
                editingProfile = profile
              } label: {
                LoqinRow(
                  title: profile.name,
                  meta: strategyLabel(for: profile),
                  swatch: themeDot(for: profile),
                  showsChevron: true,
                  theme: theme,
                  accent: accent
                )
                .padding(.vertical, 5)
              }
              .buttonStyle(LoqinRowButtonStyle(theme: theme))
              .listRowBackground(Color.clear)
              .listRowSeparatorTint(LoqinSurface.separator(theme))
              .loqinAppear(index)
            }
            .onDelete(perform: deleteProfiles)
            .onMove(perform: moveProfiles)
          }

          Section {
            Button {
              showingNewProfile = true
            } label: {
              LoqinRow(
                title: "new profile",
                systemImage: "plus.circle.fill",
                titleColor: accent,
                theme: theme,
                accent: accent
              )
              .padding(.vertical, 5)
            }
            .buttonStyle(LoqinRowButtonStyle(theme: theme))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(LoqinSurface.separator(theme))
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .tint(accent)
        .environment(\.editMode, $editMode)
      }
      .loqinTopSafePadding()
    }
    .modifier(ProfilesBackTapModifier(editMode: editMode, onBack: onBack))
    .preferredColorScheme(theme.isLightTheme ? .light : .dark)
    .sheet(item: $editingProfile) { profile in
      LoqinProfileEditorView(profile: profile)
    }
    .fullScreenCover(isPresented: $showingNewProfile) {
      LoqinProfileCreationView()
    }
    .alert("Session Running", isPresented: $showingActiveDeleteRefusal) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Stop this profile's session before deleting it.")
    }
  }

  private func strategyLabel(for profile: BlockedProfiles) -> String {
    let id = profile.blockingStrategyId ?? NFCBlockingStrategy.id
    switch id {
    case ManualBlockingStrategy.id: return "manual"
    case NFCManualBlockingStrategy.id: return "manual + nfc"
    case NFCTimerBlockingStrategy.id: return "timer"
    default: return "nfc"
    }
  }

  private func themeDot(for profile: BlockedProfiles) -> Color {
    let theme = LoqinTheme(rawValue: profile.themeId) ?? .blueHour
    return theme.resolveAccent(from: profile.themeAccentHex)
  }

  /// Deleting the profile a session is running on is refused rather than handled: the shield is
  /// system state that outlives this row, so the delete would leave the phone blocked with no
  /// session to stop and no profile to stop it from. `deleteProfile` tears that state down as a
  /// backstop, but the honest answer to "delete the thing that is currently running" is no.
  private func deleteProfiles(at offsets: IndexSet) {
    let toDelete = offsets.map { profiles[$0] }
    let activeProfileId = BlockedProfileSession.mostRecentActiveSession(in: context)?
      .blockedProfile.id

    guard !toDelete.contains(where: { $0.id == activeProfileId }) else {
      showingActiveDeleteRefusal = true
      return
    }

    do {
      for profile in toDelete {
        try BlockedProfiles.deleteProfile(profile, in: context)
      }

      // Close the gaps the deletion left in `order`, so the next reorder doesn't fight them.
      let remaining = try BlockedProfiles.fetchProfiles(in: context)
      try BlockedProfiles.reorderProfiles(remaining, in: context)
    } catch {
      print("Failed to delete or reorder profiles: \(error)")
    }
  }

  private func moveProfiles(from source: IndexSet, to destination: Int) {
    var reordered = profiles
    reordered.move(fromOffsets: source, toOffset: destination)
    try? BlockedProfiles.reorderProfiles(reordered, in: context)
  }
}

/// The tap-outside-to-go-back gesture is attached only while the list isn't in edit mode, so the
/// edit-mode delete controls (the red "−" and the "Delete" row) never have to fight it for touches.
private struct ProfilesBackTapModifier: ViewModifier {
  let editMode: EditMode
  let onBack: () -> Void

  @ViewBuilder
  func body(content: Content) -> some View {
    if editMode == .inactive {
      content.onTapGesture { onBack() }
    } else {
      content
    }
  }
}
