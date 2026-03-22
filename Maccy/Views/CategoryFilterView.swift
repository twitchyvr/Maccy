import SwiftUI

struct CategoryFilterView: View {
  @Binding var selectedCategory: ContentCategory?
  let categories: [ContentCategory: Int]

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        FilterChip(
          label: "All",
          icon: "tray.full",
          count: categories.values.reduce(0, +),
          isSelected: selectedCategory == nil
        ) {
          selectedCategory = nil
        }

        ForEach(sortedCategories, id: \.0) { category, count in
          FilterChip(
            label: category.rawValue,
            icon: category.icon,
            count: count,
            isSelected: selectedCategory == category
          ) {
            selectedCategory = selectedCategory == category ? nil : category
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
  }

  private var sortedCategories: [(ContentCategory, Int)] {
    categories
      .filter { $0.value > 0 }
      .sorted { $0.value > $1.value }
  }
}

struct FilterChip: View {
  let label: String
  let icon: String
  let count: Int
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: icon)
          .font(.caption2)
        Text(label)
          .font(.caption)
        Text("\(count)")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(isSelected ? Color.accentColor : Color.clear)
      .foregroundStyle(isSelected ? .white : .primary)
      .clipShape(Capsule())
      .overlay(
        Capsule()
          .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}
