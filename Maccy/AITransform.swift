import Foundation

/// Calls the Claude API to transform clipboard text with a natural language instruction.
/// Used by the `:ai <instruction>` paste transform in the search field.
///
/// Requires ANTHROPIC_API_KEY environment variable or ~/. anthropic/api_key file.
actor AITransform {
  static let shared = AITransform()

  private var apiKey: String? {
    // Check environment first
    if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"], !key.isEmpty {
      return key
    }
    // Fall back to file
    let keyFile = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".anthropic/api_key")
    return try? String(contentsOf: keyFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Transform text using Claude with a natural language instruction.
  /// Returns the transformed text, or an error message if something fails.
  func transform(text: String, instruction: String) async -> String {
    guard let key = apiKey else {
      return "(AI transform requires ANTHROPIC_API_KEY environment variable or ~/.anthropic/api_key file)"
    }

    let requestBody: [String: Any] = [
      "model": "claude-sonnet-4-20250514",
      "max_tokens": 4096,
      "system": "You are a clipboard text transformer. Apply the user's instruction to the provided text. Return ONLY the transformed result — no preamble, no explanation, no markdown fences unless the content itself is code. Be precise and concise.",
      "messages": [
        [
          "role": "user",
          "content": "\(instruction)\n\nHere is the text to work with:\n\n\(text)"
        ]
      ]
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
      return "(Failed to serialize request)"
    }

    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "content-type")
    request.setValue(key, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.httpBody = jsonData
    request.timeoutInterval = 30

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        return "(Invalid response from Claude API)"
      }

      guard httpResponse.statusCode == 200 else {
        let body = String(data: data, encoding: .utf8) ?? "unknown error"
        return "(Claude API error \(httpResponse.statusCode): \(body))"
      }

      guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let firstBlock = content.first,
            let resultText = firstBlock["text"] as? String else {
        return "(Failed to parse Claude API response)"
      }

      return resultText
    } catch {
      return "(AI transform error: \(error.localizedDescription))"
    }
  }
}
