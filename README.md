# VLC Deleter

Send the currently playing local file to the Windows Recycle Bin from **View > Recycle current video** in VLC. No AutoHotkey or additional runtime installation is required.

## Requirements

- Windows 10 or 11 with Windows PowerShell 5.1 (included with Windows).
- VLC 3.0.x desktop. VLC 4 is not supported yet.
- Files on a fixed local drive with a working Recycle Bin. Network shares, removable drives, folders, and reparse points are rejected.

## Install

Download this repository using **Code > Download ZIP**, extract it, and open PowerShell in the extracted folder. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Restart VLC completely. Open a video and choose **View > Recycle current video**. Installation is per user and does not require administrator rights. The execution-policy option applies only to that PowerShell process; it does not change your saved policy. Managed computers may block PowerShell scripts.

## Behavior

- A single file: stop playback and recycle the file.
- A playlist: recycle the file, remove its entries, then play the next distinct file in playlist order.
- The last item: stop, without wrapping to the beginning.
- Duplicate entries with the exact same URI are removed together.
- Shuffle and repeat do not change this action's next-item selection.
- On failure, keep the playlist entries and show an error. Playback may remain stopped.
- The action runs immediately, without a confirmation. Restore recycled files through the Windows Recycle Bin.

The in-memory playlist is updated; saved playlist files are not rewritten. This first version uses a menu action and has no global keyboard shortcut. The operation can take a few seconds while Windows starts the helper and VLC releases the file.

## How it works

The Lua extension captures the current URI and playlist entry, stops playback, and calls a PowerShell helper. Filenames are passed as encoded data, never interpolated into executable commands. A small C# wrapper compiled by built-in PowerShell calls Windows `IFileOperation` with recycling and undo flags. There is no permanent-delete command or fallback in the helper.

The extension changes the playlist only after the helper reports success. Each helper process handles one captured file and then exits; there is no background service or network listener.

## Uninstall

Close VLC. In `%APPDATA%\vlc\lua\extensions`, delete `vlc-deleter.lua` and the `vlc-deleter` helper folder. Restart VLC.

## Development

Source is in `src/`. Run `tests/Test-Helper.ps1` for helper validation and disposable-file Recycle Bin checks. The tests create their own files under `tests/tmp`; they never use your videos. See `tests/README.md` for playback checks.

API references: [VLC Lua API](https://github.com/videolan/vlc/blob/3.0.x/share/lua/README.txt), [Windows file-operation flags](https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags).

MIT licensed. See [LICENSE](LICENSE).
