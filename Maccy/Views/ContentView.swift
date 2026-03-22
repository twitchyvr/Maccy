import SwiftData
import SwiftUI

struct ContentView: View {
  @State private var appState = AppState.shared
  @State private var modifierFlags = ModifierFlags()
  @State private var scenePhase: ScenePhase = .background
  @State private var suggestion: SmartSuggestion?
  @State private var suggestionDismissed = false

  @FocusState private var searchFocused: Bool

  private var transformMatches: [PasteTransform] {
    PasteTransform.matches(for: appState.history.searchQuery)
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

              // Transform suggestions (shown when typing ":")
              if !transformMatches.isEmpty {
                TransformSuggestionsView(transforms: transformMatches) { transform in
                  applyTransform(transform)
                }
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
