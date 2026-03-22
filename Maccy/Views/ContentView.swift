import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var suggestion: SmartSuggestion?
  @State private var suggestionDismissed = false
  @State private var aiProcessing = false

  @FocusState private var searchFocused: Bool

  private var transformMatches: [PasteTransform] {
    PasteTransform.matches(for: appState.history.searchQuery)
  }

  /// Detect `:ai <instruction>` queries
  private var isAIQuery: Bool {
    let q = appState.history.searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
    return q.hasPrefix(":ai ") && q.count > 4
  }

  private var aiInstruction: String {
    let q = appState.history.searchQuery.trimmingCharacters(in: .whitespaces)
    guard q.lowercased().hasPrefix(":ai ") else { return "" }
    return String(q.dropFirst(4)).trimmingCharacters(in: .whitespaces)
  }

  var body: some View {
    ZStack {
      if #available(macOS 26.0, *) {
        GlassEffectView()
      } else {
        VisualEffectView()
      }

      KeyHandlingView(searchQuery: $appState.history.searchQuery, searchFocused: $searchFocused) {
        VStack(spacing: 0) {
          SlideoutView(controller: appState.preview) {
            HeaderView(
              controller: appState.preview,
              searchFocused: $searchFocused
            )

            VStack(alignment: .leading, spacing: 0) {
              // Smart suggestion banner
              if let suggestion, !suggestionDismissed {
                SmartSuggestionView(
                  suggestion: suggestion,
                  onAction: { handleSuggestionAction(suggestion) },
                  onDismiss: { suggestionDismissed = true }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 4)
              }

              // AI processing indicator
              if aiProcessing {
                HStack(spacing: 8) {
                  ProgressView()
                    .controlSize(.small)
                  Text("Claude is transforming...")
                    .font(.caption)
                    .foregroundStyle(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .transition(.opacity)
              }

              // Transform suggestions (shown when typing ":")
              if !transformMatches.isEmpty && !isAIQuery {
                TransformSuggestionsView(transforms: transformMatches) { transform in
                  applyTransform(transform)
                }
                .transition(.opacity)
              }

              // AI transform hint
              if isAIQuery {
                HStack(spacing: 6) {
                  Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                  Text("Press Return to send to Claude: \"\(aiInstruction)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.purple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 6)
                .transition(.opacity)
              }

              HistoryListView(
                searchQuery: $appState.history.searchQuery,
                searchFocused: $searchFocused
              )

              FooterView(footer: appState.footer)
            }
            .animation(.default.speed(3), value: appState.history.items)
            .animation(
              .default.speed(3),
              value: appState.history.pasteStack?.id
            )
            .padding(.horizontal, Popup.horizontalPadding)
            .onAppear {
              searchFocused = true
            }
            .onMouseMove {
              appState.navigator.isKeyboardNavigating = false
            }
          } slideout: {
            SlideoutContentView()
          }
          .frame(minHeight: 0)
          .layoutPriority(1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .task {
        try? await appState.history.load()
        appState.onAITransform = { [self] in
          applyAITransform()
        }
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase == .active && !suggestionDismissed {
        suggestion = SmartSuggestion.generate(from: appState.history.items)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: appState.searchVisible)
    .environment(appState)
    .environment(modifierFlags)
    .environment(\.scenePhase, scenePhase)
    // FloatingPanel is not a scene, so let's implement custom scenePhase..
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .active
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) {
      if let window = $0.object as? NSWindow,
         let bundleIdentifier = Bundle.main.bundleIdentifier,
         window.identifier == NSUserInterfaceItemIdentifier(bundleIdentifier) {
        scenePhase = .background
      }
    }
  }

  private func applyTransform(_ transform: PasteTransform) {
    guard let selectedItem = appState.navigator.leadHistoryItem else { return }
    guard let text = selectedItem.item.text else { return }

    let transformed = transform.transform(text)
    appState.history.searchQuery = ""
    appState.popup.close()
    Task { @MainActor in
      Clipboard.shared.copy(transformed)
      Clipboard.shared.paste()
    }
  }

  private func applyAITransform() {
    guard let selectedItem = appState.navigator.leadHistoryItem else { return }
    guard let text = selectedItem.item.text else { return }
    let instruction = aiInstruction
    guard !instruction.isEmpty else { return }

    aiProcessing = true
    appState.history.searchQuery = ""

    Task {
      let result = await AITransform.shared.transform(text: text, instruction: instruction)
      await MainActor.run {
        aiProcessing = false
        appState.popup.close()
        Clipboard.shared.copy(result)
        Clipboard.shared.paste()
      }
    }
  }

  private func handleSuggestionAction(_ suggestion: SmartSuggestion) {
    switch suggestion.type {
    case .pinSuggestion(let title):
      if let item = appState.history.items.first(where: { $0.title == title }) {
        appState.history.togglePin(item)
      }
      suggestionDismissed = true
    default:
      suggestionDismissed = true
    }
  }
}

#Preview {
  ContentView()
    .environment(\.locale, .init(identifier: "en"))
    .modelContainer(Storage.shared.container)
}
