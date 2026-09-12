-- Runs inside the installed VLC Lua runtime, with playback and helper mocks.
local real_vlc, real_popen = vlc, io.popen
local source = test_source
local count = 0
local function scenario(name, options)
    local calls, errors = {}, {}
    local status = "playing"
    local uri = options.uri or "file:///C:/test/movie%20%26%20%F0%9F%8E%AC.avi"
    local entries = options.entries or {{id=1,path=uri},{id=2,path="file:///C:/test/next.avi"}}
    vlc = {
        input = {item=function() if options.empty then return nil end; return {uri=function() return uri end} end},
        config = {userdatadir=function() return options.actualHelper and test_data or "C:/test" end},
        io = {open=function(path, mode)
            if options.missing then return nil end
            if options.actualHelper then return io.open(path, mode) end
            return {close=function() end}
        end},
        msg = {err=function(message) errors[#errors+1]=message end},
        strings = {convert_xml_special_chars=function(s) return s end},
        dialog = function() return {add_label=function() end, add_button=function() end, delete=function() end} end,
        deactivate = function() calls[#calls+1]="deactivate" end,
        playlist = {
            current=function() return 1 end,
            get=function() return {children=entries} end,
            stop=function() calls[#calls+1]="stop"; status="stopped" end,
            status=function() return status end,
            delete=function(id) calls[#calls+1]="delete:"..id end,
            goto=function(id) calls[#calls+1]="goto:"..id end
        }
    }
    io.popen = function(command)
        calls[#calls+1]="helper"
        assert(not command:find(uri,1,true), "Raw filename in command")
        assert(command:match("%-EncodedCommand [A-Za-z0-9+/=]+$"), "Invalid encoding")
        if options.actualHelper then return real_popen(command, "r") end
        if options.manual then status="playing" end
        return {read=function() return options.failure and "ERROR: locked" or "RECYCLED\r\n" end, close=function() end}
    end
    dofile(source)
    activate()
    local actual = table.concat(calls,",")
    assert(actual == options.expected, name .. ": " .. actual)
    assert((#errors > 0) == (options.error or false), name .. ": error reporting")
    count = count + 1
end
local uri="file:///C:/test/movie%20%26%20%F0%9F%8E%AC.avi"
scenario("playlist", {expected="stop,helper,delete:1,goto:2,deactivate"})
scenario("single", {entries={{id=1,path=uri}}, expected="stop,helper,delete:1,deactivate"})
scenario("last", {entries={{id=2,path="file:///C:/prior.avi"},{id=1,path=uri}}, expected="stop,helper,delete:1,deactivate"})
scenario("duplicates", {entries={{id=1,path=uri},{id=3,path=uri},{id=2,path="file:///C:/next.avi"}}, expected="stop,helper,delete:1,delete:3,goto:2,deactivate"})
scenario("failure", {failure=true,error=true,expected="stop,helper"})
scenario("stream", {uri="https://example.com/movie",error=true,expected=""})
scenario("empty", {empty=true,error=true,expected=""})
scenario("missing helper", {missing=true,error=true,expected=""})
scenario("manual playback", {manual=true,expected="stop,helper,delete:1,deactivate"})
if test_file_uri then
    scenario("actual helper", {uri=test_file_uri,actualHelper=true,expected="stop,helper,delete:1,goto:2,deactivate"})
end
vlc, io.popen = real_vlc, real_popen
return "PASS: " .. count .. " extension scenarios"
