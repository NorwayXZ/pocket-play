# Bug investigation — local Apple M4 / 16 GB, Android 15

## Performance
Baseline Xianyu accumulated gfxinfo: 10,832 frames, median 22ms, p95 57ms,
664 deadline-janky frames (6.13%). These are not FPS measurements and exclude
some Flutter/Surface rendering. Host GPU verified as Apple M4 OpenGL-to-Metal,
4GB guest RAM, 4 vCPU. Storage: 6.8GB free. Host memory free percentage: 28%.

Repeatable Settings control: ten alternating 300ms swipes at 1080×2400;
280 frames, median 17ms, p95 73ms, deadline-janky 6.79%.
Added opt-in smooth profile: 720×1600 @ 280dpi (same 9:20 aspect, 55.6% fewer
pixels). Lower resolution is a workload mitigation, not proof all lag is fixed.

Launcher fixes: disallow overlapping status checks, bound subprocess time,
replace inherited output pipe with private temporary file, cap output tail,
and prevent stale status from overwriting an active operation.

## Xianyu login lost — unresolved
During capture main process remained alive; recent 6,000 logcat lines had no
FATAL EXCEPTION, ANR, explicit SESSION_EXPIRED/TOKEN_EXPIRED/logout/kickout.
Exit-info contained no recorded Xianyu exit. Device clock matched host (1s).
Persistent userdata path was correct. No data clearing, account modification,
certificate interception or device identity spoofing performed.

Need a reproduction distinguishing app crash vs account sign-out and capturing
the event's time/error. Current logs do NOT justify attributing it to server risk
controls or claiming it fixed. User must complete login/verification themselves.
Capture locally just after the event:

```
python3 tools/diagnose.py --serial emulator-5554 --output diagnostics/latest
```

`--logcat` additionally stores raw logs locally; these can contain personal data.
Never commit/upload raw captures or camera screenshots. Diagnostics are ignored
by Git. No credentials, userdata or raw captures belong in the public repository.

720×1600 control: immediately after boot 213 frames, median 23ms, p95 48ms,
18.31% deadline jank; repeated after warm-up 274 frames, median 19ms,
p95 38ms, 4.01% deadline jank. Mixed results and different boot/cache states:
not a controlled proof of improvement; more repeated A/B tests are needed.
The local installed app now exposes the opt-in mode. Xianyu remains installed
with its original package/data after the restart. User login retention must
be checked by reproducing the account sign-out, not inferred from package presence.
