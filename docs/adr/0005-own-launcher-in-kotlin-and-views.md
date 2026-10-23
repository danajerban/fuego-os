# Our own Launcher, in Kotlin with plain Android Views

We write the Launcher ourselves (app ID `io.github.danajerban.fuegoos`) instead of forking CleanYourTV, and borrow its proven pieces (the blur trick, the cached glass, the HOME manifest setup, the disable/restore notes) under its MIT licence, with attribution kept in THIRD_PARTY_NOTICES.md and the source files. CleanYourTV's approach matches ours, but its 3,000-line `MainActivity` changes daily and we would delete 60 to 70% of the code ([cleanyourtv-review.md](../research/cleanyourtv-review.md)).

The stack is Kotlin and plain Views, with no Compose, no image-loading or analytics libraries, no INTERNET permission, and code shrinking on. On a TV with about 2 GB of RAM, Views mean no Compose runtime to load, a faster cold start, mature D-pad focus handling, and cheap focus motion on hardware layers ([cleanyourtv-review.md](../research/cleanyourtv-review.md), "Views over Compose").
