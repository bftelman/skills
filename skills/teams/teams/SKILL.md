---
name: teams
description: Use when the user wants to read, catch up on, send, reply to, react to, or @mention in Microsoft Teams chat messages ("check Teams", "any messages in <chat>", "reply in <chat>", "message the <X> chat", "react to that message", "@mention someone", "catch me up on Teams"), or to run autopilot on a chat (watch it and keep replying on the user's behalf). Drives the new Teams web (teams.cloud.microsoft) in Chrome via the Playwright MCP — no Graph/API. Chat ids in chats.md; verified selectors in selectors.md.
---

# Teams (Playwright MCP)

Operate Microsoft Teams web (`https://teams.cloud.microsoft/v2/`) through the **Playwright MCP**. No
Graph / MS365 API. Verified: read, send, quote-reply, react, @mention. Chats only (no calls, files,
channel posts).

Tool names below are the MCP's bare names (`browser_evaluate`, `browser_navigate`, `browser_type`…);
Claude Code exposes them as `mcp__playwright__browser_*`, other agents under their own prefix.
`browser_evaluate` is required: every flow runs as one in-page async function.

## Core rules

1. **Safety Gate — never send/react without confirmation.** Show the target chat + exact text (or
   emoji + which message) and WAIT for explicit approval. Override only if the user said "just send
   it" for that specific message. Re-confirm each new message. Reactions and @mentions notify people
   too — gate them. Safe end-to-end test target: **Notes to self** (`48:notes`).
   The only exception is **Autopilot** (below), which the user starts explicitly for one chat.
2. **One call per action.** Each Playwright call costs a model round trip (~2-3s), which dominates
   runtime; fixed `browser_wait_for` sleeps and `browser_type slowly` add more. Do the whole flow
   (open + verify + type + send + verify) in ONE `browser_evaluate` that polls selectors. Use
   `browser_click`/`hover`/`type` only where noted: Teams animates constantly, so they time out on
   Playwright's "stable" check. Never take snapshots or screenshots unless the user wants to see.
3. **Never navigate when the tab is already on Teams.** A reload costs ~4s plus SPA boot. Navigate
   only on the first Teams action of the agent session, or when the script returns `step:'navigate'`.
   Never use hash-URL navigation (the SPA ignores `#`-only changes).
4. **Verify the open chat via `document.title`** (`… | <chat name> | Microsoft Teams`). There is no
   `chat-header-title` data-tid.

Measured 2026-10-26, one send to Notes to self: old flow 34.7s / 13 calls; warm fast path 6.0s /
1 call (1.4s in page); cold (fresh browser) 9.1s / 2 calls.

## Connect

- **First Teams action in this agent session:** `browser_navigate` `https://teams.cloud.microsoft/v2/`,
  then run the chat script right away (it waits for the SPA itself, no `browser_wait_for`).
- **Afterwards:** run the chat script directly. The MCP's browser and tab stay open for the life of
  the MCP process.
- **Browser mode** depends on the MCP config:
  - `--browser msedge` (or chrome): the MCP launches its own persistent-profile browser. No launcher.
  - `--cdp-endpoint http://127.0.0.1:9222`: attaches to a debug Chrome. On `ECONNREFUSED …:9222`
    run the launcher (Windows `pwsh -File "<skill-dir>/teams-chrome.ps1"`, macOS/Linux
    `bash "<skill-dir>/teams-chrome.sh"`), then navigate. Both exit at once if the port is up, use a
    dedicated profile, and bind IPv4 (`localhost` resolves to `::1` and is refused). The connection
    drops when the user closes that window; relaunch, the profile stays signed in. One-time MCP
    config the skill can't self-heal: `claude mcp add -s user playwright -- npx @playwright/mcp@latest
    --cdp-endpoint http://127.0.0.1:9222` (other agents: same command/args in their MCP config).
- `step:'sign-in'` → ask the user to log into Teams once in that browser window (persists).
  **Never enter credentials.**

## Chat script (open, read, send)

Fill the four constants and run with `browser_evaluate`. `ID`/`NAME` come from `chats.md`.
- **Read:** `TEXT = ''`. Returns the last `READ` lines of the pane (author, time and body interleaved).
  Reading marks messages read; say so if it matters.
- **Send:** run the Safety Gate first (chat + exact text), then run with `TEXT` set. The script refuses
  if the title does not match or the chat already has a draft. Multi-line works (`\n` → soft break);
  URLs auto-link.

```js
async () => {
  const ID = '48:notes';            // chat id, or 8:orgid:<guid> for a person
  const NAME = 'Notes to self';     // search fallback + title check when not in the left list
  const TEXT = '';                  // '' = read
  const READ = 40;

  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const until = async (f, ms = 15000) => {
    const t = Date.now();
    while (Date.now() - t < ms) { const v = f(); if (v) return v; await sleep(50); }
    return null;
  };
  const hits = () => [...document.querySelectorAll('[data-tid^="AUTOSUGGEST_SUGGESTION_TOPHITS"],[data-tid^="AUTOSUGGEST_SUGGESTION_GROUPCHATS"]')];
  const t0 = Date.now();

  if (!location.host.endsWith('teams.cloud.microsoft')) return { ok: false, step: 'navigate' };
  if (!await until(() => document.querySelector('[id^="title-chat-list-item_"]'), 30000)) {
    return { ok: false, step: /login\.microsoftonline/.test(location.href) ? 'sign-in' : 'chat list not loaded' };
  }

  const label = document.getElementById('title-chat-list-item_' + ID);
  let expected = NAME;
  if (label) {
    expected = label.textContent.trim();
    label.closest('[role="treeitem"]').click();
  } else {
    const s = document.querySelector('input[data-tid="AUTOSUGGEST_INPUT"]');
    s.focus();
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(s, NAME);
    s.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText' }));
    const hit = await until(() => hits().find(e => e.dataset.tid.endsWith(ID))
      || hits().find(e => e.dataset.tid.includes('8:orgid:') && e.innerText.split('\n')[0].trim() === NAME), 8000);
    if (!hit) return { ok: false, step: 'not found', hits: hits().map(e => e.dataset.tid + ' | ' + e.innerText.split('\n')[0]) };
    hit.click();
    s.blur();
    ['keydown', 'keyup'].forEach(t => s.dispatchEvent(new KeyboardEvent(t, { key: 'Escape', keyCode: 27, bubbles: true })));
  }
  if (!await until(() => document.title.includes(expected))) return { ok: false, step: 'title', title: document.title };

  const msgs = () => [...document.querySelectorAll('[data-tid="chat-pane-message"]')];
  if (!TEXT) {
    await until(() => msgs().length);
    const pane = document.querySelector('[data-tid="message-pane-list-viewport"]') || document.querySelector('[role="main"]');
    pane.scrollTop = pane.scrollHeight;
    await sleep(300);
    return { ok: true, chat: document.title, lines: pane.innerText.split('\n').filter(Boolean).slice(-READ) };
  }

  const ed = await until(() => document.querySelector('[data-tid="ckeditor"]')?.ckeditorInstance && document.querySelector('[data-tid="ckeditor"]'));
  const ck = ed.ckeditorInstance;
  if (ed.textContent.trim()) return { ok: false, step: 'draft present', draft: ed.innerText };
  ck.editing.view.focus();
  TEXT.split('\n').forEach((line, i) => {
    if (i) ck.execute('shiftEnter');
    ck.model.change(w => w.insertText(line, ck.model.document.selection.getFirstPosition()));
  });
  await sleep(200);
  if (ed.innerText.trim() !== TEXT.trim()) return { ok: false, step: 'type', got: ed.innerText };
  for (let i = 0; i < 5 && ed.textContent.trim(); i++) {
    document.querySelector('[data-tid$="MessageCommands-send"]')?.click();
    await until(() => !ed.textContent.trim(), 1500);
  }
  const posted = await until(() => msgs().pop()?.innerText.includes(TEXT.split('\n')[0]), 10000);
  return { ok: !!posted, chat: document.title, ms: Date.now() - t0 };
}
```

Chats outside the left list fall back to an instant search (~0.5s). On `step:'not found'` pick the
right hit from the returned list and offer to add its id to `chats.md`. Why each odd step exists
(CKEditor model, send-button retry, native setter) is in `selectors.md`.

## Setup: seed chats.md from the chat list (first run, no API)

When `chats.md` is empty or the user says "set up my chats", read ids from the left list (favorites +
recents) with `browser_evaluate`:
```js
() => [...document.querySelectorAll('[id^="title-chat-list-item_"]')]
  .map(s => ({ name: s.textContent.trim(), id: s.id.replace('title-chat-list-item_', '') }))
```
Show the name→id list, keep the ones the user wants, write those rows into `chats.md`. Scroll the
list and rerun to capture more. MS365 `teams_list_chats` is an optional alternative when present.
New user? `/setup-teams` (or "set up Teams") runs connect, one-time login and this seeding in one go.

## Quote-reply, react, @mention

These need a target message or real keystrokes, so they take 2-3 calls; still batch everything else
into each `browser_evaluate`, and open the chat with the chat script (`TEXT = ''`, `READ = 1`) first.

**Find a message** (shared step): `msgs()` as above, match on text (last match = most recent), tag it
`el.setAttribute('data-cc-target','x')`, `scrollIntoView()`, dispatch `mouseenter/over/move`, then
`.click()` its `[data-tid="message-actions-menu-hidden-button"]`.

- **Quote-reply:** in the same call, click the `role="menuitem"` matching `/reply with quote|^reply/i`,
  then insert the reply via `ckeditorInstance` as in the chat script. Safety Gate, then send + verify
  (the send part of the chat script).
- **React:** Safety Gate (target + emoji) first. In the same call open the menu and click
  `[data-tid="message-actions-like"]` / `-heart` / `-laugh` / `-surprised`, or
  `[data-tid="add-reaction-picker-entry-point-button"]` for the full picker. Verify the message now
  has `[data-tid="diverse-reaction-summary"]`.
- **@mention:** the picker needs real keystrokes. Focus the editor, `browser_type` `@<name>` into
  `[data-tid="ckeditor"]` with `slowly: true`, then one `browser_evaluate` that polls for
  `[data-tid="autocomplete-picker-item-<Full Name>"]` (inside `[data-tid="AutocompletePopup-Mentions"]`;
  `…-Everyone` notifies all), clicks it and inserts the rest of the text via the model. It becomes a
  real tagged mention (`<mention mri="8:orgid:<guid>">`), not text. Safety Gate, then send + verify.
  If asked NOT to send, leave the draft or clear it with `ckeditorInstance.setData('')`.

## Autopilot

When the user asks to run autopilot on a chat (watch it and keep replying as them), read
`autopilot.md` and follow it. It is the only flow that sends without a per-message gate, and only in
the one chat the user named.

## Red flags: STOP

- About to send/react/insert-a-notifying-mention before the user said yes → STOP, run the gate
  (unless autopilot is running for that chat and it is a plain reply).
- `step:'sign-in'` → STOP, ask the user to log in in that window (never auto-login).
- `step:'title'` or `'draft present'` → STOP, report; never type into an unconfirmed chat or over a draft.
- A selector missed → discover the real one via `browser_evaluate` and self-heal `selectors.md`.

## Files

- `chats.md`: friendly-name → chat-id map (per user).
- `selectors.md`: verified `data-tid` selectors.
- `autopilot.md`: autopilot flow, hand-back rules and the watch script.
- `teams-chrome.ps1` / `teams-chrome.sh`: debug-Chrome launchers for CDP mode (Windows / macOS+Linux).
