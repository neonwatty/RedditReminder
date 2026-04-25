import SwiftUI

// MARK: - Sticker Color Palette

enum StickerColors {
  static let background = Color(red: 0.07, green: 0.08, blue: 0.14)
  static let card = Color(red: 0.10, green: 0.11, blue: 0.19)
  static let border = Color(red: 0.27, green: 0.29, blue: 0.40)
  static let gold = Color(red: 0.81, green: 0.60, blue: 0.03)
  static let pink = Color(red: 0.93, green: 0.29, blue: 0.60)
  static let textPrimary = Color(red: 0.95, green: 0.95, blue: 0.95)
  static let textSecondary = Color(red: 0.55, green: 0.56, blue: 0.63)
}

// MARK: - Sticker ViewModifiers

struct StickerCardModifier: ViewModifier {
  var borderColor: Color = StickerColors.border

  func body(content: Content) -> some View {
    content
      .background(StickerColors.card)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(borderColor, lineWidth: 2)
      )
      .shadow(color: borderColor.opacity(0.5), radius: 0, x: 2, y: 2)
  }
}

struct StickerButtonModifier: ViewModifier {
  var bgColor: Color = StickerColors.gold

  func body(content: Content) -> some View {
    content
      .font(.system(size: 12, weight: .heavy))
      .foregroundStyle(.white)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .background(bgColor)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(StickerColors.border, lineWidth: 2)
      )
      .shadow(color: StickerColors.border.opacity(0.5), radius: 0, x: 2, y: 2)
  }
}

struct StickerBadgeModifier: ViewModifier {
  var color: Color = StickerColors.border

  func body(content: Content) -> some View {
    content
      .font(.system(size: 9, weight: .bold))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .stroke(color, lineWidth: 2)
      )
  }
}

struct StickerInputModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(8)
      .background(StickerColors.card)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(StickerColors.border, lineWidth: 2)
      )
  }
}

// MARK: - View Extensions

extension View {
  func stickerCard(borderColor: Color = StickerColors.border) -> some View {
    modifier(StickerCardModifier(borderColor: borderColor))
  }

  func stickerButton(bgColor: Color = StickerColors.gold) -> some View {
    modifier(StickerButtonModifier(bgColor: bgColor))
  }

  func stickerBadge(color: Color = StickerColors.border) -> some View {
    modifier(StickerBadgeModifier(color: color))
  }

  func stickerInput() -> some View {
    modifier(StickerInputModifier())
  }
}
