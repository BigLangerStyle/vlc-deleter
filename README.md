# VLC Deleter

Watching a folder full of videos and want to get rid of one? Choose **View > Delete current video**. VLC Deleter deletes the file you're watching and moves on to the next video in your playlist.

**Deletion is permanent. There's no confirmation, and the file won't go to the Recycle Bin.**

Want to keep a video instead? **View > Favorite current video** adds a period to the start of its filename: `filename.mp4` becomes `.filename.mp4`.

To put one aside, choose **View > Archive current video**. It moves the video into a `.archive` folder beside it and plays the next video.

## What you'll need

- Windows 10 or 11. The extension uses Windows PowerShell, which comes with Windows.
- The desktop version of VLC 3.0.x. VLC 4 isn't supported yet.

You can delete files on internal drives, USB drives, SD cards, and network drives with an assigned drive letter. The extension doesn't handle streams, folders, direct network paths such as `\\server\share`, or paths through symbolic links or junctions.

## Install

Download the project using **Code > Download ZIP** on GitHub. Extract the ZIP, open PowerShell in that folder, and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

Close VLC completely, then open it again. You'll find **Delete current video**, **Favorite current video**, and **Archive current video** in the **View** menu.

You don't need administrator rights. To update, download the latest version and run the installer again.

The command allows the installer to run without changing your saved PowerShell policy. If you're on a work or school computer, your organization's settings may still block it.

## Using it

Play a video and choose **View > Delete current video**. Give it a moment to finish; VLC needs to release the file before Windows can delete it.

If you're watching a single file, playback stops. In a playlist, the deleted video is removed and the next one starts. Deleting the last video stops playback instead of jumping back to the beginning.

A few details to know:

- The next video is chosen in playlist order, even with shuffle or repeat turned on.
- Duplicate entries that point to the exact same file address are removed together.
- Only the playlist open in VLC changes. Saved playlist files aren't updated.
- There's no keyboard shortcut or button on the playback toolbar yet.

If the extension can't use the file, it shows an error and leaves playback alone. If Windows refuses to delete it after playback has stopped, the video stays in your playlist so you can play it again or try later.

### Keeping a favorite

Choose **View > Favorite current video** while watching a file. It adds one period to the filename, keeps it in the same folder, and puts the renamed video at the top of your open playlist. The video reopens from the beginning because VLC needs to release the file for the rename.

Files that already start with a period are left alone. If `.filename.mp4` already exists, you'll get an error; neither file is overwritten. Duplicate playlist entries for the old name are replaced with one entry for the favorite.

The period gives favorites a recognizable prefix when sorting filenames. Sort order depends on the program you're using. To undo it, remove the leading period in File Explorer while the video is closed. Saved playlists and matching subtitle filenames aren't renamed automatically.

### Putting a video in the archive

Choose **View > Archive current video** to move `Videos\clip.mp4` into `Videos\.archive\clip.mp4`. The folder is created if needed. The video leaves your current playlist and the next one starts; archiving the only or last video stops playback.

The filename stays the same, including a favorite's leading period. Subtitles stay where they are. Existing archived files are never overwritten, and videos already inside `.archive` are left alone. If the move fails, the playlist entry stays available.

There's no confirmation. To restore a video, move it back with File Explorer. The folder is named `.archive`, but the period doesn't make it hidden on Windows. Saved playlists aren't rewritten.

## How it works

Each menu action has a Lua script and a small PowerShell helper. Lua keeps track of the playing video and playlist; PowerShell handles deleting, renaming, or archiving the file.

Before stopping playback, it checks the file and makes sure VLC hasn't moved on to another video. It removes the playlist entry only after deletion succeeds. Filenames are passed as encoded data, so spaces and special characters aren't treated as commands.

## Uninstall

Close VLC and open `%APPDATA%\vlc\lua\extensions` in File Explorer. Delete `vlc-deleter.lua`, `vlc-favorite.lua`, `vlc-archive.lua`, and the `vlc-deleter` folder. Your archived videos stay where they are.

## Working on the code

The code lives in `src/`. See the [testing guide](tests/README.md) for automated checks and things to try in VLC. The tests create their own disposable files; they don't use your videos.

API reference: [VLC Lua API](https://github.com/videolan/vlc/blob/3.0.x/share/lua/README.txt).

MIT licensed. See [LICENSE](LICENSE).
