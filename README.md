# Thy Budget Buddy (TBB)

A private, local-first and FLOSS budget companion for iPhone, iPad, and Apple Watch.

TBB makes day-to-day budgeting quick, keeps sensitive amounts private on demand, and lets a household share only the budgets it chooses—without a TBB-operated server.

## Principles

- **Private by default.** Financial data stays in the person's iCloud private database or an explicitly invited household share.
- **Fast in public.** A persistent Privacy Mode masks all monetary values immediately.
- **Useful in seconds.** Recording a transaction must be frictionless; dashboards explain the result.
- **No rent-seeking.** TBB has no paid tier, ads, trackers, or feature gates. Support is voluntary.
- **Built to last.** Versioned exports, restore validation, deterministic calculations, and migration evidence are product requirements.

## Development

The foundation is a strict-concurrency Swift package plus a reproducible universal iPhone/iPad app project:

```bash
swift test
make ci
brew install xcodegen
xcodegen generate
open TBB.xcodeproj
```

The generated app target supports iPhone and iPad. The watchOS companion target is added with the Watch milestone, after the ledger and privacy-safe glance contracts exist.

## License

TBB is licensed under the [Mozilla Public License 2.0](LICENSE) (MPL-2.0).

## Supporting TBB

TBB will offer optional support links in the app and repository. They will never unlock, restrict, or prioritize product features. GitHub Sponsors is configured where available; the Patreon destination will be added when published.

## Documentation

- [Product intent](docs/intent.md)
- [Architecture](docs/architecture.md)
- [Threat model](docs/threat-model.md)
- [Specifications](docs/specs/registry.md)
- [Testing strategy](docs/testing.md)
- [Roadmap](docs/roadmap.md)
- [Contributing](CONTRIBUTING.md)
