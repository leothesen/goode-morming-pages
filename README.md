# Goode Morming Pages

A native macOS rebuild of [Ensō](https://enso.sonnet.io/)'s writing surface, with
one addition: a button that puts the session into a Notion journal and then
forgets it ever existed.

Write on five lines. The four above the caret dissolve as you go. You cannot
comfortably reach back and edit, which is the point.

## How the fade works

It is not per-character opacity. Four bars of the page colour are laid over the
lines above the caret at 0.98, 0.92, 0.85 and 0.70 — they **erase** rather than
dim, and the illusion holds only because they are the same colour as the surface
behind them.

That is why the writing canvas stays flat and opaque. Liquid Glass goes on the
toolbar, Settings and the sync sheet — never behind the text. Put a translucent
material back there and the bars stop matching their backdrop, turning a smooth
dissolve into four hard horizontal edges.

## One change from Ensō

The buffer is bottom-anchored: the caret's line always lands in the single
uncovered slot, even on a blank page. Ensō leaves your first line under the
heaviest scrim until you have written five of them.

## Sync

One page per session. You type a title, it creates the page, and only once Notion
confirms every block landed does the screen clear. **Notion is the only record** —
there is no local archive by design, so the confirm-then-clear order is
load-bearing.

The unsynced session is held in `~/Library/Application Support/GoodeMormingPages`
purely so a crash doesn't cost you the morning. It is deleted on a successful sync.

### Setting it up

1. Create an internal integration at <https://www.notion.so/profile/integrations>
   and copy the `ntn_…` token.
2. **Open your journal database in Notion, click `···` → Connections, and add the
   integration.** Skipping this is the single most common failure: the token is
   valid but sees nothing, and the destination list comes back empty.
3. Paste the token in Settings → Notion, hit Verify, and pick the destination.

The token lives in your Keychain, never in `UserDefaults`.

## Building

```sh
xcodegen generate    # only needed after editing project.yml
xcodebuild -scheme GoodeMormingPages -configuration Debug \
  -destination "platform=macOS,arch=arm64" build
```

`project.yml` is the source of truth for the project, but the generated
`.xcodeproj` is committed so CI needs no extra tooling.

Requires Xcode 26 and macOS 26 — the app targets Liquid Glass APIs that do not
exist in earlier toolchains.

## Notes for later

- Notion's API refuses browser origins (a CORS preflight returns 400 with no
  `Access-Control-*` headers), which is why this is a native app rather than a
  web page.
- Page parents use `data_source_id` on API version `2026-03-11`. The older
  `database_id` shape fails on multi-source databases.
- Sparkle auto-updates are not wired up yet. That needs the EdDSA keypair and the
  release workflow.
