# NoirTasks

A native macOS task organiser built with SwiftUI. It combines daily planning, a weekly board, recurring tasks and floating desktop widgets.

## Features

- Lists, priorities, subtasks and tags parsed from task titles.
- Daily and weekly planning with recurrence and completion statistics.
- Desktop task widgets and menu-bar quick entry.
- Optional Apple Calendar access and notifications, subject to macOS permissions.

## Build and run

Requires macOS 13+, Swift 5.9+ and Apple Command Line Tools.

```sh
swift build -c release
./build-app.sh
open build/NoirTasks.app
```

The script creates an ad-hoc signed app inside the project’s ignored `build/` directory. It is not notarised or distributed through the App Store.

## Structure

`Sources/NoirTasks/` contains the app and views. `Package.swift` defines the executable; `Info.plist` declares app permissions. `scripts/make-icon.swift` generates the icon.

## Data and privacy

Tasks persist in `~/Library/Application Support/NoirTasks/data.json`. That user-data file is not included. Calendar access is optional and requires permission. Export or back up important data separately; this prototype has no managed cloud backup.

## Status

Personal desktop prototype. This source publication does not establish compatibility with every macOS version, complete accessibility coverage or automated UI test coverage. Changes to permissions and recurrence should be manually checked before relying on them.
