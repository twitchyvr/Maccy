import Foundation

/// Paste transforms allow users to modify clipboard content on-the-fly
/// by typing a command prefix in the search field.
///
/// Type a transform command (e.g., `:json`) in the search field when
/// a clipboard item is selected. The transform is applied to the
/// selected item's text before pasting.
struct PasteTransform {
  let command: String
  let label: String
  let icon: String
  let description: String
  let transform: (String) -> String

  /// All available transforms, shown when user types ":"
  static let all: [PasteTransform] = [
    // Formatting
    PasteTransform(
      command: ":json",
      label: "Pretty JSON",
      icon: "curlybraces",
      description: "Format JSON with indentation"
    ) { text in
      guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
            let result = String(data: pretty, encoding: .utf8) else {
        return text
      }
      return result
    },

    PasteTransform(
      command: ":json1",
      label: "Compact JSON",
      icon: "curlybraces",
      description: "Minify JSON to single line"
    ) { text in
      guard let data = text.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data),
            let compact = try? JSONSerialization.data(withJSONObject: json),
            let result = String(data: compact, encoding: .utf8) else {
        return text
      }
      return result
    },

    // Case transforms
    PasteTransform(
      command: ":upper",
      label: "UPPERCASE",
      icon: "textformat.size.larger",
      description: "Convert to uppercase"
    ) { $0.uppercased() },

    PasteTransform(
      command: ":lower",
      label: "lowercase",
      icon: "textformat.size.smaller",
      description: "Convert to lowercase"
    ) { $0.lowercased() },

    PasteTransform(
      command: ":title",
      label: "Title Case",
      icon: "textformat",
      description: "Capitalize each word"
    ) { $0.capitalized },

    // Whitespace
    PasteTransform(
      command: ":trim",
      label: "Trim Whitespace",
      icon: "scissors",
      description: "Remove leading/trailing whitespace and blank lines"
    ) { text in
      text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    },

    PasteTransform(
      command: ":1line",
      label: "Single Line",
      icon: "arrow.right",
      description: "Collapse to single line (newlines → spaces)"
    ) { text in
      text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    },

    // URL transforms
    PasteTransform(
      command: ":noutm",
      label: "Strip UTM Params",
      icon: "link.badge.plus",
      description: "Remove tracking parameters from URLs"
    ) { text in
      guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
        return text
      }
      let trackingPrefixes = ["utm_", "fbclid", "gclid", "mc_", "ref", "source", "campaign"]
      components.queryItems = components.queryItems?.filter { item in
        !trackingPrefixes.contains(where: { item.name.hasPrefix($0) })
      }
      if components.queryItems?.isEmpty == true {
        components.queryItems = nil
      }
      return components.url?.absoluteString ?? text
    },

    PasteTransform(
      command: ":urldecode",
      label: "URL Decode",
      icon: "link",
      description: "Decode percent-encoded URL"
    ) { $0.removingPercentEncoding ?? $0 },

    PasteTransform(
      command: ":urlencode",
      label: "URL Encode",
      icon: "link",
      description: "Percent-encode for URL"
    ) { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 },

    // Encoding
    PasteTransform(
      command: ":b64enc",
      label: "Base64 Encode",
      icon: "lock",
      description: "Encode text as Base64"
    ) { Data($0.utf8).base64EncodedString() },

    PasteTransform(
      command: ":b64dec",
      label: "Base64 Decode",
      icon: "lock.open",
      description: "Decode Base64 to text"
    ) { text in
      guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
            let decoded = String(data: data, encoding: .utf8) else {
        return text
      }
      return decoded
    },

    // Dev tools
    PasteTransform(
      command: ":escape",
      label: "Escape Special Chars",
      icon: "chevron.left.forwardslash.chevron.right",
      description: "Escape quotes, backslashes, newlines"
    ) { text in
      text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\t", with: "\\t")
    },

    PasteTransform(
      command: ":unescape",
      label: "Unescape",
      icon: "chevron.left.forwardslash.chevron.right",
      description: "Unescape \\n, \\t, \\\", \\\\"
    ) { text in
      text.replacingOccurrences(of: "\\n", with: "\n")
        .replacingOccurrences(of: "\\t", with: "\t")
        .replacingOccurrences(of: "\\\"", with: "\"")
        .replacingOccurrences(of: "\\\\", with: "\\")
    },

    // Text analysis
    PasteTransform(
      command: ":count",
      label: "Character Count",
      icon: "number",
      description: "Replace with character/word/line counts"
    ) { text in
      let chars = text.count
      let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
      let lines = text.components(separatedBy: .newlines).count
      return "\(chars) chars, \(words) words, \(lines) lines"
    },

    PasteTransform(
      command: ":sort",
      label: "Sort Lines",
      icon: "arrow.up.arrow.down",
      description: "Sort lines alphabetically"
    ) { text in
      text.components(separatedBy: .newlines)
        .sorted()
        .joined(separator: "\n")
    },

    PasteTransform(
      command: ":uniq",
      label: "Unique Lines",
      icon: "line.3.horizontal.decrease",
      description: "Remove duplicate lines"
    ) { text in
      var seen = Set<String>()
      return text.components(separatedBy: .newlines)
        .filter { seen.insert($0).inserted }
        .joined(separator: "\n")
    },

    PasteTransform(
      command: ":rev",
      label: "Reverse",
      icon: "arrow.uturn.backward",
      description: "Reverse the text"
    ) { String($0.reversed()) },

    PasteTransform(
      command: ":md2txt",
      label: "Strip Markdown",
      icon: "doc.plaintext",
      description: "Remove Markdown formatting"
    ) { text in
      var result = text
      // Remove headers
      result = result.replacingOccurrences(of: "#{1,6}\\s+", with: "", options: .regularExpression)
      // Remove bold/italic
      result = result.replacingOccurrences(of: "[*_]{1,3}([^*_]+)[*_]{1,3}", with: "$1", options: .regularExpression)
      // Remove inline code
      result = result.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
      // Remove links [text](url) → text
      result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
      // Remove images
      result = result.replacingOccurrences(of: "!\\[([^\\]]*)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
      return result
    },
  ]

  /// Find a transform matching a search query prefix
  static func find(_ query: String) -> PasteTransform? {
    let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
    return all.first { $0.command == lowered }
  }

  /// Check if the query starts with ":" (transform mode)
  static func isTransformQuery(_ query: String) -> Bool {
    query.trimmingCharacters(in: .whitespaces).hasPrefix(":")
  }

  /// Get matching transforms for autocomplete
  static func matches(for query: String) -> [PasteTransform] {
    let lowered = query.lowercased().trimmingCharacters(in: .whitespaces)
    guard lowered.hasPrefix(":") else { return [] }
    if lowered == ":" { return all }
    return all.filter { $0.command.hasPrefix(lowered) }
  }
}
