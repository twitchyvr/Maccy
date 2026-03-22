import KeyboardShortcuts
import SwiftUI

struct PreviewItemView: View {
  var item: HistoryItemDecorator

  @ViewBuilder
  func previewImage(content: () -> some View) -> some View {
    content()
      .aspectRatio(contentMode: .fit)
      .clipShape(.rect(cornerRadius: 5))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if item.hasImage {
        AsyncView<NSImage?, _, _> {
          return await item.asyncGetPreviewImage()
        } content: { image in
          if let image = image {
            previewImage {
              Image(nsImage: image)
                .resizable()
            }
          } else {
            previewImage {
              ZStack {
                Color.gray.opacity(0.3)
                  .frame(
                    idealWidth: HistoryItemDecorator.previewImageSize.width,
                    idealHeight: HistoryItemDecorator.previewImageSize.height
                  )
                Image(systemName: "photo.badge.exclamationmark")
                  .symbolRenderingMode(.multicolor)
                  .frame(alignment: .center)
              }
            }
          }
        } placeholder: {
          previewImage {
            ZStack {
              Color.gray.opacity(0.3)
                .frame(
                  idealWidth: HistoryItemDecorator.previewImageSize.width,
                  idealHeight: HistoryItemDecorator.previewImageSize.height
                )
              ProgressView()
                .frame(alignment: .center)
            }
          }
        }
      } else {
        ScrollView {
          Text(item.text)
            .font(.body)
        }
      }

      Spacer(minLength: 0)

      Divider()
        .padding(.vertical)

      // Category badge with color swatch
      if !item.item.category.isEmpty {
        HStack(spacing: 5) {
          if let category = ContentCategory(rawValue: item.item.category) {
            Image(systemName: category.icon)
              .foregroundStyle(.purple)
          }
          Text(item.item.category)
            .font(.caption.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.purple.opacity(0.12))
            .clipShape(Capsule())

          // If it's a color, show a large swatch
          if item.item.category == ContentCategory.color.rawValue {
            if let swatch = ColorImage.from(item.title) {
              Image(nsImage: swatch)
                .resizable()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                  RoundedRectangle(cornerRadius: 4)
                    .stroke(.secondary.opacity(0.3), lineWidth: 1)
                )
            }
          }
        }
        .padding(.bottom, 4)
      }

      // Content stats
      if let text = item.item.text, !text.isEmpty {
        HStack(spacing: 8) {
          Label("\(text.count)", systemImage: "character.cursor.ibeam")
          Label("\(text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count)", systemImage: "text.word.spacing")
          Label("\(text.components(separatedBy: .newlines).count)", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.bottom, 4)
      }

      if let application = item.application {
        HStack(spacing: 3) {
          Text("Application", tableName: "PreviewItemView")
          AppImageView(
            appImage: item.applicationImage,
            size: NSSize(width: 11, height: 11)
          )
          Text(application)
        }
      }

      HStack(spacing: 3) {
        Text("FirstCopyTime", tableName: "PreviewItemView")
        Text(item.item.firstCopiedAt, style: .date)
        Text(item.item.firstCopiedAt, style: .time)
      }

      HStack(spacing: 3) {
        Text("LastCopyTime", tableName: "PreviewItemView")
        Text(item.item.lastCopiedAt, style: .date)
        Text(item.item.lastCopiedAt, style: .time)
      }

      HStack(spacing: 3) {
        Text("NumberOfCopies", tableName: "PreviewItemView")
        Text(String(item.item.numberOfCopies))
      }
    }
    .controlSize(.small)
  }
}
