import SwiftData
import SwiftUI

class NFCBlockingStrategy: BlockingStrategy {
  static var id: String = "NFCBlockingStrategy"

  var name: String = "NFC Tags"
  var description: String = "Start by scanning an NFC tag. To stop, scan the same tag again."
  var iconAssetName: String = "NFCStickerLogo"
  var color: Color = .yellow
  var pickerCategory: BlockingStrategyPickerCategory = .mostPopular

  var usesNFC: Bool = true
  var requiresSameCodeToStop: Bool = true

  var onSessionCreation: ((SessionStatus) -> Void)?
  var onErrorMessage: ((String) -> Void)?

  private let nfcScanner: NFCScannerUtil = NFCScannerUtil()
  private let appBlocker: AppBlockerUtil = AppBlockerUtil()

  func getIdentifier() -> String {
    return NFCBlockingStrategy.id
  }

  func startBlocking(
    context: ModelContext,
    profile: BlockedProfiles,
    forceStart: Bool?
  ) -> (any View)? {
    nfcScanner.onTagScanned = { tag in
      // Session before shield — see ManualBlockingStrategy for why the order matters.
      let tag = tag.url ?? tag.id
      let activeSession =
        BlockedProfileSession
        .createSession(
          in: context,
          withTag: tag,
          withProfile: profile,
          forceStart: forceStart ?? false
        )

      self.appBlocker.activateRestrictions(for: BlockedProfiles.getSnapshot(for: profile))
      self.onSessionCreation?(.started(activeSession))
    }

    nfcScanner.onError = { message in self.onErrorMessage?(message) }
    nfcScanner.scan(profileName: profile.name)

    return nil
  }

  func stopBlocking(
    context: ModelContext,
    session: BlockedProfileSession
  ) -> (any View)? {
    nfcScanner.onTagScanned = { tag in
      let tag = tag.url ?? tag.id

      if session.blockedProfile.hasPhysicalUnblockItem(ofType: .nfc) {
        if !session.blockedProfile.canUnblock(withCode: tag, type: .nfc) {
          self.onErrorMessage?(
            "This tag isn't one of the unlock tags added to this profile."
          )
          return
        }
      } else if !session.forceStarted && session.tag != tag {
        // No physical unblock tag - must use original session tag (unless force started)
        self.onErrorMessage?(
          "That's not the tag you started with. Scan the same tag again to exit."
        )
        return
      }

      session.endSession()
      try? context.save()
      self.appBlocker.deactivateRestrictions()

      self.onSessionCreation?(.ended(session.blockedProfile))
    }

    nfcScanner.onError = { message in self.onErrorMessage?(message) }
    nfcScanner.scan(profileName: session.blockedProfile.name, verb: "exit")

    return nil
  }
}
