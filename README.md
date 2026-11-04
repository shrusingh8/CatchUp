# CatchUp 💬

**Got a text you can't decode? CatchUp tells you what they actually meant.**

Paste in a message like *"no cap that's lowkey the goat 🐐"* and you get back:

> **They're saying it's genuinely the best, honestly.**
> `no cap` — no lie, for real · `lowkey` — kind of / quietly · `the goat` — greatest of all time

It comes in two flavors:

| | How you use it | Needs |
|---|---|---|
| **Web** (`index.html`) | Open the page, paste a message, tap **Catch me up** | Any browser + an Anthropic API key |
| **iMessage** (`MessagesViewController.swift`) | Long-press a message → **Copy** → open CatchUp from the app drawer | A Mac with Xcode to build it |

Both send the message to Claude and get back a plain-English meaning plus each slang term explained.
(Apple doesn't let iMessage apps read your chats, so copying the message is how it gets in.)

## Run the web version
Open `index.html` in a browser → **Settings · API key** → paste your key from console.anthropic.com.
The key is saved in that browser only.

## Build the iMessage version (Mac only)
1. Xcode → File → New → Project → iOS → **iMessage App** → name it `CatchUp`.
2. Replace the generated `MessagesViewController.swift` (MessagesExtension folder) with the one here.
3. Put your API key in `apiKey`.
4. Plug in your iPhone, pick it as the run target, hit ▶. Sign with your free Apple ID when asked.

## No Mac? iPhone Shortcut version
Shortcuts app → New Shortcut:
1. **Get Clipboard**
2. **Get Contents of URL** → `https://api.anthropic.com/v1/messages`, Method POST,
   Headers: `x-api-key` = your key, `anthropic-version` = `2023-06-01`, `content-type` = `application/json`,
   Request Body JSON: `model` = `claude-opus-5-5`, `max_tokens` = `1024`,
   `messages` = array with one dictionary `{role: user, content: "Translate this texting slang to plain English: " + Clipboard}`
3. **Get Dictionary Value** `content` → **Get Item from List** (last item) → **Get Dictionary Value** `text`
4. **Show Result**

Add it to the Share Sheet or Back Tap, then: copy message → run shortcut.

## Before going public
Right now everyone needs their own API key. To let anyone use it, put a small proxy server in front
that holds one key, then point both apps at it.
