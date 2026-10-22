# Source review (2026-10-23)

These are engineering references, not bundled dependencies. No source was copied.

- [MiniSim](https://github.com/okwasniewski/MiniSim/tree/bb9deb199adf9d88350f4dbc6349c4ff39fdd1a4): `MiniSim/Service/Actions.swift`, `ColdBootCommand`. Explicit cold-boot action; launching an emulator is separate from application compatibility. Inspected, not adopted as an automatic snapshot workaround.
- [Simulators](https://github.com/rialdana/simulators/blob/c15d9e32a7ac561c66e77535ece14d2f3bfe9c1f/app/Sources/Simulators/Shell.swift): command timeout and inherited pipe EOF pitfalls. Pocket Play now uses a private temporary output file, timeout, capped output read, nonoverlapping refresh and stale-refresh guard; independent implementation.
- [AndroMac](https://github.com/sabbirmohammad/AndroMac/tree/a6e718b7eabfb986290e006c07be26b7073272ef): `Sources/AndroMac/Services/EmulatorProcessManager.swift` and `Models/AndroidConfig.swift`. Examined host GPU, explicit CPU/RAM and compact display presets. Our GPU already uses host/Metal; adding another GPU flag is not a demonstrated fix. Added an opt-in 720×1600/280dpi phone profile to reduce pixel load while preserving aspect ratio.

Earlier README acknowledgements were not evidence of thorough source review. The paths and pinned commits above document this review. None of these projects demonstrates a fix for Xianyu session invalidation; no such claim is made.
