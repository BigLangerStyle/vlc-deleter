# Testing VLC Deleter

Open PowerShell in the project folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Helper.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-Extension.ps1
```

The helper test creates a disposable file, checks that validation leaves it alone, tries deleting it while it's locked, and finally deletes it after the lock is released. The filename includes spaces, an emoji, and characters that can trip up shell commands.

To check another drive, add `-FixtureParent S:\` to the helper command, replacing `S:` with your drive letter. It will create and delete its own test file there.

The extension test uses the Lua runtime that comes with VLC. PowerShell and VLC need to both be 64-bit or both be 32-bit. It simulates playback to check single videos, playlists, duplicate entries, and errors without opening VLC or changing its settings.

It also installs a temporary copy of the extension and runs the real PowerShell helper on a disposable file. That checks that the pieces work together. Other checks make sure a failed validation or a switch to another video won't stop playback or delete the wrong file.

## Try it in VLC

The automated tests can't tell us everything about the player itself. Install the extension and use disposable copies of short videos for these checks:

1. Play a single video and choose **View > Delete current video**. The file should disappear and playback should stop, with no confirmation.
2. Play the first of three videos in a playlist and delete it. The next one should start.
3. Delete the last video in the playlist. Playback should stop.
4. Try a filename with spaces, accented letters, and an emoji.
5. Hold a file open in another program so Windows can't delete it. The extension should show an error and keep the playlist entry.
6. Turn on shuffle and repeat. Deleting a video should still move to the next one in playlist order.

Record these results separately from the automated tests.

## Results so far

All 12 automated extension scenarios passed using VLC 3.0.23's Lua runtime. The helper tests also passed on an internal drive and a removable exFAT drive. The playback checks above still need to be completed for this version.
