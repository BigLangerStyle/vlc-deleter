# Verification

From a PowerShell prompt in the repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Helper.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Extension.ps1
```

The helper test creates a uniquely named disposable file, verifies that validation preserves it, checks locked-file rejection, and permanently deletes it. To test a removable drive, pass `-FixtureParent S:\` (or the appropriate drive) to `Test-Helper.ps1`.

The extension test loads VLC's installed Lua runtime DLL into the test PowerShell process. PowerShell and VLC must have matching bitness (normally both 64-bit). It tests single-item, ordered-playlist, last-item, duplicate, failure, stream, missing-helper, and manually-changed playback scenarios with mocked playback APIs, without starting VLC or changing its configuration.

It also installs into a temporary directory and exercises actual Lua-to-PowerShell validation and deletion on a disposable Unicode-named file. This checks the installer layout, command encoding, helper invocation, and successful playlist updates together. Regression scenarios verify that failed validation and a changed playing item do not stop playback or delete files.

For end-to-end manual testing, install the extension and use copies of short videos:

1. Play one copy, invoke View > Delete current video, and check that playback stops and the copy is deleted without a confirmation.
2. Play the first of three copies and verify the next starts after deletion.
3. Repeat on the final entry; playback should stop.
4. Try a filename containing spaces, non-ASCII characters, and an emoji.
5. Lock a copy in another program; check that failure retains its playlist entry.
6. Enable repeat and shuffle; the deletion action should still advance in displayed playlist order.

Automated playback mocks do not establish native View-menu behavior or real playback transitions. Record those separately when tested.

Verified on Windows with VLC 3.0.23: all 12 extension scenarios pass. Helper validation, locked-file rejection, and actual permanent deletion pass on both C: and the user's removable exFAT S: drive. Native playback-transition checks for this version remain manual.
