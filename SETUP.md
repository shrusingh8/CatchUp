# CatchUp setup

Needs a Mac with Xcode (iMessage extensions can't be built on Windows).

1. Xcode → File → New → Project → iOS → **iMessage App** → name it `CatchUp`.
2. Replace the generated `MessagesViewController.swift` (in the MessagesExtension folder) with this one.
3. Put your Anthropic API key in `apiKey` (get one at console.anthropic.com).
4. Plug in your iPhone, pick it as the run target, hit ▶. Sign with your free Apple ID when asked.
5. In Messages: long-press a message → **Copy** → tap the app drawer → **CatchUp** → tap **Allow Paste**.

## No Mac? Use a Shortcut instead (works on iPhone today)
Shortcuts app → New Shortcut:
1. **Get Clipboard**
2. **Get Contents of URL** → `https://api.anthropic.com/v1/messages`, Method POST,
   Headers: `x-api-key` = your key, `anthropic-version` = `2023-06-01`, `content-type` = `application/json`,
   Request Body JSON: `model` = `claude-opus-5-5`, `max_tokens` = `1024`,
   `messages` = array with one dictionary `{role: user, content: "Translate this texting slang to plain English: " + Clipboard}`
3. **Get Dictionary Value** `content` → **Get Item from List** (last item) → **Get Dictionary Value** `text`
4. **Show Result**

Add it to the Share Sheet / Back Tap, then: copy message → trigger shortcut.
