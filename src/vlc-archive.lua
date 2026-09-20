-- Copyright (c) 2026 Stephen Langer. MIT license.
function descriptor()
    return {
        title = "Archive current video", version = "0.4.0", author = "Stephen Langer",
        shortdesc = "Archive current video",
        description = "Move the video into a .archive folder beside it and play the next one.",
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
    vlc.msg.err("[vlc-archive] " .. message)
    if dialog then dialog:delete() end
    dialog = vlc.dialog("Archive current video")
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

local function run_helper(helper, uri, validate_only)
    -- Paths travel as UTF-8 base64 data, never executable command text.
    local script = "$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"
        .. base64(helper) .. "')); & $p -UriBase64 '" .. base64(uri) .. "'"
        .. (validate_only and " -ValidateOnly" or "")
        .. (not validate_only and " -Archive" or "")
    local encoded = base64((script:gsub(".", function(c) return c .. "\0" end)))
    local pipe = io.popen("powershell.exe -NoLogo -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand " .. encoded, "r")
    if not pipe then return "ERROR: Could not start Windows PowerShell." end
    local result = pipe:read("*a") or ""
    pipe:close()
    return result
end

local function archive_current()
    local item = vlc.input.item()
    if not item then return report("Open a video first, then try again.") end
    local uri, current = item:uri(), vlc.playlist.current()
    if not uri or not uri:match("^file:///[A-Za-z]:/") then
        return report("This isn't a file on a drive with a letter, such as C: or S:. Open a file from a drive and try again.")
    end
    local entries = {}
    leaves(vlc.playlist.get("playlist", true) or {}, entries)
    local found, next_id, remove_ids = false, nil, {}
    for _, entry in ipairs(entries) do
        if entry.id == current then found = true
        elseif found and not next_id and entry.path ~= uri then next_id = entry.id end
        if entry.path == uri then remove_ids[#remove_ids + 1] = entry.id end
    end
    if not found then return report("Couldn't find this video in the playlist. Open it from the playlist and try again.") end
    local helper = vlc.config.userdatadir() .. "/lua/extensions/vlc-deleter/Archive-File.ps1"
    local file = vlc.io.open(helper, "rb")
    if not file then return report("Part of VLC Deleter is missing. Run Install.ps1 again, then restart VLC.") end
    file:close()

    -- Validate while VLC is still playing. An unsupported drive must not stop it.
    local validation = run_helper(helper, uri, true)
    if validation:match("^ALREADY%s*$") then vlc.deactivate(); return end
    if not validation:match("^VALID%s*$") then
        return report("Couldn't archive this file. Playback hasn't been interrupted. " .. validation:sub(1, 600))
    end
    local latest = vlc.input.item()
    if vlc.playlist.current() ~= current or not latest or latest:uri() ~= uri then
        return report("VLC has moved to another video. Nothing was archived. Try again on the video you want to archive.")
    end
    vlc.playlist.stop()
    local result = run_helper(helper, uri, false)
    if not result:match("^ARCHIVED%s*$") then
        return report("Couldn't archive this file. It's still in your playlist. " .. result:sub(1, 600))
    end
    for _, id in ipairs(remove_ids) do vlc.playlist.delete(id) end
    -- Do not replace playback started manually while the helper was running.
    if next_id and vlc.playlist.status() == "stopped" then vlc.playlist.goto(next_id) end
    vlc.deactivate()
end

function activate()
    local ok, err = pcall(archive_current)
    if not ok then report("Something went wrong while archiving the video: " .. tostring(err)) end
end
function deactivate()
    if dialog then dialog:delete(); dialog = nil end
end
function close() vlc.deactivate() end
