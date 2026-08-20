# Packet 07 — confirmation page

**Status:** DONE
**Issue:** #41
**Base branch:** `main`

## Goal

A customer who finishes a booking lands on a page that tells them what they
booked, when, and what it will cost — and can reopen that page later from the
link in their email.

## Read first

- `AGENTS.md`
- `docs/method/decision-log.md` — specifically 2026-07-02 (booking references
  are opaque, not sequential) and 2026-07-09 (prices shown inclusive of VAT)
- `docs/method/source/price-list-2026-07.csv`

## Preconditions

- Packet 06 (booking POST, `bookings` table) merged.
- The `bookings.reference` column exists and is unique. If it does not, this
  slice cannot start — say so rather than adding it here.

## Files allowed to change

<!--
  Exhaustive. The pre-commit gate reads this list literally, so paths must be
  real and relative to the repo root. One glob per line is allowed.
  Anything not listed here is out of scope by definition.
-->

```
src/app/booking/[ref]/page.tsx
src/app/booking/[ref]/page.module.css
src/lib/bookings.ts
tests/booking-confirmation.test.ts
```

## Out of scope

- The confirmation **email**. That is packet 08 — this slice only has to make
  the page it links to.
- Cancellation and rescheduling. Not scoped at all yet.
- `src/lib/money.ts`. Formatting there is already correct and shared; do not
  "improve" it while you are in the neighbourhood.
- Anything in `src/app/checkout/`. Packet 06 owns it and it is still open.

## Implementation

1. `GET /booking/[ref]` renders server-side. No client fetch, no loading state
   — the page either has the booking or it does not.
2. Look the booking up by `reference`, never by `id`. References are opaque
   (decision log, 2026-07-02); ids are sequential and enumerable.
3. Show: service name, staff member's first name, start time, duration, total
   price, and the reference itself.
4. Format the start time in `Europe/Brussels` from the injected clock. Do not
   read the system clock, and do not format dates in the component.
5. Total price comes from `booking.total_cents` through the shared money
   helper. Do not recompute it from the price list — the booking is the record
   of what was agreed.
6. An unknown reference renders the 404 page. Not a redirect, not an error
   toast, and not a page that says "booking not found" with a 200 status.
7. The page must be readable with no JavaScript. It is the page people open on
   a bus in six days' time.

## Data contracts

`getBookingByReference(ref: string)` returns `Booking | null`:

```ts
type Booking = {
  reference: string        // opaque, 8 chars, case-insensitive on lookup
  serviceName: string
  staffFirstName: string
  startsAt: string         // ISO 8601, UTC, e.g. "2026-08-24T09:30:00Z"
  durationMinutes: number
  totalCents: number       // integer cents, VAT inclusive
}
```

`null` means not found. It does not mean "error" — do not throw.

## Acceptance criteria

**Happy path**
- [ ] Opening the reference from a completed booking shows the service, the
      staff member, the date and time in Europe/Brussels, and the total.
- [ ] The same URL, opened the next day, shows the same thing.
- [ ] The page renders with JavaScript disabled.

**Error paths**
- [ ] An unknown reference returns HTTP 404 and the standard 404 page.
- [ ] A malformed reference (wrong length, illegal characters) returns 404
      without touching the database.
- [ ] A database error returns 500 and logs the reference, never the row.

## Tests required

- [ ] `tests/booking-confirmation.test.ts` — renders a known booking and
      asserts service, staff name, formatted local time, and formatted total.
- [ ] Same file — unknown reference returns 404.
- [ ] Same file — a booking at 00:30 UTC renders as 02:30 local in summer.
      This is the case that catches a timezone regression; a midday fixture
      never will.

## Verification

```sh
npm run check
```

Manual:
- [ ] Complete a real booking in dev, follow the redirect, confirm the total
      matches what checkout showed — to the cent.
- [ ] Reload the confirmation URL in a private window. Same page, no session.
- [ ] 375px and 1440px. The reference must be selectable, not an image.

## Stop and report if

- `bookings.reference` does not exist, or is not unique.
- The booking row has no `total_cents` and the total would have to be
  recomputed from the price list. That is a different slice and a decision.
- Making this work needs a change in `src/app/checkout/` — packet 06 owns
  those files and is still open.

## Review notes

<!-- Filled in AFTER review. This is what turns a packet into a record. -->

Verifier (Kilo, 2026-08-11): PASS on the second pass.

First pass was MERGE AFTER FIXES — the time was formatted with
`toLocaleString()` and no timezone argument, so it rendered in the server's
zone. Correct on a laptop in Brussels, wrong on the deployment. Cites rule 6.
The 00:30 UTC fixture in the test list is what surfaced it; the original test
used a 14:00 fixture and passed in both zones.

One optional finding, not taken: the reference could be rendered in a
monospace face. Logged as a proposal in the decision log instead of widening
this diff.
