# Selectors: verified 2026-10-26 (new Teams web, teams.cloud.microsoft)

Act via one `browser_evaluate` per action (see SKILL.md → Chat script); Playwright
`browser_click`/`hover` time out on the "stable" check because Teams animates constantly.

## Open a chat
| Element | Selector | Notes |
|---|---|---|
| Left-list chat | `#title-chat-list-item_<chatId>` → `.closest('[role="treeitem"]').click()` | use `getElementById` (ids contain `:`); text = chat name; favorites + recents only |
| Chat list loaded | any `[id^="title-chat-list-item_"]` | poll this instead of a fixed wait after navigate |
| Open chat name | `document.title` = `… \| <chat name> \| Microsoft Teams` | no `chat-header-title` data-tid exists |
| Search input | `input[data-tid="AUTOSUGGEST_INPUT"]` | fill via native setter `Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value').set` + `InputEvent('input',{bubbles:true})`; plain `fill()` won't trigger suggestions |
| Result (group/meeting) | `[data-tid$="<chatId>"]` | prefix `AUTOSUGGEST_SUGGESTION_TOPHITS`/`GROUPCHATS` + `19:…@thread.v2` |
| Result (person → 1:1) | `[data-tid$="8:orgid:<userGuid>"]` | prefix `…TOPHITS`; opens/creates the 1:1 |
| Dismiss flyout | blur input + dispatch Escape keydown/keyup | flyout lingers over the compose box otherwise |

## Compose & send
| Element | Selector | Notes |
|---|---|---|
| Compose box | `[data-tid="ckeditor"]` | CKEditor 5; write through `.ckeditorInstance.model` (raw DOM edits are reverted); soft break = `ck.execute('shiftEnter')`; clear = `ck.setData('')` |
| Send | `[data-tid$="MessageCommands-send"]` | `newMessageCommands-send` on cold load, `sendMessageCommands-send` later; re-click while the editor is non-empty: on a cold load Teams ignores the first click until its draft state syncs; the editor empties on send, so no double send |
| Verify sent | editor empty AND last `[data-tid="chat-pane-message"]` contains the text | |

## Messages
| Element | Selector | Notes |
|---|---|---|
| Message row | `[data-tid="chat-pane-message"]` | match on text; last match = most recent; body only (no author) |
| Message id | `data-mid` on the message row | increasing number; `id="message-body-<mid>"` |
| Author | `#author-<mid>` | only on the first message of a run by one author; carry it forward |
| Own message | row `.closest('.fui-ChatMyMessage')` | others are under `.fui-ChatMessage` |
| Message text | `#content-<mid>` | body without author/time |
| Message pane (scroll) | `[data-tid="message-pane-list-viewport"]` | fallback `[role="main"]`; `.innerText` interleaves author, time, body |
| More-options menu (per msg) | `[data-tid="message-actions-menu-hidden-button"]` | dispatch `mouseenter/over/move` first, then `.click()` |

## Quote-reply
Open the message's more-options menu → click the `role="menuitem"` matching `/reply with quote|^reply/i`
(label "Reply with quote (Alt+R)"). Compose box then shows the quoted reference.

## Reactions (in the more-options menu's top row)
| Element | Selector |
|---|---|
| Like 👍 | `[data-tid="message-actions-like"]` |
| Heart | `[data-tid="message-actions-heart"]` |
| Laugh | `[data-tid="message-actions-laugh"]` |
| Surprised | `[data-tid="message-actions-surprised"]` |
| Full picker | `[data-tid="add-reaction-picker-entry-point-button"]` (also `expanded-reactions-picker-entry`) |
| Verify applied | `[data-tid="diverse-reaction-summary"]` present / "N … reaction" text on the message |

## @mention
| Element | Selector | Notes |
|---|---|---|
| Trigger | type `@<name>` into `[data-tid="ckeditor"]` with real keystrokes | picker needs keystrokes |
| Picker | `[data-tid="AutocompletePopup-Mentions"]` | |
| Person option | `[data-tid="autocomplete-picker-item-<Full Name>"]` (role option) | `…-Everyone` notifies all |
| Inserted chip (verify) | `[itemtype="http://schema.skype.com/Mention"]` wrapping `<mention mri="8:orgid:<guid>">` | a real tagged mention, not text |

## CDP / connection (CDP mode only)
- Debug Chrome must listen on IPv4 `127.0.0.1:9222`; MCP endpoint must be `http://127.0.0.1:9222`
  (not `localhost` → IPv6 `::1` refuses).
- `ECONNREFUSED …:9222` mid-run = the debug Chrome window was closed → relaunch `teams-chrome.ps1`.
