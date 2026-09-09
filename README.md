# Alert Me

Alert Me is a native macOS 26 Tahoe app for one-time and recurring popup alerts.

## Getting started

Open `AlertMe.xcodeproj` in Xcode 26.6 or later, select the `AlertMe` scheme, and run the app.

To install Alert Me as a normal app that can be opened without starting Xcode:

```shell
./scripts/install.sh
```

This creates `~/Applications/Alert Me.app` and asks Spotlight to index it. After installation, press <kbd>Command</kbd>+<kbd>Space</kbd>, search for **Alert Me**, and open it like any other Mac app. To install and open it in one command:

```shell
./scripts/install.sh --open
```

Run the installer again whenever you want to replace the installed app with the latest source code.

To use fallback notifications, the app must have a valid development signature:

1. Open **Xcode > Settings > Accounts** and add your Apple ID.
2. Select the `AlertMe` project and the `AlertMe` target.
3. Under **Signing & Capabilities**, select your Development Team.
4. Rebuild the app and copy the newly signed `AlertMe.app` into `/Applications`.
5. Open the installed app and select **Allow Notifications**.

Popup alert windows continue to work while Alert Me is running even if notification permission is unavailable.

## Development

Run the complete test suite after every code or project change:

```shell
./scripts/test.sh
```

The app uses SwiftUI, AppKit, SwiftData, UserNotifications, and ServiceManagement.

## Behavior

- Create one-time, daily, weekly, monthly, or yearly alerts.
- Enter messages of up to 500 characters.
- Fire alerts at second zero as soon as the selected minute begins.
- Set dates and times independently in the alert editor, or use **Now** to copy the current date and time.
- Display one-time alert dates as `09 September 2026`.
- Choose the app-wide default macOS system sound under **Alert Me > Settings**. Individual alerts can be silent.
- Close the management window without stopping scheduled alerts.
- Enable **Open Alert Me at login** in Settings for improved reliability.
- Keep Alert Me out of the Dock by default, or enable **Show Alert Me in the Dock** in Settings.
- Use Light mode by default, with a Light/Dark choice under **Alert Me > Settings**.

When a non-silent popup appears, Alert Me plays the selected sound immediately and then every five seconds up to 20 additional times. Dismissing the popup stops the sequence. Deleting an alert takes effect immediately without a confirmation dialog.

Missed alerts are recorded but are not replayed after the Mac wakes or the app reopens. Explicitly quitting or force-quitting the app prevents popup alerts until it is opened again. A fallback notification is delayed briefly and canceled when the app popup appears, so both are not intentionally displayed for the same occurrence. Fallback notifications use the default notification sound because macOS notification sounds must be bundled with the app.

## Manual verification

Some operating-system integrations cannot be verified reliably in automated tests:

1. Grant and deny notification permission, then confirm the Settings guidance.
2. Run a signed app bundle and verify launch-at-login registration.
3. Confirm the alert panel appears over other apps, Spaces, and full-screen apps.
4. Put the Mac to sleep across an alert time and confirm the missed alert is not replayed.
5. Confirm explicitly quitting the app stops popup alerts until relaunch.
6. Preview each listed system sound and confirm silent alerts do not play it.
