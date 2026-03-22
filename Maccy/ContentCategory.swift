import AppKit
import Foundation

enum ContentCategory: String, CaseIterable, Identifiable, Codable {
  case url = "URL"
  case code = "Code"
  case email = "Email"
  case color = "Color"
  case filePath = "File Path"
  case phoneNumber = "Phone"
  case number = "Number"
  case image = "Image"
  case file = "File"
  case text = "Text"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .url: return "link"
    case .code: return "chevron.left.forwardslash.chevron.right"
    case .email: return "envelope"
    case .color: return "paintpalette"
    case .filePath: return "folder"
    case .phoneNumber: return "phone"
    case .number: return "number"
    case .image: return "photo"
    case .file: return "doc"
    case .text: return "doc.text"
    }
  }

  static func detect(item: HistoryItem) -> ContentCategory {
    if item.image != nil { return .image }
    if !item.fileURLs.isEmpty { return .file }

    guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines),
          !text.isEmpty else {
      return .text
    }

    // Order matters — most specific first

    // Color: hex codes, rgb(), hsl()
    if Self.matches(text, pattern: "^#([0-9a-fA-F]{3,8})$") ||
       Self.matches(text, pattern: "^rgba?\\(") ||
       Self.matches(text, pattern: "^hsla?\\(") {
      return .color
    }

    // Email
    if Self.matches(text, pattern: "^[\\w.+-]+@[\\w-]+(\\.[\\w-]+)+$") {
      return .email
    }

    // URL
    if Self.matches(text, pattern: "^https?://") ||
       Self.matches(text, pattern: "^www\\.") {
      return .url
    }

    // File path
    if text.hasPrefix("/") || text.hasPrefix("~/") || text.hasPrefix("file://") {
      return .filePath
    }

    // Phone number (various formats)
    if Self.matches(text, pattern: "^[+]?[\\d\\s\\-().]{7,20}$") &&
       text.filter({ $0.isNumber }).count >= 7 {
      return .phoneNumber
    }

    // Pure number
    if Double(text.replacingOccurrences(of: ",", with: "")) != nil {
      return .number
    }

    // Code detection — heuristic based on common patterns
    if detectCode(text) {
      return .code
    }

    return .text
  }

  private static func matches(_ text: String, pattern: String) -> Bool {
    return text.range(of: pattern, options: .regularExpression) != nil
  }

  private static func detectCode(_ text: String) -> Bool {
    let codeIndicators = [
      "func ", "class ", "struct ", "enum ", "import ",  // Swift
      "function ", "const ", "let ", "var ",              // JS/TS
      "def ", "return ", "if __name__",                   // Python
      "public ", "private ", "protected ",                // Java/C#/C++
      "=> ", "-> ",                                       // Arrows
    ]

    let symbolIndicators: [(String, Int)] = [
      ("{", 2), ("}", 2),                                 // Braces
      ("()", 1), ("[];", 1),                              // Brackets
      ("==", 1), ("!=", 1), ("&&", 1), ("||", 1),        // Operators
    ]

    // If it has multiple lines with indentation, likely code
    let lines = text.components(separatedBy: .newlines)
    let indentedLines = lines.filter { $0.hasPrefix("  ") || $0.hasPrefix("\t") }
    if lines.count >= 3 && indentedLines.count >= 2 {
      return true
    }

    // Check for code keywords
    for indicator in codeIndicators {
      if text.contains(indicator) { return true }
    }

    // Check for code symbols (need multiple hits)
    var symbolScore = 0
    for (symbol, weight) in symbolIndicators {
      if text.contains(symbol) { symbolScore += weight }
    }

    return symbolScore >= 3
  }
}
