-- SPDX-License-Identifier: GPL-3.0-or-later
-- Booster selection through the stock Hellpod item list (category 5) and the game's
-- own booster routine, in the order the stock list handler uses at 0x146E6DC:
-- equip (0x875800: squad check, host/client sync), peer notice (0xBDE430, event
-- 0x5D509124), panel widget (0x1893D40), then list close.
-- Facts come from this project's own disassembly of build 25480438; see
-- docs/UPDATE-0.1.7.md. Candidates are only rows the stock list
-- itself marks selectable, and the game's squad-duplicate check must also accept them.
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.create_boosters(P,S)
    local ffi=P.ffi
    local L=S.layout
    -- Exact code this module depends on. Any difference refuses the whole feature.
    local pins={
        {0x146E11A,'pin:52::510fcda3ec1aade3'},
        {0x146E6DC,'pin:164::9b49830f356f641d'},
        {0x146EB49,'pin:50::8439126763d62143'},
        {0x875110,'pin:347::2c4405f6609c3ac4'},
        {0x875800,'pin:193::60066b561e7e8152'},
        {0x1893D40,'pin:63::cd694e6abd907cf5'},
        {0xFD9A40,'pin:24::ac64670989b5ff73'},
        {0xBDE430,'pin:49::cbe03a86e730161a'},
    }
    for _,pin in ipairs(pins) do
        assert(P.match(pin[1],pin[2]),string.format('Unsupported booster code at 0x%X',pin[1]))
    end
    -- Values below are the operands of the pinned instructions above.
    local BOOSTER_CATEGORY,BOOSTER_FOCUS=5,4
    -- Booster table address, row count and row size come from the game's own code. The
    -- stock confirm (0x146E6DC), the squad check (0x875110) and the panel widget
    -- (0x1893D40) each carry them as operands; all three must agree. The count is the
    -- table's own size, never the number of rows the list shows (ownership, mission and
    -- squad state can hide rows).
    local function pinned(rva)
        for _,pin in ipairs(pins) do if pin[1]==rva then return pin[2] end end
        error(string.format('Booster pin 0x%X missing',rva))
    end
    local T=P.derive({
        {name='booster_confirm',rva=0x146E6DC,text=pinned(0x146E6DC),fields={
            confirm_count={'u32',{7}},confirm_bound={'u8',{26}},confirm_stride={'u8',{34}},
            confirm_table={'rip',{38},{42}}}},
        {name='booster_squad',rva=0x875110,text=pinned(0x875110),fields={squad_bound={'u8',{46}}}},
        {name='booster_widget',rva=0x1893D40,text=pinned(0x1893D40),fields={
            widget_table={'rip',{37},{41}},widget_stride={'u8',{57}},widget_bound={'u8',{60}}}},
    })
    local TABLE,TABLE_COUNT,TABLE_STRIDE=T.confirm_table,T.confirm_count,T.confirm_stride
    assert(T.widget_table==TABLE and T.widget_stride==TABLE_STRIDE and T.confirm_bound==TABLE_COUNT
        and T.squad_bound==TABLE_COUNT and T.widget_bound==TABLE_COUNT,'Booster table facts disagree')
    -- The bounds are signed 8-bit compare operands; a larger table needs different code.
    assert(TABLE_COUNT>0 and TABLE_COUNT<128 and TABLE_STRIDE>=4,'Invalid booster table shape')
    P.log(string.format('Booster table from code: rva=0x%X rows=%d stride=0x%X',TABLE,TABLE_COUNT,TABLE_STRIDE))
    local SESSION,SESSION_LOCAL=0x347CEF0,0xB398             -- 0x875813, 0x875824
    local PEERS,PEERS_COUNT,PEERS_LIST=0x3326468,0x88,0xE8    -- 0x146E11A..0x146E12A
    local PEER_DEFAULT,PEER_NONE_A,PEER_NONE_B=0x3483C34,0x3484888,0x3483C20
    local WIDGET,BOOSTER_IN_BLOCK=0x620E8,0x130               -- 0x146E76A; probe diff
    local NOTICE=0x5D509124
    assert(L.category==0x2818 and L.grid==0x595F0 and L.grid+L.grid_focus==0x66F5C,
        'Booster list layout differs from the pinned open routine')
    local C={
        open=P.bind('void (*)(uint64_t)',0x146E9D0),
        close=P.bind('void (*)(uint64_t)',L.close_list),
        focus=P.bind('void (*)(uint64_t,int)',0x1895770),
        allowed=P.bind('uint8_t (*)(uint64_t,uint64_t,uint32_t)',0x875110),
        equip=P.bind('void (*)(uint64_t,uint32_t,uint32_t)',0x875800),
        player=P.bind('uint64_t (*)(uint32_t)',0xFD9A40),
        send=P.bind('void (*)(uint32_t,int64_t,void *,uint32_t)',0xBDE430),
        widget=P.bind('void (*)(uint64_t,uint32_t)',0x1893D40),
    }
    pcall(ffi.cdef,'typedef struct { uint32_t kind; uint32_t size; const void *value; } rlm_notice_field;')
    local B={}
    local function booster_id(index)
        if index>=TABLE_COUNT then return 0 end
        return P.u32(P.base+TABLE+index*TABLE_STRIDE) or 0
    end
    local function block_booster(before)
        return P.u32(before.screen+L.block_base+before.index*L.block_stride+BOOSTER_IN_BLOCK)
    end
    local function local_peer()
        local peers=assert(P.pointer(P.base+PEERS),'Session peers unavailable')
        local id_address=P.base+PEER_DEFAULT
        if P.u32(peers+PEERS_COUNT)~=0 then id_address=assert(P.pointer(peers+PEERS_LIST),'Peer list unavailable')+8 end
        local id=assert(P.u32(id_address),'Local peer unreadable')
        assert(id~=P.u32(P.base+PEER_NONE_A) and id~=P.u32(P.base+PEER_NONE_B),'Local player is not in a session')
        return id
    end
    function B.current(before) return block_booster(before) end

    -- Opens the stock booster list, lets choose() pick among its selectable rows, equips
    -- the pick the way the list's own confirm does, and closes the list again.
    function B.select(before,choose)
        local screen=before.screen
        assert(S.same(before),'Loadout changed before booster selection')
        assert(P.byte(screen+L.list_open)==0,'Close the individual equipment selector first')
        local previous_focus=P.u32(screen+L.grid+L.grid_focus)
        -- Restored exactly afterwards, including no focus (-1) and mission-row slots.
        if previous_focus==4294967295 then previous_focus=-1 end
        assert(previous_focus and previous_focus<=11,'Focus a loadout slot, close its selector, then retry')
        local chosen
        local ok,err=pcall(function()
            C.focus(screen+L.grid,BOOSTER_FOCUS)
            C.open(screen)
            assert(S.same(before),'Loadout changed while opening booster list')
            assert(P.byte(screen+L.list_open)~=0 and P.u32(screen+L.category)==BOOSTER_CATEGORY,
                'Native booster list did not open')
            local list=screen+L.list
            local n=assert(P.u32(list+L.list_count),'Unreadable booster list count')
            assert(n>0 and n<=TABLE_COUNT and n<=L.list_capacity,'Invalid booster list count')
            local session=assert(P.pointer(P.base+SESSION),'Booster session unavailable')
            local me=P.pointer(session+SESSION_LOCAL) or 0
            local current=block_booster(before)
            local pool={}
            for i=0,n-1 do
                local index=P.u32(list+L.ids+i*4)
                local selectable=P.byte(list+L.selectable+i)
                local id=index and booster_id(index) or 0
                local squad_ok=index and index<TABLE_COUNT and C.allowed(0,me,index)==1
                if selectable==1 and squad_ok and id~=0 and id~=current then
                    pool[#pool+1]={index=index,id=id}
                end
            end
            P.log(string.format('Booster list: rows=%d candidates=%d current=%s',n,#pool,tostring(current)))
            chosen=choose(pool,current)
            local peer=local_peer()
            assert(S.same(before) and P.u32(screen+L.category)==BOOSTER_CATEGORY,'Booster list changed before applying')
            -- Same calls, arguments and order as the stock confirm (0x146E6EF..0x146E77B).
            C.equip(0,0,chosen.index)
            local player=C.player(peer)
            assert(player~=0,'Local player record unavailable')
            local value=ffi.new('uint32_t[1]',chosen.id)
            local fields=ffi.new('rlm_notice_field[2]')
            fields[0].kind,fields[0].size,fields[0].value=1,4,ffi.cast('const void *',player)
            fields[1].kind,fields[1].size,fields[1].value=6,4,value
            C.send(NOTICE,-2,fields,2)
            C.widget(screen+WIDGET,chosen.id)
        end)
        -- The stock confirm closes the list itself; never touch a stale screen.
        local cleaned,cleanup_error=pcall(function()
            if S.screen()==screen then
                if P.byte(screen+L.list_open)~=0 then C.close(screen) end
                C.focus(screen+L.grid,previous_focus)
            end
        end)
        assert(ok,err)
        assert(cleaned,cleanup_error)
        P.log(string.format('Booster requested: index=%d id=%u',chosen.index,chosen.id))
        return chosen
    end
    -- Index 0 is "no booster": the squad check 0x875110 always accepts it (several
    -- players may all have none). Randomize picks a real booster; Load may restore 0.
    function B.randomize(before,random)
        return B.select(before,function(pool)
            local real={}
            for _,item in ipairs(pool) do if item.index~=0 then real[#real+1]=item end end
            assert(#real>0,'No other selectable booster')
            return real[random(#real)]
        end)
    end
    -- Saved booster: nothing to do when it is already equipped; otherwise it must be a
    -- row the stock list offers right now (owned, not taken by a squad member).
    function B.load(before,id)
        if block_booster(before)==id then return nil end
        return B.select(before,function(pool)
            for _,item in ipairs(pool) do if item.id==id then return item end end
            error('Saved booster is not selectable now',0)
        end)
    end
    return B
end
