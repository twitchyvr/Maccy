import Charts
import Defaults
import SwiftData
import SwiftUI

struct InsightsView: View {
  @Query private var items: [HistoryItem]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        overviewCards
        categoryChart
        appUsageChart
        hourlyActivityChart
        topCopiedItems
      }
      .padding()
    }
    .frame(minWidth: 500, minHeight: 600)
  }

  // MARK: - Overview Cards

  private var overviewCards: some View {
    HStack(spacing: 12) {
      StatCard(
        title: "Total Items",
        value: "\(items.count)",
        icon: "doc.on.clipboard",
        color: .blue
      )
      StatCard(
        title: "Total Copies",
        value: "\(items.reduce(0) { $0 + $1.numberOfCopies })",
        icon: "document.on.document",
        color: .green
      )
      StatCard(
        title: "Duplicate Rate",
        value: duplicateRateText,
        icon: "arrow.2.squarepath",
        color: .orange
      )
      StatCard(
        title: "Apps Used",
        value: "\(uniqueApps.count)",
        icon: "square.grid.2x2",
        color: .purple
      )
    }
  }

  // MARK: - Category Breakdown

  private var categoryChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Content Types")
        .font(.headline)

      Chart(categoryData, id: \.category) { entry in
        SectorMark(
          angle: .value("Count", entry.count),
          innerRadius: .ratio(0.5),
          angularInset: 1.5
        )
        .foregroundStyle(by: .value("Category", entry.category))
        .cornerRadius(4)
      }
      .frame(height: 200)
    }
    .padding()
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - App Usage

  private var appUsageChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Copied From")
        .font(.headline)

      Chart(appData.prefix(8), id: \.app) { entry in
        BarMark(
          x: .value("Copies", entry.count),
          y: .value("App", entry.app)
        )
        .foregroundStyle(.blue.gradient)
        .cornerRadius(4)
      }
      .frame(height: CGFloat(min(appData.count, 8) * 32 + 20))
    }
    .padding()
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Hourly Activity

  private var hourlyActivityChart: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Activity by Hour")
        .font(.headline)

      Chart(hourlyData, id: \.hour) { entry in
        BarMark(
          x: .value("Hour", entry.hourLabel),
          y: .value("Copies", entry.count)
        )
        .foregroundStyle(.green.gradient)
        .cornerRadius(2)
      }
      .frame(height: 150)
    }
    .padding()
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Top Copied

  private var topCopiedItems: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Most Copied")
        .font(.headline)

      ForEach(Array(topItems.enumerated()), id: \.offset) { index, item in
        HStack(spacing: 10) {
          Text("#\(index + 1)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 24)

          if let category = ContentCategory(rawValue: item.category) {
            Image(systemName: category.icon)
              .foregroundStyle(.secondary)
              .frame(width: 16)
          }

          Text(item.title.isEmpty ? "(image)" : item.title)
            .lineLimit(1)
            .truncationMode(.tail)

          Spacer()

          Text("\(item.numberOfCopies)×")
            .font(.caption.monospacedDigit().bold())
            .foregroundStyle(.blue)
        }
        .padding(.vertical, 4)

        if index < topItems.count - 1 {
          Divider()
        }
      }
    }
    .padding()
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // MARK: - Computed Data

  private var uniqueApps: [String] {
    Array(Set(items.compactMap { $0.application }))
  }

  private var duplicateRateText: String {
    let totalCopies = items.reduce(0) { $0 + $1.numberOfCopies }
    guard totalCopies > 0 else { return "0%" }
    let duplicates = totalCopies - items.count
    let rate = Double(duplicates) / Double(totalCopies) * 100
    return String(format: "%.0f%%", rate)
  }

  private var categoryData: [(category: String, count: Int)] {
    var counts: [String: Int] = [:]
    for item in items {
      let cat = item.category.isEmpty ? "Text" : item.category
      counts[cat, default: 0] += 1
    }
    return counts.map { (category: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  private var appData: [(app: String, count: Int)] {
    var counts: [String: Int] = [:]
    for item in items {
      let app = item.application.flatMap { bundle in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)?
          .deletingPathExtension().lastPathComponent
      } ?? "Unknown"
      counts[app, default: 0] += 1
    }
    return counts.map { (app: $0.key, count: $0.value) }
      .sorted { $0.count > $1.count }
  }

  private var hourlyData: [(hour: Int, hourLabel: String, count: Int)] {
    var counts = Array(repeating: 0, count: 24)
    let calendar = Calendar.current
    for item in items {
      let hour = calendar.component(.hour, from: item.lastCopiedAt)
      counts[hour] += 1
    }
    return (0..<24).map { hour in
      let label = hour == 0 ? "12a" : hour < 12 ? "\(hour)a" : hour == 12 ? "12p" : "\(hour - 12)p"
      return (hour: hour, hourLabel: label, count: counts[hour])
    }
  }

  private var topItems: [HistoryItem] {
    items
      .filter { $0.numberOfCopies > 1 }
      .sorted { $0.numberOfCopies > $1.numberOfCopies }
      .prefix(10)
      .map { $0 }
  }
}

// MARK: - Stat Card

struct StatCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.title2)
        .foregroundStyle(color)

      Text(value)
        .font(.title2.bold().monospacedDigit())

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(.quaternary.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}
