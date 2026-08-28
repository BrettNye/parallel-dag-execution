---
title: webhook signature verification
created: 2026-07-29
---

# Verify inbound webhook signatures

## 1. Goal

Reject any inbound webhook whose HMAC signature does not match the shared
secret.

## 2. Requirements

- **R1** — `POST /api/webhooks/inbound` computes the request's HMAC-SHA256 over
  the raw body and compares it to the `X-Signature` header using a
  constant-time compare.
- **R2** — A request with no `X-Signature` header is rejected with `401`
  before the body is parsed.

## 3. Existing surface

`verifySignature(rawBody, header, secret)` in `code/handler.ts` already
implements the constant-time comparison the route must call. The route task
extends this file; it does not create a new comparison routine.

## 4. Out of scope

Rotating the shared secret. Rate-limiting invalid attempts.
