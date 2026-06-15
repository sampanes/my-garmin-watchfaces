# Track 2 — Async social (ACNH-style visits, gifts, mail)

**Verdict: doable, but it's a real product, not a feature.** It requires *your*
backend, *your* identity/friend system, and ongoing ops. Model it on Animal
Crossing's **asynchronous** social: you visit a *snapshot* of a friend's pet, leave
gifts/letters, and they find them later. No live presence (that's Track 3).

## Why async (not live)

Per the connectivity model: no real-time server→watch push, internet only via the
phone. So the natural, reliable design is **store-and-forward**:

- You act → POST to your server → it lands in the friend's mailbox.
- Friend pulls it on next app open (or a throttled background poll, ≥ ~5 min).
- Latency of minutes-to-hours is fine and *on-theme* for a cozy pet game.

## Architecture

```
 [Watch app] --makeWebRequest--> (phone bridge) --> [YOUR API] --> [DB]
                                                       |
                            users · pets(snapshots) · friendships · mailbox
```

- **Backend:** small REST API + DB. Endpoints roughly:
  `POST /pet/snapshot`, `GET /friend/{code}/snapshot`, `POST /mail`,
  `GET /mailbox?since=`, `POST /friend/request`, `POST /friend/accept`.
- **Watch ↔ net:** `Communications.makeWebRequest`. Confirmed (`beyond_faces/WEB_AND_BACKGROUND.md`):
  **HTTPS is mandatory** (newer firmware blocks non-SSL), **needs the phone connected**,
  and **battery-saver disables background requests**. Exact size/throttle limits still
  open — keep payloads tiny anyway (short JSON keys, snapshot-not-history).
- **Sync strategy:** pull-on-open is the backbone (cheap, reliable). Optional
  background fetch only to light up a "you have mail" glance.
- **⚠️ Background sync is brutally constrained:** ≥5 min interval, ~30 s run (incl.
  request lag), **32 KB heap** — the JSON parser can *crash* on a large response. So
  the background path must fetch a **tiny** "have mail / counts" payload; pull the real
  contents in the foreground on open. Mark background code `(:background)`; request
  `Communications` + `Background` permissions.

## Identity & friends (the part Garmin won't give you)

- **No Garmin friend graph access.** Build your own:
  - **Accounts/auth:** OAuth via `Communications.makeOAuthRequest` against your
    backend (or a device-bound token). Verify the flow specifics.
  - **Friend pairing:** show an 8-char **friend code** on the watch; friend enters
    it. (QR/scan is far nicer but needs the companion app — see below.)
- From the user's POV it can *feel* like "me and my Garmin buddy," but architecturally
  it's your network. Set that expectation in the UX copy.

## "Visiting" + gifts + mail

- **Visit:** `GET` the friend's latest pet snapshot and render it locally with your
  existing sprite engine. **The snapshot *is* the progression model's output** — a
  handful of tiny integers: permanent identity (species + evolution branch + name) +
  current arrangement (worn cosmetics + displayed gifts/trophies) + track tiers. That's
  exactly what makes two pets look distinct at a glance even though everyone eventually
  unlocks everything (see `05-progression.md §"Won't everyone end up identical?"`).
  Optional **guestbook / footprint**: leave a tiny "was here" marker.
- **Gift:** item id + optional note → `POST /mail` → friend's mailbox → applied on
  their next open (food, decor, currency).
- **Mailbox:** server-side queue; client pulls `since` a cursor. Idempotent apply
  (don't double-grant a gift on re-sync).

## Messaging: use canned vocabulary, NOT free text

Strong recommendation:

- **Text entry on a watch is miserable** (tiny keyboard / voice-only).
- Free text between users is a **moderation/abuse surface** you'd have to police.
- → Ship a **fixed vocabulary**: reactions/stickers + a curated phrase list (think
  ACNH reactions or Splatoon's preset phrases). Expressive, safe, watch-friendly,
  and tiny on the wire. Free text (if ever) belongs in the companion phone app.

## Companion phone app — optional but powerful

Building a CIQ Mobile SDK companion app (iOS/Android) that messages the watch app
unlocks a lot:

| Companion app gives you | Cost |
|--------------------------|------|
| Real OS **push notifications** (surface "new gift!" on phone→watch) | Build + maintain 2 mobile apps |
| **QR friend-add**, account management, richer onboarding | App Store / Play review + listings |
| Better text entry, heavier networking off the watch | More moving parts, more to break |

Decision flagged in open-questions. You can launch Track 2 **without** it
(watch-only `makeWebRequest`), then add it if the project has legs.

## Ops reality check

This track means you **run a service**: hosting, database, auth, abuse handling,
privacy policy, uptime. That's the real ongoing commitment — more than the code.
Budget for it before designing features that assume it.

## MVP scope (Track 2)

1. Backend with accounts + friend codes + pet snapshot + mailbox.
2. Watch: publish my snapshot on close; "visit friend" fetch+render; send/receive
   a **canned gift+sticker**; pull mailbox on open.
3. No companion app, no free text, no live presence yet.
