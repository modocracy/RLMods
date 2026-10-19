-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original platform layer. No executable memory writes, injection, hooks or unlock edits.
local RLM = assert(rawget(_G, 'RLMmods'))
function RLM.create_platform()
    local ffi = require('ffi')
    assert(ffi.abi('64bit') and ffi.os == 'Windows', 'Windows x64 LuaJIT required')
    for _, decl in ipairs({
        'void *GetCurrentProcess(void);', 'void *GetModuleHandleA(const char *);',
        'int ReadProcessMemory(void *,const void *,void *,size_t,size_t *);',
        'int CreateDirectoryA(const char *,void *);',
        'void *GetForegroundWindow(void);',
        'unsigned long GetCurrentProcessId(void);',
        'unsigned long GetWindowThreadProcessId(void *,unsigned long *);',
        'int GetCursorPos(void *);', 'int ScreenToClient(void *,void *);',
        'int GetClientRect(void *,void *);',
    }) do pcall(ffi.cdef, decl) end
    local kernel, user = ffi.load('kernel32'), ffi.load('user32')
    local process = kernel.GetCurrentProcess()
    local base_ptr = kernel.GetModuleHandleA('game.dll')
    assert(base_ptr ~= nil, 'game.dll unavailable')
    local P = {ffi=ffi, base=tonumber(ffi.cast('uintptr_t', base_ptr))}
    local buffer, received = ffi.new('uint8_t[4096]'), ffi.new('size_t[1]')
    local function address_ok(a) return type(a)=='number' and a>=65536 and a<140737488355328 and a%1==0 end
    function P.read(address, size)
        if not address_ok(address) or type(size)~='number' or size<1 or size>1048576 or size%1~=0 then return nil end
        local b = size<=4096 and buffer or ffi.new('uint8_t[?]',size)
        if kernel.ReadProcessMemory(process,ffi.cast('const void *',address),b,size,received)==0 or tonumber(received[0])~=size then return nil end
        return ffi.string(b,size)
    end
    function P.decode32(s,o)
        o=o or 0; if type(s)~='string' or #s<o+4 then return nil end
        local a,b,c,d=s:byte(o+1,o+4); return a+256*b+65536*c+16777216*d
    end
    -- Scalar reads go into reusable typed buffers: no string per read, which matters
    -- for the per-frame checks.
    local word,quad,octet=ffi.new('uint32_t[1]'),ffi.new('uint64_t[1]'),ffi.new('uint8_t[1]')
    local function read_into(address,target,size)
        return address_ok(address)
            and kernel.ReadProcessMemory(process,ffi.cast('const void *',address),target,size,received)~=0
            and tonumber(received[0])==size
    end
    function P.u32(a) if read_into(a,word,4) then return tonumber(word[0]) end return nil end
    function P.byte(a) if read_into(a,octet,1) then return octet[0] end return nil end
    function P.pointer(a)
        if not read_into(a,quad,8) then return nil end
        local v=tonumber(quad[0])
        return address_ok(v) and v or nil
    end
    local log
    local directory=(os.getenv('LOCALAPPDATA') or '')
    if directory~='' then
        directory=directory..'\\RLMmods'; pcall(kernel.CreateDirectoryA,directory,nil)
        -- Keep earlier sessions across restarts, but start a new file past 1 MiB; the
        -- previous one stays as RLMmods.old.log (replacing the older copy).
        local path,old=directory..'\\RLMmods.log',directory..'\\RLMmods.old.log'
        local existing=io.open(path,'rb')
        if existing then
            local size=existing:seek('end'); existing:close()
            if size and size>1048576 then os.remove(old); os.rename(path,old) end
        end
        log=io.open(path,'a')
    end
    function P.log(message)
        if log then pcall(function() log:write(tostring(message)..'\n'); log:flush() end) end
    end
    function P.close_log() if log then pcall(log.close,log); log=nil end end
    local pe=P.u32(P.base+60)
    assert(pe and pe<4096 and P.read(P.base+pe,4)=='PE\0\0','Invalid game.dll PE header')
    P.timestamp=P.u32(P.base+pe+8)
    -- Fixed-build check. On another build main.lua enables nothing native; it only
    -- saves a code copy (P.dump_code) so the next update can be analysed quickly.
    P.supported=P.timestamp==0x6AB3B43F
    local header=P.read(P.base+pe,24)
    local count=header:byte(7)+256*header:byte(8)
    local opt=header:byte(21)+256*header:byte(22)
    assert(count>0 and count<128,'Invalid PE section count')
    local section_data=assert(P.read(P.base+pe+24+opt,count*40),'Unreadable PE sections')
    local code_ranges={}
    for i=0,count-1 do
        local o=i*40
        local flags=P.decode32(section_data,o+36)
        if math.floor(flags/536870912)%2==1 then
            local start=P.decode32(section_data,o+12)
            code_ranges[#code_ranges+1]={start,start+P.decode32(section_data,o+8)}
        end
    end
    P.code_ranges=code_ranges
    -- One copy of the executable sections per game.dll build, kept on this machine
    -- for offline analysis after a game update. Never packaged or uploaded.
    function P.dump_code()
        assert(directory~='','LOCALAPPDATA unavailable')
        local index_path=string.format('%s\\code-%08X.txt',directory,P.timestamp)
        local existing=io.open(index_path,'r')
        if existing then existing:close(); return false end
        local lines={string.format('timestamp=0x%08X base=0x%X',P.timestamp,P.base)}
        local chunk=1048576
        for _,range in ipairs(code_ranges) do
            local name=string.format('%s\\code-%08X-%08X.bin',directory,P.timestamp,range[1])
            local file=assert(io.open(name,'wb'),'Cannot create code copy')
            local missing=0
            for rva=range[1],range[2]-1,chunk do
                local size=math.min(chunk,range[2]-rva)
                local data=P.read(P.base+rva,size)
                -- Keep offsets aligned; unreadable pages are reported, not guessed.
                if not data then data=string.rep('\0',size); missing=missing+1 end
                file:write(data)
            end
            file:close()
            lines[#lines+1]=string.format('rva=0x%X size=0x%X unreadable_chunks=%d file=%s',
                range[1],range[2]-range[1],missing,name:match('[^\\]+$'))
        end
        local index=assert(io.open(index_path,'w'))
        index:write(table.concat(lines,'\n'),'\n'); index:close()
        P.log('Saved game.dll code copy for build 0x'..string.format('%08X',P.timestamp))
        return true
    end
    function P.code_rva(rva)
        for _,range in ipairs(code_ranges) do if rva>=range[1] and rva<range[2] then return true end end
        return false
    end
    -- Code pins: 'pin:<length>:<wildcard offsets>:<FNV-1a 64>' (tools/hash_pins.py).
    -- The game's bytes are read and fingerprinted here; the source keeps no copy of them.
    local bit=require('bit')
    -- 64-bit FNV constants built at run time: 64-bit literals would mark the compiled
    -- chunk as FFI bytecode, which the packaging check (plain stripped format) refuses.
    local FNV_OFFSET=bit.bor(bit.lshift(ffi.cast('uint64_t',0xcbf29ce4),32),0x84222325)
    local FNV_PRIME=bit.bor(bit.lshift(ffi.cast('uint64_t',1),40),0x1b3)
    local function fingerprint(data,skip)
        local h=FNV_OFFSET
        for i=1,#data do
            if not skip[i-1] then h=bit.bxor(h,data:byte(i))*FNV_PRIME end
        end
        return bit.tohex(h,16)
    end
    local pins={}
    local function parse_pin(text)
        local cached=pins[text]
        if cached then return cached end
        local length,wildcards,hash=tostring(text):match('^pin:(%d+):([%d,%-]*):(%x+)$')
        length=tonumber(length)
        assert(length and length>0 and length<=4096 and hash and #hash==16,'Invalid code pin')
        local skip={}
        for first,last in wildcards:gmatch('(%d+)%-?(%d*)') do
            for k=tonumber(first),tonumber(last~='' and last or first) do skip[k]=true end
        end
        cached={length=length,skip=skip,hash=hash:lower()}
        pins[text]=cached
        return cached
    end
    -- True and the bytes read when the code at rva has the pinned fingerprint.
    function P.match(rva,text)
        local pin=parse_pin(text)
        if not P.code_rva(rva) or not P.code_rva(rva+pin.length-1) then return false end
        local s=P.read(P.base+rva,pin.length); if not s then return false end
        if fingerprint(s,pin.skip)~=pin.hash then return false end
        return true,s
    end
    function P.derive(specs)
        local fields={}
        for _,spec in ipairs(specs) do
            local matched,blob=P.match(spec.rva,spec.text)
            assert(matched,'Unsupported game code: '..spec.name)
            for name,recipe in pairs(spec.fields or {}) do
                local value
                for k,offset in ipairs(recipe[2]) do
                    local n=recipe[1]=='u8' and blob:byte(offset+1) or P.decode32(blob,offset)
                    assert(n~=nil,'Truncated signature field')
                    if recipe[1]=='rip' or recipe[1]=='call' then
                        if n>=2147483648 then n=n-4294967296 end
                        n=spec.rva+recipe[3][k]+n
                        if recipe[1]=='call' then assert(P.code_rva(n),'Native call outside executable section') end
                    end
                    assert(value==nil or value==n,'Signature field mismatch: '..name)
                    value=n
                end
                assert(fields[name]==nil or fields[name]==value,'Conflicting layout field: '..name)
                fields[name]=value
            end
        end
        return fields
    end
    function P.bind(proto,rva)
        assert(P.code_rva(rva),'Native address outside executable section')
        return ffi.cast(proto,P.base+rva)
    end
    local point,rect,pid=ffi.new('int32_t[2]'),ffi.new('int32_t[4]'),ffi.new('unsigned long[1]')
    local own_process=kernel.GetCurrentProcessId()
    -- The game window, its focus and client size change rarely: look them up every 30
    -- calls (about half a second); the cursor position itself is read every call.
    local window,window_w,window_h,window_calls=nil,0,0,0
    function P.cursor(width,height)
        window_calls=window_calls-1
        if window_calls<=0 then
            window_calls,window=30,nil
            local foreground=user.GetForegroundWindow()
            if foreground~=nil then
                user.GetWindowThreadProcessId(foreground,pid)
                if pid[0]==own_process and user.GetClientRect(foreground,rect)~=0 then
                    window,window_w,window_h=foreground,rect[2]-rect[0],rect[3]-rect[1]
                end
            end
        end
        if window==nil or window_w<=0 or window_h<=0 then return nil end
        if user.GetCursorPos(point)==0 or user.ScreenToClient(window,point)==0 then return nil end
        if point[0]<0 or point[1]<0 or point[0]>=window_w or point[1]>=window_h then return nil end
        return tonumber(point[0])*width/window_w,(window_h-tonumber(point[1]))*height/window_h
    end
    P.log('\nSession '..os.date('%Y-%m-%d %H:%M:%S')..' | RLMmods '..RLM.version)
    return P
end
