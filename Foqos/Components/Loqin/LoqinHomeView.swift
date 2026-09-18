import SwiftData
import SwiftUI

/// The loqin home screen. One shared behavior layer — the full-screen tap/hold gesture, the
/// press ripple, haptics, the NFC/timer enter, and the enter/exit transition — rendered through
/// the selected profile's theme. The look changes; the behavior does not.
struct LoqinHomeView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @EnvironmentObject private var strategyManager: StrategyManager
  @EnvironmentObject private var requestAuthorizer: RequestAuthorizer
  @EnvironmentObject private var navigationManager: NavigationManager
  @EnvironmentObject private var ratingManager: RatingManager

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
  /// The pending "tear down the locked surface once the exit animation has played out" work.
  /// Held so a session started *during* that window can cancel it — see `onChange(of:isBlocking)`.
  @State private var lockedClearWorkItem: DispatchWorkItem?
  @State private var breathing = false
  @State private var orbBright = false

  // Press feedback — a ripple + light haptic the moment the finger lands.
  @State private var pressScale: CGFloat = 0
  @State private var pressLocation: CGPoint = .zero
  @State private var isPressing = false
  @State private var pressPulse = 0

  /// Whether a tap on the home surface is currently allowed to start a session.
  ///
  /// The surface is one full-screen transparent layer with a `minimumDistance: 0` drag on it, so a
  /// single tap anywhere begins a real block — for an NFC profile, one you then need the tag to
  /// leave. That is far too eager to have live in the moments around a modal going away: a cover
  /// torn down mid-touch can deliver that touch to whatever is underneath, and underneath
  /// onboarding is exactly this gesture. Finishing first-run profile creation therefore dropped
  /// the user straight into a locked session they never asked for, on a profile they had just
  /// finished describing. Disarming across every dismissal also absorbs an impatient second tap.
  @State private var isEnterArmed = false
  @State private var enterArmWorkItem: DispatchWorkItem?

  /// How long the finger must stay down to enter a hold-to-enter profile.
  private static let holdToEnterDuration: TimeInterval = 0.5

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

  /// True once a countdown session is far enough past its expected end that the engine should be
  /// re-read. A timer session is ended by the device-activity extension, out of process — the
  /// shields come off and the shared session closes without anything notifying this view. Nothing
  /// else here reacts to that, so without this the locked surface and its running clock stay up,
  /// over apps that are no longer blocked, until the app is backgrounded and brought forward
  /// again. This re-evaluates on the session timer's per-second publish.
  private var isCountdownReloadDue: Bool {
    guard let activeSession = strategyManager.activeSession else {
      return false
    }

    return SessionTimeCalculator.isCountdownReloadDue(for: activeSession)
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
        // `lockedProfile == nil` is a safety net, not a nicety: with no locked surface mounted
        // there is nothing else on screen that can take a touch, so the home layer must stay live
        // whatever `reveal` says. Without it, any state where `reveal > 0` outlives the locked
        // surface leaves the whole screen inert — a running session with no way to reach ✕.
        .allowsHitTesting(reveal == 0 || lockedProfile == nil)
        .blur(radius: menuOpen ? 16 : 0)
        .scaleEffect(menuOpen ? 0.985 : 1)
        .brightness(menuOpen ? -0.06 : 0)
        .animation(.easeInOut(duration: 0.45), value: menuOpen)
        .zIndex(homeLayerZIndex)

      transitionedLocked
        // `transitionT` is progress, not presence — on the way *out* it also runs 0 → 1, so the
        // old `transitionT >= 1` turned hit testing back on at the exact moment the surface
        // finished fading away, and `lockedProfile` isn't nil'd until `exitClearDelay` after
        // that. For those ~150ms an invisible session view sat above the home layer and ate the
        // first tap back in. `!isExiting` is what separates "arrived" from "left".
        .allowsHitTesting(lockedProfile != nil && !isExiting && transitionT >= 1)
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
      // Schedule activities registered for a profile that no longer has a schedule (or no longer
      // exists) keep firing on their own. Nothing else calls this any more, so without it here
      // they accumulate and start sessions the user removed.
      strategyManager.cleanUpGhostSchedules(context: context)
      showOnboarding = profiles.isEmpty
      if !reduceMotion {
        withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
          breathing = true
        }
      }
      syncLockedSurface()
      armEnter()
    }
    .onChange(of: showOnboarding) { _, showing in
      // First run ends here. Re-arm only once onboarding is fully gone, so the tap that finished
      // profile creation cannot be the tap that starts a session on it.
      if showing {
        isEnterArmed = false
        enterArmWorkItem?.cancel()
        enterArmWorkItem = nil
      } else {
        armEnter()
      }
    }
    .onChange(of: activeSheet) { _, sheet in
      if sheet == nil { armEnter() }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      armEnter()
      // A session can start or end while this view is suspended — a schedule or timer firing in
      // the device-activity extension, a shortcut, the widget — and none of those deliver an
      // `onChange` here. Re-reading the engine on every foreground is what the legacy HomeView
      // already does, and it is what lets a surface left inconsistent repair itself without the
      // user having to force-quit the app.
      strategyManager.loadActiveSession(context: context)
      syncLockedSurface()
    }
    .onChange(of: isCountdownReloadDue, initial: true) { _, shouldReload in
      guard shouldReload else { return }
      // Deliberately no `syncLockedSurface()`: clearing the session flips `isBlocking`, and that
      // handler already plays the exit properly. Snapping as well would race it.
      strategyManager.loadActiveSession(context: context)
    }
    .onChange(of: profiles) { _, _ in
      if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
        selectedProfileID = profiles.first?.id
      }
      showOnboarding = profiles.isEmpty
    }
    // Tag-to-toggle. A background NFC scan or a QR code opens
    // `https://foqos.app/profile/<id>`, which `foqosApp.onOpenURL` hands to the navigation
    // manager; this is the only place that consumes it. It was left behind in the legacy
    // `HomeView` when this view became the root, which quietly killed the whole feature —
    // scanning a tag launched the app and did nothing.
    .onChange(of: navigationManager.profileId, initial: true) { _, profileId in
      guard let profileId, let link = navigationManager.link else { return }
      strategyManager.toggleSessionFromDeeplink(profileId, url: link, context: context)
      navigationManager.clearNavigation()
    }
    // `https://foqos.app/navigate/<id>` selects a profile without starting it. The legacy home
    // screen opened its start-picker preselected; here the selection *is* the home screen, so
    // pointing it at that profile is the whole action.
    .onChange(of: navigationManager.navigateToProfileId, initial: true) { _, profileId in
      guard let profileId, let id = UUID(uuidString: profileId) else { return }
      if profiles.contains(where: { $0.id == id }) {
        selectedProfileID = id
      }
      navigationManager.clearNavigation()
    }
    .onChange(of: strategyManager.isBlocking) { _, blocking in
      // Any transition supersedes a teardown still queued from the previous one. Starting a
      // session inside the exit window (stop, then tap straight back in — under 1.5s on the
      // slower worlds) used to let that stale timer fire against the *new* session and null out
      // `lockedProfile` while `reveal` was 1: the locked surface unmounted, the home layer was
      // still hit-test-disabled behind it, and the screen went inert with the block running.
      lockedClearWorkItem?.cancel()
      lockedClearWorkItem = nil

      // Entering on a hold takes the home layer's hit testing away while the finger is still
      // down, so the drag that started the session is cancelled and its `onEnded` — the only
      // thing that clears `isPressing` — never runs. Left set, it makes `onChanged` return early
      // forever: once the session ends, the home screen ignores every tap and hold from then on.
      isPressing = false

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
        let clear = DispatchWorkItem {
          // Re-checked at fire time as well as cancelled above: cancellation alone loses the race
          // if the item is already dequeued when the new session lands.
          guard !strategyManager.isBlocking else { return }
          lockedProfile = nil
          lockedClearWorkItem = nil
        }
        lockedClearWorkItem = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + exitClearDelay, execute: clear)
      }
    }
    // Switching straight from one profile to another — a tag or a shortcut hitting
    // `toggleSessionFromBackground` — stops and starts inside a single update, so `isBlocking`
    // goes true → true and the handler above never runs. Watching the session's identity instead
    // catches that case; without it the locked surface keeps rendering the name and world of the
    // profile that just ended, over a session belonging to a different one.
    .onChange(of: strategyManager.activeSession?.id) { _, _ in
      guard strategyManager.isBlocking else { return }
      lockedProfile = strategyManager.activeSession?.blockedProfile
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

  /// Mounted for as long as there is any profile to render, and hidden with opacity rather than
  /// removed — the same treatment the menu and utility overlays above already get, for the same
  /// reason. Inserting this subtree on demand put it in the one situation this file has already
  /// been burned by: a `GeometryReader`-rooted, full-screen layer appearing alongside the home
  /// layer's own animated transforms, which can come up blank. Blank here is not cosmetic — the
  /// session has started and the apps are blocked by the time it mounts, so a layer that fails to
  /// draw reads as "it blocked everything without turning on", with the ✕ nowhere on screen.
  @ViewBuilder
  private var transitionedLocked: some View {
    if let profile = lockedProfile ?? selectedProfile {
      let presenting = lockedProfile != nil
      Group {
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
      .opacity(presenting ? 1 : 0)
      .accessibilityHidden(!presenting)
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
              // No ripple or haptic while disarmed either — feedback for a press that is going
              // to be ignored reads as the app having taken the tap and then done nothing.
              if !menuOpen, isEnterArmed {
                beginPress(at: value.location)
              }
            }
            .onEnded { value in
              isPressing = false
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
        .simultaneousGesture(holdEnterGesture)

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

  /// Re-arms the enter gesture a beat after whatever was covering the home surface has gone. The
  /// delay only has to outlast the dismissal itself; a user who means to enter taps well after it.
  private func armEnter(after delay: TimeInterval = 0.5) {
    enterArmWorkItem?.cancel()
    isEnterArmed = false
    let item = DispatchWorkItem {
      isEnterArmed = true
      enterArmWorkItem = nil
    }
    enterArmWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
  }

  private func start() {
    // Both entry gestures land here — the tap path directly, the hold path through its work item —
    // so this one guard covers both.
    guard isEnterArmed else { return }
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

    // The review prompt counts sessions, and this is the only place one starts from the UI. Its
    // sole caller lived in the legacy `HomeView`, so the prompt could never fire once this view
    // became the root.
    ratingManager.incrementLaunchCount()
  }

  /// Snaps the locked surface to whatever the engine actually reports, with no transition. Used
  /// on appear and on foreground, where there is no animation to play — the user was not watching.
  /// Idempotent, so it is safe to call whenever the two could have drifted apart.
  private func syncLockedSurface() {
    if strategyManager.isBlocking {
      lockedClearWorkItem?.cancel()
      lockedClearWorkItem = nil
      lockedProfile = strategyManager.activeSession?.blockedProfile
      isExiting = false
      reveal = 1
    } else if lockedClearWorkItem == nil {
      // Skipped while a teardown is still queued: that exit is mid-animation and owns `reveal`.
      lockedProfile = nil
      isExiting = false
      reveal = 0
    }
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

  /// Hold-to-enter, for the one strategy that asks for it (manual + nfc). Deliberately a real
  /// `LongPressGesture` rather than a timer armed on touch-down and cancelled from the drag's
  /// `onEnded`, which is what this was: that shape is only correct while `onEnded` is guaranteed to
  /// arrive, and on this screen it is not — a gesture torn up mid-flight by a re-render never ends,
  /// so nothing cancelled the timer and it started a session half a second after the finger had
  /// already lifted. A plain tap became a hold, on the one profile kind you can only leave by
  /// scanning a tag. SwiftUI will not fire a long press that was released early or cancelled, so
  /// the guarantee now comes from the framework instead of from our own bookkeeping.
  private var holdEnterGesture: some Gesture {
    LongPressGesture(minimumDuration: Self.holdToEnterDuration)
      .onEnded { _ in
        guard requiresHoldToEnter, !menuOpen else { return }
        start()
      }
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
