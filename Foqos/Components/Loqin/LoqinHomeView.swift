import SwiftData
import SwiftUI

/// The loqin home screen. One shared behavior layer — the full-screen tap/hold gesture, the
/// press ripple, haptics, the NFC/timer enter, and the enter/exit transition — rendered through
/// the selected profile's theme. The look changes; the behavior does not.
struct LoqinHomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var strategyManager: StrategyManager
  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer

  @Query(sort: [SortDescriptor(\BlockedProfiles.order, order: .forward)])
  private var profiles: [BlockedProfiles]

  @State private var selectedProfileID: UUID?
  @State private var showMenu = false
  @State private var showMore = false
  @State private var activeSheet: LoqinUtilityScreen?
  @State private var showOnboarding = false
  @State private var lockedProfile: BlockedProfiles?
  @State private var reveal: CGFloat = 0
  @State private var isExiting = false
  @State private var breathing = false
  @State private var orbBright = false

  // Press feedback — a ripple + light haptic the moment the finger lands.
  @State private var pressScale: CGFloat = 0
  @State private var pressLocation: CGPoint = .zero
  @State private var isPressing = false
  @State private var pressPulse = 0
  @State private var holdEnterWorkItem: DispatchWorkItem?

  // Scan errors (e.g. an NFC tag that isn't on the unlock list, or doesn't match the tag a
  // session was started with) surface as a native alert rather than in-theme UI — the failure
  // is about the physical tag, not the current world's look.
  @State private var showingScanError = false
  @State private var scanErrorMessage = ""

  private var selectedProfile: BlockedProfiles? {
    if let id = selectedProfileID, let match = profiles.first(where: { $0.id == id }) {
      return match
    }
    return profiles.first
  }

  private var theme: LoqinTheme {
    LoqinTheme(rawValue: selectedProfile?.themeId ?? LoqinTheme.blueHour.rawValue) ?? .blueHour
  }

  private var accent: Color {
    theme.resolveAccent(from: selectedProfile?.themeAccentHex)
  }

  /// Normalized progress through the current transition (0 = start, 1 = end), whether entering
  /// or exiting. The individual themes read this to drive their home/locked transforms + FX.
  private var transitionT: CGFloat {
    isExiting ? (1 - reveal) : reveal
  }

  /// Only Manual + NFC profiles enter on a hold — the deliberate gesture reserved for a session
  /// you can only leave by scanning. NFC, Manual, and Timer profiles keep the simple tap-to-enter.
  private var requiresHoldToEnter: Bool {
    guard let profile = selectedProfile else { return false }
    let strategyId = profile.blockingStrategyId ?? NFCBlockingStrategy.id
    return StrategyManager.getStrategyFromId(id: strategyId).entryGesture == .hold
  }

  private var menuOpen: Bool {
    showMenu || showMore
  }

  private var menuAnimation: Animation {
    reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 0.45)
  }

  private func enterAnimation() -> Animation {
    reduceMotion ? .linear(duration: 0.01) : theme.enterAnimation()
  }

  private func exitAnimation() -> Animation {
    reduceMotion ? .linear(duration: 0.01) : theme.exitAnimation()
  }

  private var exitClearDelay: TimeInterval {
    reduceMotion ? 0.05 : theme.exitDuration + 0.15
  }

  var body: some View {
    ZStack {
      transitionedHome
        .allowsHitTesting(reveal == 0)
        .blur(radius: menuOpen ? 16 : 0)
        .scaleEffect(menuOpen ? 0.985 : 1)
        .brightness(menuOpen ? -0.06 : 0)
        .animation(.easeInOut(duration: 0.45), value: menuOpen)
        .zIndex(homeLayerZIndex)

      transitionedLocked
        .allowsHitTesting(transitionT >= 1)
        .zIndex(lockedLayerZIndex)

      if !reduceMotion {
        theme.transitionFX(accent: accent, t: transitionT, exiting: isExiting)
          .ignoresSafeArea()
          .zIndex(3)
      }

      // Always present rather than conditionally inserted (`if showMenu { ... }`), toggled by
      // opacity instead: an `if`-inserted `GeometryReader`-rooted overlay here reproducibly
      // failed to render *any* content — not even a plain color fill — the moment it appeared
      // alongside the home layer's own animated `blur`/`scaleEffect`/`brightness`, with no crash
      // and no error. Keeping the view permanently in the tree and animating opacity instead
      // sidesteps whatever insertion-time graph issue that was.
      LoqinMenuView(
        selectedProfileID: $selectedProfileID,
        isPresented: showMenu,
        theme: theme,
        accent: accent,
        onSelect: closeMenus,
        onMore: openMore,
        onCancel: closeMenus
      )
      .opacity(showMenu ? 1 : 0)
      .allowsHitTesting(showMenu)
      .animation(menuAnimation, value: showMenu)
      .zIndex(6)

      LoqinMoreView(
        theme: theme,
        accent: accent,
        onBack: showProfileMenu,
        onProfiles: { presentUtility(.profiles) },
        onInsights: { presentUtility(.insights) },
        onSettings: { presentUtility(.settings) }
      )
      .opacity(showMore ? 1 : 0)
      .allowsHitTesting(showMore)
      .accessibilityHidden(!showMore)
      .animation(menuAnimation, value: showMore)
      .zIndex(7)

      // Same always-present-plus-opacity treatment as the menu/more overlays above, and for the
      // same reason: a conditionally-inserted overlay here reproducibly failed to render.
      LoqinProfilesView(theme: theme, accent: accent, onBack: dismissUtility)
        .utilitySheetVisibility(activeSheet == .profiles)

      LoqinInsightsView(theme: theme, accent: accent, onBack: dismissUtility)
        .utilitySheetVisibility(activeSheet == .insights)

      LoqinSettingsView(theme: theme, accent: accent, onBack: dismissUtility)
        .utilitySheetVisibility(activeSheet == .settings)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .preferredColorScheme(theme == .porcelain ? .light : .dark)
    .sensoryFeedback(.impact(weight: .light), trigger: pressPulse)
    .sensoryFeedback(.impact(weight: .medium), trigger: strategyManager.isBlocking) { _, locked in
      locked
    }
    .sheet(isPresented: strategyActionSheetBinding) {
      BlockingStrategyActionView(
        customView: strategyManager.customStrategyView,
        presentationDetents: strategyManager.customStrategyViewPresentationDetents
      )
    }
    .fullScreenCover(isPresented: $showOnboarding) {
      LoqinOnboardingView()
    }
    .onReceive(strategyManager.$errorMessage) { errorMessage in
      guard let message = errorMessage else { return }
      scanErrorMessage = message
      showingScanError = true
    }
    .alert("Can't Unlock", isPresented: $showingScanError) {
      Button("OK", role: .cancel) {
        strategyManager.errorMessage = nil
      }
    } message: {
      Text(scanErrorMessage)
    }
    .onAppear {
      if selectedProfileID == nil {
        selectedProfileID = profiles.first?.id
      }
      strategyManager.loadActiveSession(context: context)
      showOnboarding = profiles.isEmpty
      if !reduceMotion {
        withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
          breathing = true
        }
      }
      if strategyManager.isBlocking {
        lockedProfile = strategyManager.activeSession?.blockedProfile
        reveal = 1
      }
    }
    .onChange(of: profiles) { _, _ in
      if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
        selectedProfileID = profiles.first?.id
      }
      showOnboarding = profiles.isEmpty
    }
    .onChange(of: strategyManager.isBlocking) { _, blocking in
      if blocking {
        isExiting = false
        lockedProfile = strategyManager.activeSession?.blockedProfile
        reveal = 0
        withAnimation(enterAnimation()) {
          reveal = 1
        }
      } else {
        isExiting = true
        withAnimation(exitAnimation()) {
          reveal = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + exitClearDelay) {
          lockedProfile = nil
        }
      }
    }
  }

  /// Most directions crossfade or reveal the locked surface above the home surface. Cobalt's
  /// reverse wipe is the exception: the returning home surface must sit above the locked surface
  /// or it remains hidden until the session view is removed, which reads as a flash.
  private var homeLayerZIndex: Double {
    if isExiting {
      return theme == .cobalt ? 2 : 1
    }
    switch theme {
    case .aperture, .fieldGlass, .porcelain, .blueHour: return 2
    case .aura, .horizon, .cobalt, .redline: return 1
    }
  }

  private var lockedLayerZIndex: Double {
    homeLayerZIndex == 2 ? 1 : 2
  }

  // MARK: - Transition layers

  @ViewBuilder
  private var transitionedHome: some View {
    if reduceMotion {
      homeSurface
    } else {
      theme.homeTransform(homeSurface, t: transitionT, exiting: isExiting)
    }
  }

  @ViewBuilder
  private var transitionedLocked: some View {
    if let profile = lockedProfile {
      if reduceMotion {
        LoqinSessionView(profile: profile, progress: reveal)
          .opacity(transitionT)
      } else {
        theme.lockedTransform(
          LoqinSessionView(profile: profile, progress: reveal),
          t: transitionT,
          exiting: isExiting
        )
      }
    }
  }

  // MARK: - Home surface

  private var homeSurface: some View {
    ZStack {
      themeVisuals
        .id(theme)
        .transition(.opacity)

      Color.clear
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
              guard !isPressing else { return }
              isPressing = true
              if !menuOpen {
                beginPress(at: value.location)
                if requiresHoldToEnter {
                  scheduleHoldEnter()
                }
              }
            }
            .onEnded { value in
              isPressing = false
              cancelHoldEnter()
              if menuOpen {
                closeMenus()
                return
              }
              if !requiresHoldToEnter {
                let dx = value.translation.width
                let dy = value.translation.height
                if dx * dx + dy * dy < 24 * 24 {
                  start()
                }
              }
            }
        )

      theme.pressRipple(accent: accent)
        .scaleEffect(pressScale)
        .opacity(1 - pressScale)
        .position(pressLocation)
        .allowsHitTesting(false)

      VStack(spacing: 8) {
        profileSelector
        Spacer()
        tapHint
          .padding(.bottom, 54)
          .allowsHitTesting(false)
      }
      .loqinTopSafePadding(34)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// The "tap to enter" hint from `docs/design-system.md` — specified from the start but never
  /// actually built. Breathes in sync with the center orb so it reads as part of the same calm
  /// signal rather than a separate label.
  private var tapHint: some View {
    Text(requiresHoldToEnter ? "hold to enter" : "tap to enter")
      .font(.system(size: 11, weight: .semibold))
      .tracking(0.3)
      .foregroundStyle(theme.textTertiary)
      .opacity(breathing ? 0.85 : 0.4)
      .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: breathing)
  }

  /// The theme-specific home visuals — background and centerpiece — swapped as one unit so
  /// switching profiles crossfades cleanly instead of snapping.
  private var themeVisuals: some View {
    ZStack {
      theme.background(
        state: .free,
        accent: accent,
        progress: reveal,
        breathing: breathing
      )
      theme.centerpiece(
        breathing: breathing, bright: orbBright, accent: accent, t: transitionT, exiting: isExiting)
    }
    .animation(.smooth(duration: 0.42), value: theme)
  }

  // MARK: - Profile selector

  private var profileSelector: some View {
    Button {
      withAnimation(menuAnimation) {
        showMore = false
        showMenu.toggle()
      }
    } label: {
      HStack(spacing: 6) {
        Text(selectedProfile?.name ?? "set up a profile")
          .font(theme.menuFont(size: 20))
        Image(systemName: "chevron.down")
          .font(.system(size: 12, weight: .semibold))
          .rotationEffect(.degrees(showMenu ? 180 : 0))
      }
      .padding(.horizontal, 22)
      .padding(.vertical, 13)
      .contentShape(Rectangle())
    }
    .buttonStyle(LoqinPressButtonStyle(accent: accent, restingColor: theme.textPrimary))
  }

  // MARK: - Interaction

  private func beginPress(at location: CGPoint) {
    pressLocation = location
    pressPulse += 1
    DispatchQueue.main.async {
      withAnimation(.easeOut(duration: 0.3)) {
        pressScale = 1
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
      pressScale = 0
    }
  }

  private func start() {
    guard let profile = selectedProfile, !strategyManager.isBlocking else { return }
    if theme == .aura {
      withAnimation(.easeOut(duration: 0.32)) {
        orbBright = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
        withAnimation(.easeInOut(duration: 0.55)) {
          orbBright = false
        }
      }
    }
    // NFC profiles present their scan UI here (scan to enter); sleep/timer start immediately.
    strategyManager.toggleBlocking(context: context, activeProfile: profile)
  }

  private func closeMenus() {
    withAnimation(menuAnimation) {
      showMenu = false
      showMore = false
    }
  }

  private func openMore() {
    withAnimation(menuAnimation) {
      showMenu = false
      showMore = true
    }
  }

  private func showProfileMenu() {
    withAnimation(menuAnimation) {
      showMore = false
      showMenu = true
    }
  }

  private func presentUtility(_ screen: LoqinUtilityScreen) {
    closeMenus()
    if screen == .settings {
      requestAuthorizer.refreshAuthorizationStatus()
    }
    withAnimation(.easeOut(duration: 0.26)) {
      activeSheet = screen
    }
  }

  /// Leaving a utility screen returns to the More menu — the step the user actually came from —
  /// so back reads as one level of the menu stack rather than a jump to the bare home screen.
  private func dismissUtility() {
    withAnimation(.easeOut(duration: 0.26)) {
      activeSheet = nil
    }
    withAnimation(menuAnimation) {
      showMenu = false
      showMore = true
    }
  }

  private func scheduleHoldEnter() {
    cancelHoldEnter()
    let item = DispatchWorkItem {
      self.start()
    }
    holdEnterWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
  }

  private func cancelHoldEnter() {
    holdEnterWorkItem?.cancel()
    holdEnterWorkItem = nil
  }

  private var strategyActionSheetBinding: Binding<Bool> {
    Binding(
      get: { strategyManager.showCustomStrategyView },
      set: { isPresented in
        if !isPresented {
          strategyManager.showCustomStrategyView = false
        }
      }
    )
  }
}

// MARK: - Supporting views

/// Utility destinations reachable from the More menu.
private enum LoqinUtilityScreen: String, Identifiable {
  case profiles
  case insights
  case settings

  var id: String { rawValue }
}
