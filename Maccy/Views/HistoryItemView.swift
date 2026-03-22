import Defaults
import SwiftUI

struct HistoryItemView: View {
  @Bindable var item: HistoryItemDecorator
  var previous: HistoryItemDecorator?
  var next: HistoryItemDecorator?
  var index: Int

  private var visualIndex: Int? {
    if appState.navigator.isMultiSelectInProgress && item.selectionIndex >= 0 {
      return item.selectionIndex
    }
    return nil
  }

  private var selectionAppearance: SelectionAppearance {
    let previousSelected = previous?.isSelected ?? false
    let nextSelected = next?.isSelected ?? false
    switch (previousSelected, nextSelected) {
    case (true, false):
      return .topConnection
    case (false, true):
      return .bottomConnection
    case (true, true):
      return .topBottomConnection
    default:
      return .none
    }
  }

  /// Relative time label: "2m", "1h", "3d"
  private var timeAgo: String? {
    let seconds = -item.item.lastCopiedAt.timeIntervalSinceNow
    if seconds < 60 { return nil } // Too recent, skip
    if seconds < 3600 { return "\(Int(seconds / 60))m" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h" }
    return "\(Int(seconds / 86400))d"
  }

  /// Category icon from auto-detection
  private var categoryIcon: String? {
    guard !item.item.category.isEmpty,
          let category = ContentCategory(rawValue: item.item.category),
          category != .text else { return nil }
    return category.icon
  }

  @Default(.showItemMetadata) private var showMetadata
  @Environment(AppState.self) private var appState

  var body: some View {
    ListItemView(
      id: item.id,
      selectionId: item.id,
      appIcon: item.applicationImage,
      image: item.thumbnailImage,
      accessoryImage: item.thumbnailImage != nil ? nil : ColorImage.from(item.title),
      attributedTitle: item.attributedTitle,
      shortcuts: item.shortcuts,
      isSelected: item.isSelected,
      selectionIndex: visualIndex,
      selectionAppearance: selectionAppearance
    ) {
      HStack(spacing: 4) {
        // Category icon
        if showMetadata, let icon = categoryIcon {
          Image(systemName: icon)
            .font(.caption2)
            .foregroundStyle(item.isSelected ? .white.opacity(0.7) : .secondary)
        }

        Text(verbatim: item.title)

        if showMetadata {
          Spacer(minLength: 0)

          // Copy count badge (only shown for items copied 2+ times)
          if item.item.numberOfCopies > 1 {
            Text("\(item.item.numberOfCopies)×")
              .font(.caption2.monospacedDigit())
              .foregroundStyle(item.isSelected ? .white.opacity(0.7) : .secondary)
          }

          // Relative time
          if let timeAgo {
            Text(timeAgo)
              .font(.caption2.monospacedDigit())
              .foregroundStyle(item.isSelected ? .white.opacity(0.6) : .secondary.opacity(0.6))
          }
        }
      }
    }
    .onAppear {
      item.ensureThumbnailImage()
    }
    .onTapGesture {
      if NSEvent.modifierFlags.contains(.command) && appState.multiSelectionEnabled {
        appState.navigator.addToSelection(item: item)
      } else {
        Task {
          appState.history.select(item)
        }
      }
    }
  }
}
