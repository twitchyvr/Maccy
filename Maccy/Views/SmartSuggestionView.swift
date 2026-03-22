import SwiftUI

/// A non-intrusive suggestion banner shown at the top of the clipboard list.
/// Provides contextual tips based on user behavior patterns.
struct SmartSuggestionView: View {
  let suggestion: SmartSuggestion
  let onAction: () -> Void
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: suggestion.icon)
        .font(.caption)
        .foregroundStyle(.white)
        .frame(width: 20, height: 20)
        .background(suggestion.color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 5))

      Text(suggestion.message)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer()

      if let actionLabel = suggestion.actionLabel {
        Button(actionLabel) { onAction() }
          .font(.caption.bold())
          .buttonStyle(.borderless)
          .foregroundStyle(suggestion.color)
      }

      Button {
        onDismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(suggestion.color.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .padding(.horizontal, 6)
  }
}

struct SmartSuggestion: Identifiable, Equatable {
  let id = UUID()
  let icon: String
  let message: String
  let actionLabel: String?
  let color: Color
  let type: SuggestionType

  enum SuggestionType: Equatable {
    case pinSuggestion(itemTitle: String)
    case tip(String)
    case duplicateAlert
  }

  static func == (lhs: SmartSuggestion, rhs: SmartSuggestion) -> Bool {
    lhs.id == rhs.id
  }

  /// Generate a contextual suggestion based on current clipboard state
  @MainActor
  static func generate(from items: [HistoryItemDecorator]) -> SmartSuggestion? {
    // Suggest pinning items copied 5+ times that aren't already pinned
    if let frequent = items.first(where: { $0.item.numberOfCopies >= 5 && $0.isUnpinned }) {
      let title = frequent.title.prefix(30)
      return SmartSuggestion(
        icon: "pin",
        message: "You've copied \"\(title)\" \(frequent.item.numberOfCopies) times. Pin it?",
        actionLabel: "Pin",
        color: .orange,
        type: .pinSuggestion(itemTitle: frequent.title)
      )
    }

    // Tip: transform commands
    if items.count > 10 {
      let tips: [SmartSuggestion] = [
        SmartSuggestion(
          icon: "wand.and.stars",
          message: "Type : in search for paste transforms — :json, :trim, :upper and more",
          actionLabel: nil,
          color: .purple,
          type: .tip("transforms")
        ),
        SmartSuggestion(
          icon: "rectangle.on.rectangle",
          message: "⌘+Click to select multiple items, then paste them one by one",
          actionLabel: nil,
          color: .blue,
          type: .tip("multiselect")
        ),
        SmartSuggestion(
          icon: "magnifyingglass",
          message: "Search by app name (\"Chrome\") or type (\"URL\", \"Code\")",
          actionLabel: nil,
          color: .green,
          type: .tip("search")
        ),
      ]
      // Rotate tips based on item count to show different ones
      return tips[items.count % tips.count]
    }

    return nil
  }
}
