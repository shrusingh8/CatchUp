// CatchUp — iMessage app extension.
// Flow: long-press a message -> Copy -> open CatchUp in the app drawer -> it auto-pastes & translates.
// (Apple doesn't let extensions read the conversation, so the clipboard is the bridge.)

import UIKit
import Messages

// ponytail: key baked into the app = fine for your own phone, NOT for App Store. Ship a tiny proxy server before publishing.
private let apiKey = "sk-ant-PUT-YOUR-KEY-HERE"

class MessagesViewController: MSMessagesAppViewController {
    private let input = UITextView()
    private let output = UILabel()
    private let button = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        input.font = .preferredFont(forTextStyle: .body)
        input.layer.borderColor = UIColor.separator.cgColor
        input.layer.borderWidth = 1
        input.layer.cornerRadius = 8

        output.numberOfLines = 0
        output.font = .preferredFont(forTextStyle: .body)
        output.text = "Copy a message, then tap Translate."

        button.setTitle("Translate", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [input, button, output])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            input.heightAnchor.constraint(equalToConstant: 70),
        ])
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        // Grab whatever was just copied (iOS will show an "Allow Paste" prompt).
        if let copied = UIPasteboard.general.string, !copied.isEmpty {
            input.text = copied
            translateTapped()
        }
    }

    @objc private func translateTapped() {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input.resignFirstResponder()
        output.text = "Decoding…"
        Task {
            let result = (try? await translate(text)) ?? "Couldn't reach the translator. Check your key / connection."
            await MainActor.run { output.text = result }
        }
    }

    private func translate(_ text: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "claude-opus-5-5",
            "max_tokens": 1024,
            "output_config": ["effort": "low"],
            "fallbacks": "default",
            "system": "You translate texting slang, abbreviations and emoji into plain English. Reply with: the plain-English meaning in one or two sentences, then a short bullet list of each slang term and what it means. No preamble.",
            "messages": [["role": "user", "content": text]],
        ])

        let (data, _) = try await URLSession.shared.data(for: req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if let err = json["error"] as? [String: Any] { return "API error: \(err["message"] ?? "unknown")" }
        if json["stop_reason"] as? String == "refusal" { return "The model declined to translate that one." }
        // Response can include thinking blocks first; take the text block.
        let blocks = json["content"] as? [[String: Any]] ?? []
        return blocks.first { $0["type"] as? String == "text" }?["text"] as? String ?? "No translation returned."
    }
}
