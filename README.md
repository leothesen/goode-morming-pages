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

One page per session. You give it a title, an emoji and tags; it creates the page,
and only once Notion confirms every block landed does the screen clear.

**Line breaks.** Consecutive lines stay in one Notion block, separated by line
breaks. A blank line starts a new block. Splitting on every newline — which is
what it used to do — leaves a visibly empty paragraph between each line, because
Notion blocks carry their own vertical spacing on top of the break.

**Tags** come from the select or multi-select column in your database (it prefers
one called "Tags"). Options are read from the schema when you pick the destination
in Settings, and default to `morning-pages`. Anything you type that Notion hasn't
seen is created on write. The emoji and tags you chose last time are offered again.
 **Notion is the only record** —
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

## Installing

Download `GoodeMormingPages.zip` from the
[latest release](https://github.com/leothesen/goode-morming-pages/releases/latest)
using the command line, which avoids Gatekeeper entirely:

```sh
cd ~/Downloads
gh release download --repo leothesen/goode-morming-pages --pattern '*.zip'
ditto -x -k GoodeMormingPages.zip .
mv GoodeMormingPages.app /Applications/
open /Applications/GoodeMormingPages.app
```

The app is ad-hoc signed and not notarised, so `spctl` rejects it. Files fetched
with `gh` or `curl` carry no quarantine flag and open without complaint.

On first launch it offers to move itself into `/Applications`. Say yes — running
it from `~/Downloads` is how you end up with three copies.

### If you download through a browser

macOS quarantines the file and refuses to open it. Either clear the flag:

```sh
xattr -dr com.apple.quarantine ~/Downloads/GoodeMormingPages.app
```

Or go through the UI: double-click and let it be blocked, then open **System
Settings → Privacy & Security**, scroll to the bottom, and click **Open Anyway**
next to the message about Goode Morming Pages. You may be asked for Touch ID or
your password, and you only do this once per installed copy.

### Duplicate copies

If the app ever appears to have renamed itself — "GoodeMormingPages 2" — you have
more than one copy. Downloading the zip twice leaves `GoodeMormingPages (1).zip`,
and unzipping that gives you `GoodeMormingPages 2.app` beside the first. macOS
registers both under the same bundle ID and tells them apart by filename.

```sh
ls -d ~/Downloads/GoodeMorming* /Applications/GoodeMorming*   # find them
mdfind "kMDItemCFBundleIdentifier == 'co.leothesen.GoodeMormingPages'"
```

Delete everything except the copy in `/Applications`.

## Contributing and releasing

`main` is protected. Everything goes through a pull request, and shipping is a
separate, deliberate act.

```
branch → PR → CI must pass → merge          (nothing ships)
publish a release with a v* tag → it ships
```

**On the PR**, `.github/workflows/ci.yml` builds Debug, runs the tests, then
builds Release and launches it to prove it actually starts. Failures block the
merge.

**On publishing a release**, `.github/workflows/release.yml` stamps the version
from the tag, tests, builds, smoke-tests, packages with `ditto`, signs with
Sparkle's EdDSA key, and attaches both the app and `appcast.xml` to the release.

```sh
gh release create v0.2.0 --generate-notes
```

It must be a *release*, not a bare `git push --tags` — the workflow listens for
`release: published`. Merging to `main` ships nothing.

### The update feed

Sparkle reads
`https://github.com/leothesen/goode-morming-pages/releases/latest/download/appcast.xml`,
a permanently stable URL that always resolves to the newest release's asset.

It used to be a file on `main`, committed by the release job. That fought branch
protection: `github-actions[bot]` is not exempt from "changes must be made
through a pull request", so the push was rejected, the release still looked
perfectly healthy, and the feed silently stopped advancing. Serving the feed from
the release itself needs no write access to any branch, so there is nothing to
keep exempt.

`appcast.xml` is still committed at the repo root. It is the *old* feed location,
kept only so copies installed before this change get offered one more update and
land on the new URL. Once nothing is running an older build it can be deleted.

### Required setting

**Required status check: `build-and-test`.** Without it the PR gate is decorative.

### Why the release job is one workflow

An earlier design had merges create a release and a second workflow build it.
That does not work: anything created with `GITHUB_TOKEN` does not trigger further
workflows, so the build would never start and nothing would say why.

### Things that will bite

- **The repo must stay public.** The appcast and the app are fetched from the
  releases page with no credentials, and Sparkle treats a failed feed fetch as
  "no update available" without a word. The release job ends by fetching the
  published feed and asserting it is reachable, signed, and advertising the
  version just built.
- **`CURRENT_PROJECT_VERSION` must sort correctly.** Sparkle compares
  `CFBundleVersion`. It is kept as the same semver string as `MARKETING_VERSION`
  precisely so `0.2.0` beats `0.1.1`. A bare integer baseline like `1` would make
  every semver release look older, and updates would silently never appear.
- **`SPARKLE_PRIVATE_KEY`** is a repo secret. It is the same key the walkingpad
  app uses — Sparkle's own guidance is one key per person, not per app. Lose it
  and no installed copy can ever be updated again.

## Notes for later

- Notion's API refuses browser origins (a CORS preflight returns 400 with no
  `Access-Control-*` headers), which is why this is a native app rather than a
  web page.
- Page parents use `data_source_id` on API version `2026-03-11`. The older
  `database_id` shape fails on multi-source databases.
- Sparkle auto-updates are wired up; see Releasing above.
