# Architecture

## Platform targets

The canonical registry is `registry/platforms.json` and is validated to contain exactly 39 unique IDs. Platform target records describe category, role, execution mode, and a preliminary license expression. A catalog license label is not a substitute for upstream license verification.

## Nine service processes

Each process is a separate systemd unit and loopback-only listener. nginx is the public entry point. PostgreSQL is the persistent relational store. Valkey is the local cache/event transport. Service processes run as a dedicated unprivileged account with `NoNewPrivileges`, private temporary storage, and a restricted filesystem view.

## Four knowledge layers

- Evidence: source claims, source URI, source hash, collection timestamp, confidence.
- Derivation: method and machine-readable result derived from evidence.
- Policy: versioned rules evaluated against derived facts.
- Profile: deployable constraints and selected policy set.

## Provenance identity chain

Project → Source Version → Package Instance → Artifact SHA-256.

## Freedom model

Software freedom (F) and hardware freedom (H) are independent axes. Hardware freedom evidence must describe firmware, device documentation, and replaceability; it must not be inferred from the software license.
