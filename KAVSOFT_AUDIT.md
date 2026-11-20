# Kavsoft audit

Every Kavsoft example in the user's `everything` folder, against Shirox as
of this arc. Statuses: fully implemented / partially implemented / broken /
missing / not requested.

| Example | Purpose | Status in Shirox | Where | Notes |
| --- | --- | --- | --- | --- |
| ASplashScreen | Carry-on splash: icon shrink, push, onboarding reveal; mask-expansion for later launches | Fully implemented (this arc fixed the broken sizing) | Shirox/Views/Onboarding/LaunchScreen.swift | Was broken: the splash logo had no size constraint, so the 1024pt ShiroMark asset rendered at natural size and filled the screen several times over. Both stages now draw the mark at a fixed 90pt and cross-fade into the 150pt icon, and the mask-expansion logo is constrained the same way. Timing, springs and the two variants match the reference. |
| GooeyRefreshable (MorphingRefreshable) | Pull to refresh: capsule in the Dynamic Island, circle dropping out, blur + alphaThreshold GPU merge | Fully implemented (this arc fixed the positioning everywhere) | Shirox/Views/Shared/MorphingRefresh.swift + AlphaThreshold.metal | Was broken: the blob positioned itself from the scroll view's LOCAL safe area, which full-bleed pages (Home's hero, both detail pages) read as zero and bar-padded pages inflate; the blob landed off screen or mid-page. Now anchored to the window's hardware top inset and shifted by the scroll view's own offset, so it grows out of the island on every page that can pull. |
| HCalendarView | Horizontal week calendar with day selection | Fully implemented (previous arc) | Shirox/Views/Shared/HorizontalCalendar.swift, UpcomingCalendarView.swift | Ported earlier; this arc only fixed how the page presents (no zoom transition, no drag-down dismissal). Days stay in a continuous horizontal row. |
| WSSection | Sticky section cards as rows scroll | Implemented, then withdrawn from Home per the user | Shirox/Views/Shared/StickySection.swift | The port works, but the user never asked for Home's sections to live inside cards: the three Home sections (AnimeSection, Continue Watching, Continue Reading) are restored to the original plain header-over-shelf layout. The component stays in the tree for possible reuse. |
| TWTextEffect | Typewriter text | Fully implemented (previous arc) | Shirox/Views/Onboarding/TypeWriterHeadline.swift | Runs on the redesigned onboarding's welcome page, iOS 18+. |
| AMSheets | Custom sheet presentation | Partially implemented | Shirox/Views/Shared/View+AdaptiveSheet.swift | The app uses system sheets through the adaptiveSheet shim rather than the full AMSheets custom presentation; the zoom grow-from-source variants (zoomSource/zoomingOut/toolbarZoomSource) are ported and in use. |
| ATPicker | Animated theme picker with capsule selection | Fully implemented (previous arc) | Shirox/Views/SettingsPickers.swift (ThemePickerSheet) | The @Namespace scope error Codemagic build 2 caught was here; fixed and green since. |
| AIPicker | Animated app icon picker | Fully implemented (previous arc) | Shirox/Views/SettingsPickers.swift (IconPickerSheet) | Carousel scene on iOS 26, plain picker below. |
| CompactNotificationView | Compact in-app notification UI | Partially implemented / superseded | Shirox/Views/Notifications/NotificationsTabView.swift | Shirox's notifications are AniList feeds, not the reference's local notification UI; the bell page and its unread badge carry the role. The reference's exact component was never requested by name. |
| SToasts | Stacked glass toasts | Fully implemented (previous arc) | Shirox/Views/Shared/Toast.swift | ToastManager API unchanged. |
| HView | Highlighted text view | Not requested | - | No Shirox screen asked for inline highlight markup; left out on purpose. |
| WSSection For Xcode 26 | The same sticky sections, Xcode 26 variant | Superseded by the port above | Shirox/Views/Shared/StickySection.swift | The single port covers both via its own availability ladder. |

Rules kept from the user's brief: no example is inserted into unrelated
screens, a Swift file with a matching name is not proof of a working port,
and every port runs on the app's iOS 15 floor through the availability
ladders (blob 18+, typewriter 18+, glass 26+).
