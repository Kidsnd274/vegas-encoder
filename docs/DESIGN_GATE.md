# Stop point before app design

The user now reports the app plan/design is complete on another branch. The local
remote ref `origin/product-ui-design` is available; it has not been merged or
approved for implementation in this foundation task. The user explicitly left its
review for next time and requested a foundation commit now. Current implementation is limited to the VEGAS integration
foundation. It supports the Render As exporter: rendered video/audio, host lifecycle,
configuration exchange and saved render templates. The fixed external FFmpeg path
validates media delivery and cleanup. The one-checkbox page is a temporary proof.

## Continue now

1. Resolve native page/holder ownership and connect the minimal settings page safely.
2. Verify the proof setting reaches Render. The real on/off renders pass; Apply,
   unapplied Cancel and saved-byte reload pass in the fake host. The user explicitly
   deferred real two-template/restart testing; keep persistence unverified in the
   support notes and revisit during product qualification.
3. Finish real-host repeat, cancellation/recovery and genuine failure checks with
   useful errors and no leaked process/frame/partial output.

Normal real rendering and the setting's on/off effects pass. Native ownership is
resolved for the current target; the opt-in configuration proof passes 67 checks
and fake-host setting round-trip/recovery tests. The new installed candidate
corrects generic progress failures being mistaken for cancellation.
Real cancellation/recovery now passes on the installed build; controlled failure
recovery and deferred persistence remain qualification limits. See
[configuration follow-up](NATIVE_CONFIGURATION.md).

## Tell the user to stop here

Report implementation readiness and its remaining qualification limits, commit
the foundation as requested, and stop. Review the user's existing app-design
branch only in the later stage they requested. Do not claim the deferred
persistence or unobserved controlled-failure test passed.

This is the point to decide workflows, screen layouts, navigation, desktop/popup
relationship, basic and advanced controls, preset creation/editing/sharing/versioning,
encoding options and how the two preset layers feel to the user. Choose the desktop
framework and full settings/recipe model with those decisions available.

Until the user's design branch is reviewed for the next implementation stage,
stop before building the preset library, codec
catalog, rich editor, app shell, or final UI framework integration. Keep the minimal
page and proof value replaceable. Native adapter, media ownership, timing and encoder
lifecycle remain reusable foundation work.

Further general VEGAS automation, SDK reconstruction, benchmarking and format
expansion are outside this gate unless necessary to make the current integration
reliable. Offline tests alone cannot complete real-host qualification.
