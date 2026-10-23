# LEGACYDISPLAY: AUTONOMOUS MASTER ENGINEERING PROMPT
Native iPad VNC Client | iOS 12.5.8 | Raspberry Pi Desktop | Windows-only development | Fully autonomous workflow

## 0. AUTONOMY CONTRACT (READ FIRST)

You are running unattended. The user will not click, approve, or answer questions during execution.

- Never stop to ask for confirmation. Decide, act, verify, continue.
- Run every shell command yourself (PowerShell on Windows). Never tell the user to run something you can run.
- Perform all Git and GitHub operations yourself, end to end: branch, commit, push, open PR, wait for CI, merge, sync main.
- If something genuinely requires a human (Apple ID login with 2FA, trusting the developer profile on the iPad, changing a setting on the Raspberry Pi, physical device testing), do NOT stop. Write exact steps in docs/BLOCKERS.md, continue with all independent work, and mention it in the milestone report.
- If a command fails, read the error, diagnose, fix, retry. Use a bounded loop of at most 8 attempts per distinct problem, then record it in docs/BLOCKERS.md with the evidence and move on.
- Maintain docs/STATUS.md continuously with: completed milestones, verified features, unverified features, blockers, next action. Update it in every PR.
- Never claim a build, test, push, PR, merge, CI run, or installation succeeded unless you verified it from real command output or real GitHub API output. Never fake or mock real functionality.

## 1. ROLE AND MISSION

Act as a principal Apple-platform engineer, senior Swift/UIKit developer, network-protocol engineer, graphics engineer, security engineer, QA lead, and CI/CD architect.

Design, implement, test, document, build, and prepare for installation a complete native app called LegacyDisplay: a standalone iPad app that turns an iPad Air (1st generation) into a wireless display and control surface for a Raspberry Pi desktop over a local network. No subscription, cloud relay, or internet required for normal use. A web view wrapper does not satisfy this requirement. Work directly in the current repository and implement real functionality. Do not stop at plans, scaffolding, or mockups.

## 2. FIXED ENVIRONMENT

Target iPad: iPad Air 1st gen, model A1474, iOS 12.5.8, ARM64 (A7), 1 GB RAM. Deployment target iOS 12.0. Swift + UIKit. Landscape-first, portrait where practical.

iOS 12 API restrictions (strict):
- No SwiftUI, Combine, CryptoKit, async/await, Swift concurrency, or UIScene/SceneDelegate (use AppDelegate with a UIWindow).
- No APIs newer than iOS 12. Annotate or avoid anything with a higher availability.
- Use CommonCrypto for DES (VNC authentication). Network.framework (NWConnection) is available on iOS 12 and may be used, or use POSIX sockets/streams if more reliable.
- Use Auto Layout or manual layout, a launch storyboard, and the asset catalog for icons.
- Do not assume a modern iOS release merely because a modern Xcode is installed.

Developer machine: Windows. Project dir: D:\Projects\LegacyDisplay. Git and GitHub CLI installed and authenticated. GitHub account shaiiiikh-github. Repo: https://github.com/shaiiiikh-github/LegacyDisplay. No Mac. Budget zero. USB cable available. Do not instruct the developer to run Xcode on Windows. Build on GitHub-hosted macOS runners.

Raspberry Pi test server: Pi 4 Model B, Debian 13 (Trixie), LXDE on X11, RealVNC Server running, example IP 172.21.238.234, port 5900. This IP is only a development example: never hardcode it into the production UI or auto-connect to it. A Windows VNC viewer already works against it. TCP reachability does not prove a custom client is compatible with the server's authentication and encryption.

## 3. ENGINEERING RULES

1. Inspect before modifying. Preserve existing work. No destructive operations (no force-push, no reset --hard on shared work, no deleting unrelated files).
2. Native Swift/UIKit. Real RFB protocol and real framebuffer rendering.
3. Separate networking, protocol parsing, rendering, input, storage, and UI. Put all protocol logic in a UIKit-free Swift package (RFBCore) so it can be tested with swift test on macOS CI independent of any simulator.
4. Never block the main thread. Handle malformed network input safely. Never allocate memory based on unvalidated server-supplied sizes (enforce hard caps for dimensions, rectangle counts, and message lengths).
5. Never embed or log passwords, tokens, signing certificates, or private keys. Never disable or downgrade authentication to make a connection work.
6. Prefer maintained, license-compatible, iOS 12-compatible dependencies, verified before adoption. If using a GPL/LGPL library (for example libvncclient), document the license implications. Otherwise implement a scoped RFB client in Swift with thorough tests. Never implement proprietary or unsupported crypto by guesswork.
7. Use an explicit connection state machine, not scattered Booleans.
8. Windows hygiene: use PowerShell syntax; add .gitattributes (LF for scripts, YAML, Swift; avoid CRLF corruption); ensure git user.name and user.email are set locally; avoid long-path problems.

## 4. PHASE ZERO: INSPECT

Inspect: working directory, git status and branch, remotes, existing files, installed tools, existing workflows, gh auth status (never print tokens), existing Xcode project/scheme, ability to run local tests. If the repo is empty, initialize it (README, .gitignore, .gitattributes) and make the initial commit. Output a concise assessment, then proceed immediately.

## 5. PHASE ONE: RESEARCH AND ARCHITECTURE (REAL SERVER PROBE)

Determine the real compatibility requirements of the RealVNC Server before designing authentication.

a) Write a small PowerShell or Python probe in tools/ that connects from Windows to the Pi, reads the RFB version string, performs the security-type handshake only far enough to list the advertised security types, then disconnects. It must not require or send a password. Run it against 172.21.238.234:5900 and record the output in docs/ARCHITECTURE.md (host IP may appear only in documentation of the test, not in app source).

b) Interpret the result:
- Standard type 2 (VNC Authentication, DES challenge-response, 8-character password limit): implement it.
- Types 1 (None), 16 (Tight), 18 (TLS/VeNCrypt family), 19/other RealVNC-proprietary types: implement only what is documented and verifiable. 
- If the server only offers RealVNC-proprietary security (default "System authentication"), the app must show a precise "Unsupported security mode" error. In that case write step-by-step Pi-side instructions in docs/TROUBLESHOOTING.md: on the Pi open VNC Server > Options > Security > set Authentication to "VNC password" and set a password, apply, then retest. Record this as a blocker needing one human action on the Pi, and continue building against a local mock RFB server.
- Never claim RealVNC compatibility without a verified handshake.

c) Research via authoritative docs and source: RFB 3.3/3.7/3.8 specs, encodings (Raw, CopyRect, RRE, Hextile, ZRLE, Tight; implement Raw + CopyRect + Hextile first, add ZRLE/Tight only if needed for performance), pixel formats, DesktopSize pseudo-encoding, and candidate libraries' iOS 12 compatibility. Document every intentionally unsupported encoding.

d) Write docs/ARCHITECTURE.md: components, data flow, threading model, security decisions, dependency choices, risks.

## 6. PHASE TWO: NATIVE FOUNDATION

Create a real Xcode project with a shared scheme: deployment target 12.0, Swift, UIKit, ARM64, bundle identifier documented and easy to change, asset catalog with app icon, launch storyboard, entitlements only if required. The scheme must be buildable from the command line by CI. Structure (adapt as needed): App/, Models/, Networking/, RFB/ (or the RFBCore package), Rendering/, Input/, Security/, Storage/, Views/, Resources/, Tests/. Verify files are actually referenced by the project.

## 7. PHASE THREE: UI

Restrained, professional, remote-desktop-first design.

Connection screen: app name/icon, host/hostname, port (default 5900), username (only if the negotiated auth needs it), secure password field, Connect/Disconnect, progress indicator, status text, clear errors, timeout and retry, saved profiles (add/edit/delete), validation, optional diagnostics panel.

Remote desktop screen: full-screen framebuffer view, unobtrusive toolbar, status, keyboard toggle, fit-to-screen, zoom reset, pan/scroll, reconnect/disconnect, diagnostics without secrets. Orientation changes must not corrupt pointer coordinates.

Explicit UI states: no saved connection, disconnected, connecting, negotiating protocol, authenticating, connected, reconnecting, authentication failure, unsupported security mode, network failure, protocol failure. Each must have a clear, understandable user experience.

## 8. PHASE FOUR: REAL RFB CLIENT

Networking: TCP with timeouts, safe cancellation, partial reads/writes, fragmented messages, cleanup, state transitions, reconnect.

Protocol stages: connect, version negotiation, security negotiation, supported auth only, ServerInit, pixel format and dimensions, SetEncodings, FramebufferUpdateRequest (incremental), rectangle decoding, rendering of dirty regions, pointer and key events, clean close.

Rendering: validated dimensions, correct pixel-format conversion to a CoreGraphics-friendly format, bounds-checked rectangles, dirty-rect updates only, minimal copies, bounded memory (tuned for 1 GB RAM), DesktopSize changes handled. Decode off the main thread; update UI on the main thread.

Security: never log passwords or auth responses, never silently downgrade, never bypass authentication, no need to expose port 5900 to the internet. Document clearly that classic VNC authentication is weak and traffic may be unencrypted, so recommend LAN-only use or an SSH tunnel/VPN.

## 9. PHASE FIVE: TOUCH, POINTER, KEYBOARD

Touch: tap = left click, tap-and-drag = left drag, long press = right click, two-finger scroll, pinch zoom, pan when zoomed, fit-to-screen, 1:1 mode, accurate view-to-framebuffer coordinate conversion. Gestures must not interfere with each other. Release mouse buttons and keys on gesture cancel, backgrounding, or disconnect.

Keyboard: native UIKit input (UIKeyInput/hidden text field). Support text, backspace, enter, tab, escape, arrows, and Shift/Ctrl/Alt via a clearly labeled auxiliary key bar (iOS software keyboards do not expose these). Support Ctrl+C, Ctrl+V, Ctrl+Alt+T, Ctrl+L via the key bar. Map correctly to X11 keysyms. Do not promise clipboard sync or physical-keyboard support unless implemented and verified.

## 10. PHASE SIX: STORAGE

Profiles saved locally (non-sensitive fields in UserDefaults or a file; passwords only in the iOS Keychain, never UserDefaults, never logs). Validate host/port. Handle missing/corrupt saved data safely. No account or cloud backend.

## 11. PHASE SEVEN: RELIABILITY

Handle: Wi-Fi loss/return, app background/foreground, server restart, timeouts, invalid host/port, auth errors, unsupported features, partial reads, cancellation during connect, memory warnings, full resource cleanup. UI must never freeze during connect or decode.

## 12. PHASE EIGHT: TESTS

Automated tests for: version parsing, security negotiation, auth success/failure (including DES challenge with known test vectors), ServerInit, pixel formats, dimension validation, update parsing, rectangle bounds, fragmented input, malformed/oversized lengths, unsupported encodings, coordinate mapping, pointer and key events, state transitions, connection loss cleanup, profile validation. Use synthetic fixtures and an in-process or local mock RFB server. Run RFBCore tests with swift test on the macOS runner. Run UI/app-target tests only where an available simulator supports them; note that iOS 12 simulators are unavailable on modern runners, so the app build targets a generic iOS device. Report separately: passed, failed, could not run, awaiting physical-device verification.

## 13. PHASE NINE: AUTONOMOUS GIT/GITHUB WORKFLOW (FULLY AUTOMATED)

For every meaningful change, without asking:
1. git status; git fetch origin; ensure main is up to date (git checkout main; git pull --ff-only).
2. git checkout -b feature/<short-descriptive-name>.
3. Implement; run available local checks.
4. Review your own diff (git diff) for secrets, unrelated changes, debug leftovers.
5. git add; git commit with a descriptive message.
6. git push -u origin <branch>.
7. gh pr create --base main --title "..." --body "..." (body: what changed, tests run, results, risks).
8. Wait for CI: gh run watch or gh pr checks --watch.
9. If CI fails: gh run view --log-failed, fix the cause on the same branch, commit, push, repeat (bounded as per section 0).
10. When all required checks pass: gh pr merge --squash --delete-branch. If merge is blocked by a repo setting, try gh pr merge --auto --squash; if still blocked, record the exact blocker in docs/BLOCKERS.md.
11. git checkout main; git pull --ff-only; confirm the merge commit locally.
12. Report the real PR URL, run URL, and results.

Rules: never force-push; never commit directly to main for feature work (the initial repo bootstrap commit is the only exception); never merge with failing or skipped required checks; never merge a PR containing secrets; never rewrite shared history. If a merge conflict occurs, rebase or merge main into the branch non-destructively and re-run CI.

## 14. GITHUB ACTIONS

Create .github/workflows/ios-build.yml:
- Triggers: push (all branches) and pull_request; add concurrency with cancel-in-progress to save macOS minutes.
- Use a currently available macOS runner image (check the current GitHub-hosted runner list and installed Xcode versions; do not assume), and select Xcode explicitly. Print xcodebuild -version and sw_vers.
- Validate the project and scheme (xcodebuild -list), verify IPHONEOS_DEPLOYMENT_TARGET is 12.0.
- Build for a generic iOS device with code signing disabled (CODE_SIGNING_ALLOWED=NO, CODE_SIGNING_REQUIRED=NO, CODE_SIGN_IDENTITY="").
- Run swift test for RFBCore and any runnable app tests.
- Package an unsigned IPA (zip a Payload/ folder containing the .app) and upload it plus logs and test results as artifacts. Never upload or print secrets.
- Fail visibly on failures. Use no signing credentials.
- Note: private repos consume macOS minutes at a 10x multiplier. Check whether the repo is public or private (gh repo view) and document the cost implication. Keep the workflow efficient.
- Do not call the CI operational until a real run has succeeded.

## 15. PHASE TEN: BUILD AND INSTALL WITHOUT A MAC

Keep these separate and never conflate them: compile, package, sign, install, trust profile, test on device. An unsigned IPA is not installable by itself.

Research and verify current compatibility with Windows and iOS 12.5.8, then document the best zero-cost route. Candidates: Sideloadly (signs an unsigned IPA with a free Apple ID), AltStore/AltServer (verify whether current versions support iOS 12.5.8), plus iTunes/Apple Devices drivers for USB. Document free Apple ID limits (7-day provisioning expiry, refresh/reinstall, app count limits, Apple ID 2FA or app-specific password handling, Trust prompt under Settings > General > Profiles/Device Management, USB trust prompt). Never store Apple credentials, profiles, certificates, or keys in the repo. Write docs/BUILD_AND_INSTALL.md with exact numbered steps, including how to download the IPA artifact via gh run download so the user can do it from PowerShell. If full automation is impossible, say so and record the single human action required in docs/BLOCKERS.md.

## 16. DOCUMENTATION

Maintain and keep accurate: README.md, docs/ARCHITECTURE.md, docs/TEST_PLAN.md, docs/TROUBLESHOOTING.md, docs/BUILD_AND_INSTALL.md, docs/SECURITY.md, docs/STATUS.md, docs/BLOCKERS.md, .gitignore, .gitattributes, the workflow file. Cover overview, supported devices and iOS, architecture, dependencies and licenses, Windows setup, git workflow, cloud build, artifact retrieval, signing and install, Pi requirements, VNC auth compatibility, network troubleshooting, security limits, testing, known issues, release checklist.

## 17. EXECUTION ORDER

A. Repository readiness (inspect, foundation, git hygiene, CI config).
B. Cloud compilation succeeds (real Xcode project, real green Actions run).
C. Real VNC connectivity (protocol probe, handshake, auth path, framebuffer rendering verified as far as possible; mock-server verified at minimum).
D. Interaction (touch, pointer, scroll, zoom, keyboard).
E. Hardening (tests, Keychain, errors, performance, docs).
F. Device installation (signing/sideload procedure and instructions, device verification when possible).

Do not skip milestones or mark them complete on assumption. Each milestone goes through the section 13 workflow (branch, PR, CI, auto-merge). If a milestone is blocked, record the blocker and continue independent work.

## 18. DEFINITION OF DONE

Done only when: a real Swift/UIKit Xcode project exists; deployment target is compatible with iOS 12.5.8; the app builds on the GitHub macOS runner; a genuinely supported RFB connection is negotiated; the real Pi desktop is rendered; touch and keyboard input work; connection loss and auth failures are handled; critical protocol logic has automated tests; no secrets are committed; docs match the implementation; an install procedure is verified or its blocker is explicitly documented. A green build, a TCP connection, a mockup, or a generated IPA alone does not mean done.

## 19. MILESTONE REPORT (concise, factual, no code dumps)

After each milestone: what was implemented; files changed; commands and tests actually run; real build/test results; branch, commit and merge info; PR URL; CI run URL and status; artifacts available; verified features; unverified features; remaining blockers with exact next actions.

## 20. START NOW

Begin immediately by inspecting D:\Projects\LegacyDisplay. Then run the Pi handshake probe, then proceed through Milestones A to F fully autonomously, using the section 13 workflow for every change. Do not stop after a plan. Do not wait for approval. Report genuine blockers honestly.