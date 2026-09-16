-- Copyright (c) 2026 Stephen Langer. MIT license.
function descriptor()
    return {
        title = "Favorite current video", version = "0.3.0", author = "Stephen Langer",
        shortdesc = "Favorite current video",
        description = "Add a period to the start of the filename, then reopen the video.",
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
    vlc.msg.err("[vlc-favorite] " .. message)
    if dialog then dialog:delete() end
    dialog = vlc.dialog("Favorite current video")
    dialog:add_label(vlc.strings.convert_xml_special_chars(message), 1, 1)
    dialog:add_button("Close", close, 1, 2)
end

local function leaves(node, out)
    if node.children then
        for _, child in ipairs(node.children) do leaves(child, out) end
    elseif node.path then out[#out + 1] = node end
end

local function entries()
    local list = {}
    local root = vlc.playlist.get("playlist", true) or {}
    leaves(root, list)
    return list, root.id
end

local function run_helper(helper, uri, validate)
    local script = "$p=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('"
        .. base64(helper) .. "')); & $p -UriBase64 '" .. base64(uri) .. "'"
        .. (validate and " -ValidateOnly" or " -Favorite")
    local encoded = base64((script:gsub(".", function(c) return c .. "\0" end)))
    local pipe = io.popen("powershell.exe -NoLogo -NoProfile -NonInteractive -STA -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand " .. encoded, "r")
    if not pipe then return "ERROR: Could not start Windows PowerShell." end
    local result = pipe:read("*a") or ""
    pipe:close()
    return result
end

local function favorite_current()
    local item = vlc.input.item()
    if not item then return report("Open a video first, then try again.") end
    local uri, current = item:uri(), vlc.playlist.current()
    if not uri or not uri:match("^file:///[A-Za-z]:/") then
        return report("Open a file on a drive with a letter, such as C: or S:.")
    end
    local name = vlc.strings.decode_uri(uri:match("([^/]+)$") or "")
    if name:sub(1, 1) == "." then vlc.deactivate(); return end
    local list = entries()
    local found = false
    for _, entry in ipairs(list) do if entry.id == current then found = true end end
    if not found then return report("Couldn't find this video in the playlist. Open it from the playlist and try again.") end
    local helper = vlc.config.userdatadir() .. "/lua/extensions/vlc-deleter/Favorite-File.ps1"
    local file = vlc.io.open(helper, "rb")
    if not file then return report("Part of VLC Deleter is missing. Run Install.ps1 again, then restart VLC.") end
    file:close()
    local validation = run_helper(helper, uri, true)
    if validation:match("^ALREADY%s*$") then vlc.deactivate(); return end
    if not validation:match("^VALID%s*$") then
        return report("Couldn't favorite this video. Playback hasn't been interrupted. " .. validation:sub(1, 600))
    end
    local latest = vlc.input.item()
    if vlc.playlist.current() ~= current or not latest or latest:uri() ~= uri then
        return report("VLC has moved to another video. Nothing was renamed. Try again.")
    end
    vlc.playlist.stop()
    local result = run_helper(helper, uri, false)
    if not result:match("^FAVORITED%s*$") then
        return report("Couldn't rename this video. Its playlist entry was kept. " .. result:sub(1, 600))
    end

    local renamed_uri = uri:gsub("([^/]+)$", ".%1")
    local before, root_id = entries()
    local known = {}
    for _, entry in ipairs(before) do known[entry.id] = true end
    vlc.playlist.enqueue({{path = renamed_uri, name = "." .. name}})
    local after = entries()
    local new_id
    for _, entry in ipairs(after) do
        if not known[entry.id] and entry.path == renamed_uri then new_id = entry.id; break end
    end
    if not new_id then
        return report("The file was renamed, but VLC couldn't add it to the playlist. Open ." .. name .. " from its folder.")
    end
    -- Moving to the playlist root puts the favorite first without rebuilding
    -- unrelated entries or depending on their IDs matching their positions.
    if root_id then vlc.playlist.move(new_id, root_id) end
    for _, entry in ipairs(before) do
        if entry.path == uri then vlc.playlist.delete(entry.id) end
    end
    if vlc.playlist.status() == "stopped" then vlc.playlist.goto(new_id) end
    vlc.deactivate()
end

function activate()
    local ok, err = pcall(favorite_current)
    if not ok then report("Something went wrong while favoriting the video: " .. tostring(err)) end
end
function deactivate()
    if dialog then dialog:delete(); dialog = nil end
end
function close() vlc.deactivate() end
