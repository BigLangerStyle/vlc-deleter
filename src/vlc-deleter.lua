-- Copyright (c) 2026 Stephen Langer. MIT license.
function descriptor()
    return {
        title = "Recycle current video", version = "0.1.0", author = "Stephen Langer",
        shortdesc = "Recycle current video",
        description = "Send the current local file to the Windows Recycle Bin and play the next playlist entry.",
        capabilities = {}
    }
end

local dialog
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(value)
    local out = {}
    for i = 1, #value, 3 do
        local a, b, c = value:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local function digit(shift)
            local index = math.floor(n / shift) % 64 + 1
            return alphabet:sub(index, index)
        end
        out[#out + 1] = digit(262144) .. digit(4096)
            .. (b and digit(64) or "=") .. (c and digit(1) or "=")
    end
    return table.concat(out)
end

local function report(message)
    vlc.msg.err("[vlc-deleter] " .. message)
    dialog = vlc.dialog("Recycle current video")
    dialog:add_label(vlc.strings.convert_xml_special_chars(message), 1, 1)
    dialog:add_button("Close", close, 1, 2)
end

local function leaves(node, out)
    if node.children then
        for _, child in ipairs(node.children) do leaves(child, out) end
    elseif node.path then
        out[#out + 1] = node
    end
end

local function recycle()
    local item = vlc.input.item()
    if not item then return report("No file is currently playing.") end
    local uri, current = item:uri(), vlc.playlist.current()
    if not uri or not uri:match("^file:///[A-Za-z]:/") then
        return report("Only files on local Windows drives can be recycled.")
    end
    local entries = {}
    leaves(vlc.playlist.get("playlist", true) or {}, entries)
    local found, next_id, remove_ids = false, nil, {}
    for _, entry in ipairs(entries) do
        if entry.id == current then found = true
        elseif found and not next_id and entry.path ~= uri then next_id = entry.id end
        if entry.path == uri then remove_ids[#remove_ids + 1] = entry.id end
    end
    if not found then return report("The playing item is not in the editable playlist.") end
    local helper = vlc.config.userdatadir() .. "/lua/extensions/vlc-deleter/Recycle-File.ps1"
    local file = vlc.io.open(helper, "rb")
    if not file then return report("Helper is missing. Run Install.ps1 and restart VLC.") end
    file:close()

    -- Both variable strings travel as UTF-8 base64 data. The command itself is
    -- ASCII encoded as UTF-16LE for PowerShell: filenames never become code.
    local script = "$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"
        .. base64(helper) .. "')); & $p -UriBase64 '" .. base64(uri) .. "'"
    local encoded = base64((script:gsub(".", function(c) return c .. "\0" end)))
    if vlc.playlist.current() ~= current then return report("Playback changed. Try again.") end
    vlc.playlist.stop()
    local pipe = io.popen("powershell.exe -NoLogo -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand " .. encoded, "r")
    if not pipe then return report("Could not start Windows PowerShell. The playlist entry was kept.") end
    local result = pipe:read("*a") or ""
    pipe:close()
    if not result:match("^RECYCLED%s*$") then
        return report("Recycling failed; the playlist entry was kept. " .. result:sub(1, 600))
    end
    for _, id in ipairs(remove_ids) do vlc.playlist.delete(id) end
    -- Do not replace playback started manually while the helper was running.
    if next_id and vlc.playlist.status() == "stopped" then vlc.playlist.goto(next_id) end
    vlc.deactivate()
end

function activate()
    local ok, err = pcall(recycle)
    if not ok then report("Could not finish recycling: " .. tostring(err)) end
end
function deactivate()
    if dialog then dialog:delete(); dialog = nil end
end
function close() vlc.deactivate() end
