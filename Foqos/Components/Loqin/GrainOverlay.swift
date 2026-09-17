import CoreGraphics
import SwiftUI

/// Subtle film grain. Breaks up banding in the dark gradients and gives the field a tactile,
/// filmic texture — one of the biggest "premium vs. cheap" signals. The noise is generated once
/// as a small grayscale image and tiled, so it costs almost nothing at render time.
enum FieldGrain {
  /// Shared, lazily-built grayscale noise tile.
  static let image: CGImage = makeNoise()

  private static func makeNoise() -> CGImage {
    let side = 256
    let bytesPerPixel = 4
    guard let ctx = CGContext(
      data: nil,
      width: side,
      height: side,
      bitsPerComponent: 8,
      bytesPerRow: side * bytesPerPixel,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      fatalError("Unable to create grain context")
    }
    guard let data = ctx.data else {
      fatalError("Grain context has no backing data")
    }
    let pixels = data.assumingMemoryBound(to: UInt8.self)
    for i in 0..<(side * side) {
      let value = UInt8.random(in: 0...255)
      let offset = i * bytesPerPixel
      pixels[offset] = value
      pixels[offset + 1] = value
      pixels[offset + 2] = value
      pixels[offset + 3] = 255
    }
    guard let image = ctx.makeImage() else {
      fatalError("Unable to make grain image")
    }
    return image
  }
}

/// A full-surface noise overlay. Place it as the topmost layer of a background so the grain
/// reads as "on the lens", sitting over both the photo and the scrims.
struct GrainOverlay: View {
  var opacity: Double = 0.04

  var body: some View {
    Image(decorative: FieldGrain.image, scale: 1)
      .resizable(resizingMode: .tile)
      .blendMode(.overlay)
      .opacity(opacity)
      .allowsHitTesting(false)
  }
}
