# Verification

From a PowerShell prompt in the repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Helper.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Extension.ps1
```

The helper test creates a uniquely named disposable file, verifies validation and locked-file rejection, recycles it, and checks its presence in the Windows Recycle Bin. It leaves that small fixture in the bin for inspection.

The extension test loads VLC's installed Lua runtime DLL into the test PowerShell process. PowerShell and VLC must have matching bitness (normally both 64-bit). It tests single-item, ordered-playlist, last-item, duplicate, failure, stream, missing-helper, and manually-changed playback scenarios with mocked playback APIs, without starting VLC or changing its configuration.

It also installs into a temporary directory and exercises the actual Lua-to-PowerShell command on a disposable Unicode-named file. This checks the installer layout, command encoding, helper invocation, and successful playlist updates together.

For end-to-end manual testing, install the extension and use copies of short videos:

1. Play one copy, invoke the View action, and check that playback stops and the copy appears in the Recycle Bin.
2. Play the first of three copies and verify the next starts after recycling.
3. Repeat on the final entry; playback should stop.
4. Try a filename containing spaces, non-ASCII characters, and an emoji.
5. Lock a copy in another program; check that failure retains its playlist entry.
6. Enable repeat and shuffle; the deletion action should still advance in displayed playlist order.

Automated playback mocks do not establish native View-menu behavior or real playback transitions. Record those separately when tested.

Verified on Windows with VLC 3.0.23: all 10 extension scenarios and helper checks pass, including actual Recycle Bin presence. Native View-menu and playback-transition checks remain manual.
