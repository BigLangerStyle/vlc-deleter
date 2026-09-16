local real_vlc, real_popen = vlc, io.popen
local count = 0
local function scenario(name, options)
    local calls, errors, helper_calls = {}, {}, 0
    local status = "playing"
    local uri = options.uri or "file:///C:/test/movie.mp4"
    local list = options.list or {{id=1,path=uri},{id=2,path="file:///C:/test/next.mp4"}}
    vlc = {
        input={item=function() if options.empty then return nil end; return {uri=function() return uri end} end},
        config={userdatadir=function() return options.actualHelper and test_data or "C:/test" end},
        io={open=function(path,mode)
            if options.missing then return nil end
            if options.actualHelper then return io.open(path,mode) end
            return {close=function() end}
        end},
        msg={err=function(message) errors[#errors+1]=message end},
        strings={convert_xml_special_chars=function(s) return s end,
            decode_uri=function(s) return (s:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end},
        dialog=function() return {add_label=function() end,add_button=function() end,delete=function() end} end,
        deactivate=function() calls[#calls+1]="deactivate" end,
        playlist={
            current=function() return options.changed and helper_calls > 0 and 2 or 1 end,
            get=function() return {id=0,children=list} end,
            stop=function() calls[#calls+1]="stop"; status="stopped" end,
            status=function() return status end,
            enqueue=function(items)
                calls[#calls+1]="enqueue"
                if not options.enqueueFailure then list[#list+1]={id=9,path=items[1].path} end
            end,
            move=function(id,parent)
                assert(id==9 and parent==0)
                calls[#calls+1]="move"
                for i,e in ipairs(list) do if e.id==id then table.remove(list,i); table.insert(list,1,e); break end end
                return 0
            end,
            delete=function(id)
                calls[#calls+1]="delete:"..id
                for i,e in ipairs(list) do if e.id==id then table.remove(list,i); break end end
            end,
            goto=function(id) calls[#calls+1]="goto:"..id end
        }
    }
    io.popen=function(command)
        helper_calls=helper_calls+1
        calls[#calls+1]="helper"
        assert(not command:find(uri,1,true))
        assert(command:match("%-EncodedCommand [A-Za-z0-9+/=]+$"))
        if options.actualHelper then return real_popen(command,"r") end
        local result
        if helper_calls==1 then
            assert(status=="playing")
            result=options.invalid and "ERROR: collision" or "VALID"
        else
            if options.manual then status="playing" end
            result=options.failure and "ERROR: locked" or "FAVORITED"
        end
        return {read=function() return result end,close=function() end}
    end
    dofile(test_source)
    activate()
    assert(table.concat(calls,",")==options.expected,name..": "..table.concat(calls,","))
    assert((#errors>0)==(options.error or false),name..": error reporting")
    if not options.error and helper_calls==2 then
        assert(list[1].id==9 and list[1].path==uri:gsub("([^/]+)$",".%1"),"Wrong favorite entry")
        for _,entry in ipairs(list) do assert(entry.path~=uri,"Stale playlist path") end
    end
    count=count+1
end
local success="helper,stop,helper,enqueue,move,delete:1,goto:9,deactivate"
scenario("playlist",{expected=success})
scenario("single",{list={{id=1,path="file:///C:/test/movie.mp4"}},expected=success})
scenario("duplicates",{list={{id=1,path="file:///C:/test/movie.mp4"},{id=3,path="file:///C:/test/movie.mp4"}},expected="helper,stop,helper,enqueue,move,delete:1,delete:3,goto:9,deactivate"})
scenario("already favorite",{uri="file:///C:/test/.movie.mp4",expected="deactivate"})
scenario("encoded period",{uri="file:///C:/test/%2Emovie.mp4",expected="deactivate"})
scenario("collision",{invalid=true,error=true,expected="helper"})
scenario("locked",{failure=true,error=true,expected="helper,stop,helper"})
scenario("changed",{changed=true,error=true,expected="helper"})
scenario("stream",{uri="https://example.com/video",error=true,expected=""})
scenario("empty",{empty=true,error=true,expected=""})
scenario("missing helper",{missing=true,error=true,expected=""})
scenario("enqueue failure",{enqueueFailure=true,error=true,expected="helper,stop,helper,enqueue"})
scenario("manual playback",{manual=true,expected="helper,stop,helper,enqueue,move,delete:1,deactivate"})
if test_file_uri then scenario("real helper",{uri=test_file_uri,actualHelper=true,expected=success}) end
vlc,io.popen=real_vlc,real_popen
return "PASS: "..count.." favorite scenarios"
