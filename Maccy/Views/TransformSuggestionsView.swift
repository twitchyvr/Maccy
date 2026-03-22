import SwiftUI

/// Shows available paste transforms when the user types ":" in the search field.
/// Each transform is shown as a selectable row with icon, command, and description.
struct TransformSuggestionsView: View {
  let transforms: [PasteTransform]
  let onSelect: (PasteTransform) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 4) {
        Image(systemName: "wand.and.stars")
          .foregroundStyle(.purple)
        Text("Paste Transforms")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)

      Divider()
        .padding(.horizontal, 8)

      ScrollView {
        VStack(spacing: 0) {
          ForEach(Array(transforms.enumerated()), id: \.offset) { _, transform in
            TransformRow(transform: transform, onSelect: onSelect)
          }
        }
      }
      .frame(maxHeight: 300)
    }
    .padding(.vertical, 4)
  }
}

struct TransformRow: View {
  let transform: PasteTransform
  let onSelect: (PasteTransform) -> Void

  @State private var isHovered = false

  var body: some View {
    Button {
      onSelect(transform)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: transform.icon)
          .frame(width: 16)
          .foregroundStyle(.purple)

        Text(transform.command)
          .font(.body.monospaced())
          .foregroundStyle(.primary)

        Text("—")
          .foregroundStyle(.secondary)

        Text(transform.description)
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 5)
      .background(isHovered ? Color.accentColor.opacity(0.15) : .clear)
      .clipShape(RoundedRectangle(cornerRadius: 4))
    }
    .buttonStyle(.plain)
    .onHover { isHovered = $0 }
  }
}
