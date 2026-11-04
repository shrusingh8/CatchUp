// CatchUp — iMessage app extension.
// "What did they just say?" Copy a message, open CatchUp, get the plain-English meaning.
// Apple doesn't let extensions read the conversation, so the clipboard is the bridge.

import UIKit
import Messages

// ponytail: key baked into the app = fine for your own phone, NOT for App Store. Ship a tiny proxy server before publishing.
private let apiKey = "sk-ant-PUT-YOUR-KEY-HERE"

private let accent = UIColor(red: 1.0, green: 0.42, blue: 0.29, alpha: 1)   // warm coral

class MessagesViewController: MSMessagesAppViewController {
    private let bubble = UITextView()          // the message being decoded, styled as an incoming text
    private let button = UIButton(configuration: .filled())
    private let meaning = UILabel()
    private let terms = UILabel()
    private let resultCard = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let title = UILabel()
        title.text = "CatchUp"
        title.font = .systemFont(ofSize: 28, weight: .heavy)
        let subtitle = UILabel()
        subtitle.text = "Copy any message → find out what it actually means."
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel
        subtitle.numberOfLines = 0

        bubble.font = .preferredFont(forTextStyle: .body)
        bubble.backgroundColor = .secondarySystemGroupedBackground
        bubble.layer.cornerRadius = 18
        bubble.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        bubble.isScrollEnabled = false

        button.configuration?.title = "Catch me up"
        button.configuration?.baseBackgroundColor = accent
        button.configuration?.cornerStyle = .capsule
        button.configuration?.buttonSize = .large
        button.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)

        meaning.numberOfLines = 0
        meaning.font = .systemFont(ofSize: 19, weight: .semibold)
        meaning.text = "Long-press a message in the chat, tap Copy, then come back here."
        terms.numberOfLines = 0
        terms.font = .preferredFont(forTextStyle: .callout)
        terms.textColor = .secondaryLabel

        resultCard.backgroundColor = .secondarySystemGroupedBackground
        resultCard.layer.cornerRadius = 20
        let resultStack = UIStackView(arrangedSubviews: [meaning, terms])
        resultStack.axis = .vertical
        resultStack.spacing = 8
        resultStack.translatesAutoresizingMaskIntoConstraints = false
        resultCard.addSubview(resultStack)

        let stack = UIStackView(arrangedSubviews: [title, subtitle, bubble, button, resultCard])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(18, after: subtitle)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            bubble.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            resultStack.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 16),
            resultStack.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -16),
            resultStack.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            resultStack.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -16),
        ])
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        // Grab whatever was just copied (iOS shows an "Allow Paste" prompt).
        if let copied = UIPasteboard.general.string, !copied.isEmpty, copied != bubble.text {
            bubble.text = copied
            translateTapped()
        }
    }

    @objc private func translateTapped() {
        let text = bubble.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        bubble.resignFirstResponder()
        requestPresentationStyle(.expanded)
        button.configuration?.showsActivityIndicator = true
        meaning.text = "Decoding…"
        terms.text = nil
        Task {
            let (m, t) = await translate(text)
            await MainActor.run {
                button.configuration?.showsActivityIndicator = false
                meaning.text = m
                terms.text = t
            }
        }
    }

    // Returns (plain-English meaning, "term — meaning" lines).
    private func translate(_ text: String) async -> (String, String?) {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "claude-opus-5-5",
            "max_tokens": 1024,
            "fallbacks": "default",
            "system": catchUpPrompt,
            "messages": [["role": "user", "content": text]],
            "output_config": ["effort": "low", "format": ["type": "json_schema", "schema": catchUpSchema]],
        ])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return ("Couldn't connect. Check your internet and try again.", nil) }
        if let err = json["error"] as? [String: Any] { return ("Something went wrong: \(err["message"] ?? "unknown error")", nil) }
        if json["stop_reason"] as? String == "refusal" { return ("CatchUp can't translate that one.", nil) }

        // Response may start with thinking blocks; the JSON answer is in the text block.
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let raw = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let parsed = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any]
        else { return ("No translation came back. Try again.", nil) }

        let list = (parsed["terms"] as? [[String: String]] ?? [])
            .map { "\($0["term"] ?? "")  —  \($0["means"] ?? "")" }
            .joined(separator: "\n")
        return (parsed["meaning"] as? String ?? "", list.isEmpty ? nil : list)
    }
}

// Same prompt + schema as the web version (index.html) — keep them in sync.
private let catchUpPrompt = "You decode texting slang, abbreviations and emoji into plain English for someone who isn't fluent in it. 'meaning' = what the sender is actually saying, in one or two casual sentences. 'terms' = each slang word, abbreviation or emoji used and what it means here (empty if none)."
private let catchUpSchema: [String: Any] = [
    "type": "object",
    "properties": [
        "meaning": ["type": "string"],
        "terms": ["type": "array", "items": [
            "type": "object",
            "properties": ["term": ["type": "string"], "means": ["type": "string"]],
            "required": ["term", "means"], "additionalProperties": false,
        ]],
    ],
    "required": ["meaning", "terms"], "additionalProperties": false,
]
