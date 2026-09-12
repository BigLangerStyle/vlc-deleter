# VLC Deleter

Permanently delete the currently playing file from **View > Delete current video** in VLC, then play the next playlist entry.

**The action deletes immediately, without confirmation or the Recycle Bin.**

## Requirements

- Windows 10 or 11 with Windows PowerShell 5.1 (included with Windows).
- VLC 3.0.x desktop. VLC 4 is not supported yet.
- Files on fixed, removable (including USB and SD), or mapped network drives. Direct UNC paths, folders, and reparse points are rejected.

## Install

Download this repository using **Code > Download ZIP**, extract it, and open PowerShell in the extracted folder. Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Restart VLC completely. Open a video and choose **View > Delete current video**. Installation is per user and does not require administrator rights. The execution-policy option applies only to that PowerShell process; it does not change your saved policy. Managed computers may block PowerShell scripts. Re-running the installer upgrades the extension and removes the obsolete recycling helpers.

## Behavior

- A single file: stop playback and permanently delete the file.
- A playlist: delete the file, remove its entries, then play the next distinct file in playlist order.
- The last item: stop, without wrapping to the beginning.
- Duplicate entries with the exact same URI are removed together.
- Shuffle and repeat do not change this action's next-item selection.
- Validate the target before stopping playback. If validation fails, playback stays unchanged.
- If deletion fails after stopping, keep the playlist entries and show an error. Playback may remain stopped.
- The action runs immediately, without a confirmation. Files do not go to the Recycle Bin.

The in-memory playlist is updated; saved playlist files are not rewritten. This first version uses a menu action and has no global keyboard shortcut. The operation can take a few seconds while Windows starts the helper and VLC releases the file.

## How it works

The Lua extension captures the current URI and playlist entry, validates the target using a PowerShell helper, and checks that the playing item has not changed. It then stops playback and invokes the helper's deletion mode. Filenames are passed as encoded data, never interpolated into executable commands. The helper uses .NET's exact-path file deletion after briefly waiting for VLC to release its handle.

The extension changes the playlist only after the helper reports success. Each helper process handles one captured file and then exits; there is no background service or network listener.

## Uninstall

Close VLC. In `%APPDATA%\vlc\lua\extensions`, delete `vlc-deleter.lua` and the `vlc-deleter` helper folder. Restart VLC.

## Development

Source is in `src/`. Run `tests/Test-Helper.ps1` for helper validation and disposable-file deletion checks. Tests create their own fixtures under `tests/tmp` by default; they never use your videos. See `tests/README.md` for playback checks and testing another drive.

API reference: [VLC Lua API](https://github.com/videolan/vlc/blob/3.0.x/share/lua/README.txt).

MIT licensed. See [LICENSE](LICENSE).
