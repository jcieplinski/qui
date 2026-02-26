# Qui Events API

## Overview

**Qui** is a local iOS and watchOS application for residents of the Mission Rock neighborhood in San Francisco. It answers a simple question: *“Are there any events happening around me today?”* Events include sporting events and concerts at **Oracle Park** and **Chase Center**, plus other goings-on in the area (e.g. Ferry Building, China Basin Park, Pier 48, Thrive City). Users can check at a glance via the app or a home-screen widget on their iPhones, as well as with the app or complication for their Apple Watch. The app is useful for residents to assess parking and traffic conditions on a given day, as well as to help decide whether to attend events in their own backyard.

The app is read-only: it fetches event data from a backend, stores it locally, and displays it. This document describes that backend API so you can run your own server or build another client of your own.

The main source of event data to the backend is provided (with kind permission) by the official SeatGeek API. Special events are also added manually as needed to cover non-ticketed and private events.

---

## API summary

The API is **read-only**: clients GET JSON feeds of events. No authentication is required.

---

## Base URL

```
https://quievents.com
```

(Replace with your own server base URL if self-hosting.)

---

## Endpoints

### 1. Events (main feed)

**`GET /events.json`**

Returns the primary list of events as a JSON array.

| Aspect | Details |
|--------|---------|
| **Method** | `GET` |
| **URL** | `https://quievents.com/events.json` |
| **Response** | `200 OK` with `Content-Type: application/json` |
| **Body** | JSON array of [Event objects](#event-object) |

---

### 2. Special events

**`GET /specialEvents.json`**

Returns a separate list of special events (e.g. private corporate concerts, one-offs). The response follows the same shape as the main feed. Clients typically merge this with the main feed, deduplicate by `id`, and sort by event date.

| Aspect | Details |
|--------|---------|
| **Method** | `GET` |
| **URL** | `https://quievents.com/specialEvents.json` |
| **Response** | `200 OK` with `Content-Type: application/json` |
| **Body** | JSON array of [Event objects](#event-object) |

---

## Event object

Each element in the events array must follow this structure. All string fields use UTF-8.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | UUID (e.g. `"550e8400-e29b-41d4-a716-446655440000"`). Must be unique across both feeds. Used for deduplication and updates. |
| `title` | string | Yes | Event title. |
| `subtitle` | string | No | Optional subtitle. |
| `type` | string | Yes | Category. Recommended: `"sports"`, `"concert"`, `"special event"`, or `"other"`. |
| `location` | string | Yes | Venue/location name. Examples: `"Oracle Park"`, `"Chase Center"`, `"Ferry Building"`, `"China Basin Park"`, `"Pier 48"`, `"Under The Big Top, Oracle Park Lot A"`, `"Thrive City"`. |
| `date` | string | Yes | Date in **Pacific time**. Format: `YYYY-MM-dd` (e.g. `2025-06-15`). |
| `time` | string | Yes | Time in **Pacific time**. Format: `HH:mm` (e.g. `19:30`), or `TBD` when time is not set. |
| `performers` | string | No | Performer or team names. |
| `url` | string | No | Link to more info or tickets. |
| `image_url` | string | No | Absolute URL to a cover/poster image. |
| `source` | string | Yes | Origin of the event, e.g. `"SeatGeek API"`, `"manual"`, or another identifier. |

**Date/time:** Because all events are local to San Francisco, all dates and times are interpreted in **America/Los_Angeles (Pacific)**. The app uses `date` + `time` together; if `time` is `"TBD"`, the event is treated as date-only.

>Be sure your app converts from Pacific time to the user’s current locale to determine what day "today" is, in case they happen to be traveling outside their home time zone.

### Example event

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "SF Giants vs. Colorado Rockies",
  "subtitle": "MLB",
  "type": "sports",
  "location": "Oracle Park",
  "date": "2025-06-15",
  "time": "19:30",
  "performers": "SF Giants",
  "url": "https://mlb.com/giants",
  "image_url": "https://example.com/images/giants-rockies.jpg",
  "source": "SeatGeek API"
}
```

### Example: time TBD

```json
{
  "id": "660e8400-e29b-41d4-a716-446655440001",
  "title": "TBD Game",
  "type": "sports",
  "location": "Chase Center",
  "date": "2025-07-01",
  "time": "TBD",
  "source": "manual"
}
```

---

## Requests in practice

- **Method:** GET only; no request body.
- **Headers:** No required headers. Sending `Accept: application/json` is recommended.
- **Caching:** Servers may set `Cache-Control` (or `ETag` / `Last-Modified`) to reduce load; clients should respect them when appropriate.

---

## Best practices for API consumers

1. **Polling**
   - Do not poll aggressively. The reference app fetches at most once per day on launch, and only re-fetches in the background when it has been at least an hour since the last update and at least 5 minutes since the last refresh attempt. Events do not change very often once scheduled. And most are scheduled long in advance. 
   - Prefer a minimum interval of **several minutes** between full refreshes (e.g. 5–15 minutes) and **once per day** for cold start.

2. **Failure handling**
   - If `/events.json` fails or returns an empty array, treat it as a temporary outage. The reference client does **not** delete existing cached events in that case; it only updates when the main feed returns data. Special events from `/specialEvents.json` are still applied.
   - Use timeouts (e.g. 10–30 seconds) and retry with backoff (exponential or fixed delay) instead of tight loops.

3. **Merging feeds**
   - Fetch both `/events.json` and `/specialEvents.json`.
   - Merge into one list and **deduplicate by `id`** (last occurrence wins if you allow overwrites).
   - Sort by `date` (and optionally `time`) for display. The app uses Pacific time for “today” and “future” filtering.

4. **Validation**
   - Ensure `id` is a valid UUID string and unique.
   - Ensure `date` is `YYYY-MM-dd` and `time` is `HH:mm` or `TBD`. Invalid dates can cause parsing errors or wrong display in clients.

5. **Images**
   - `image_url` should be an absolute URL, pointing to either a JPEG or PNG file. No SVG or PDF support required. Clients should cache images; use stable URLs so caching is effective and avoid unnecessary re-downloads.

6. **HTTPS**
   - Use HTTPS only in production. The reference app uses ephemeral `URLSession` (no cookies); no auth is sent.

---

## Summary

| Endpoint | Purpose |
|----------|---------|
| `GET /events.json` | Main event feed (array of events). |
| `GET /specialEvents.json` | Additional/special events (same schema). |

Both return a JSON array of [Event objects](#event-object). The API is read-only, and no authentication or request body is required. Following the polling and error-handling practices above will keep usage responsible and reliable.
