-- SPDX-License-Identifier: GPL-3.0-or-later
-- Helmet, armor, cape, primary, secondary and grenade selection through the stock
-- Hellpod equipment view (panel mode 1) and the game's own equip calls, in the order
-- the stock list confirm uses at 0x146E785 (armor family) and 0x146E7E7 (weapons).
-- Facts come from this project's own disassembly of build 25480438; see
-- docs/UPDATE-0.1.8.md. Candidates are only rows the stock list marks selectable.
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.create_equipment(P,S)
    local ffi=P.ffi
    local L=S.layout
    local pins={
        {0x146E11A,'pin:52::510fcda3ec1aade3'},
        {0x146E1B3,'pin:119::8fbe93a9b6bfb334'},
        {0x146E785,'pin:198::7b2848f7c202e6b5'},
        {0x146EA7B,'pin:201::b645f6c07ceca1e2'},
        {0x146F38C,'pin:24::bc8dd1db3cdc60f3'},
        {0x189A2B0,'pin:107::bc4f4132316931e5'},
        {0x1898910,'pin:32::4cdbdad40e5cea39'},
        {0x1365EF0,'pin:78::1400fd68f9f98f3d'},
        {0x8760B0,'pin:32::ddd064e7465bb923'},
        {0x875CD0,'pin:32::20b1b934339d29b3'},
        {0x875EC0,'pin:32::efa2ae66c38236b9'},
        -- Equipment view refresh: rebinds the grid to a block and updates the six slot
        -- widgets from it (0x18991A0), one widget at a time through 0x18975D0.
        {0x18991A0,'pin:215::dab64a5fcb1cd9ab'},
        {0x18975D0,'pin:54::6546395a7912df48'},
    }
    for _,pin in ipairs(pins) do
        assert(P.match(pin[1],pin[2]),string.format('Unsupported equipment code at 0x%X',pin[1]))
    end
    -- Operands of the pinned instructions above.
    local PANEL,MODE,EQUIP_GRID,EQUIP_FOCUS,SUBSLOT=0x593D0,0x6F290,0x66F70,0x6F284,0x281C
    local PROGRESSION,OFFER_COUNT,OFFER_ROWS,OFFER_STRIDE=0x347CEF8,0x1CE0,0xB9CE4,0x18
    local ARMOR_SESSION=0x33264F8
    local PEERS,PEERS_COUNT,PEERS_LIST=0x3326468,0x88,0xE8
    local PEER_DEFAULT,PEER_NONE_A,PEER_NONE_B=0x3483C34,0x3484888,0x3483C20
    assert(L.category==0x2818 and L.local_index==0x27D0 and L.block_base==0x10 and L.block_stride==0x9F0,
        'Equipment layout differs from the pinned confirm routine')
    -- Equipment-view focus -> list category and sub-slot (open routine 0x146EAD2 and its
    -- jump table 0x146F38C), then the confirm branch's write offset or weapon arguments.
    local SLOTS={
        -- widget: slot widget inside the equipment grid, as the pinned refresh 0x18991A0 uses.
        {name='helmet',focus=0,category=3,sub=1,offset=0x124,setter=0x875CD0,widget=0x110},
        {name='armor',focus=1,category=3,sub=0,offset=0x12C,setter=0x8760B0,widget=0x1668},
        {name='cape',focus=2,category=3,sub=2,offset=0x128,setter=0x875EC0,widget=0x2BC0},
        -- Weapon offsets: where the game's own refresh reads them (checked below).
        {name='primary',focus=3,category=1,sub=1,slot=1,kind=1,current_offset=0x0,widget=0x4118},
        {name='secondary',focus=4,category=1,sub=3,slot=3,kind=2,current_offset=0x60,widget=0x5670},
        {name='grenade',focus=5,category=1,sub=4,slot=4,kind=4,current_offset=0xC0,widget=0x6BC8},
    }
    -- Block offsets, widget offsets and list categories of the six slots, as the game's
    -- own equipment-view refresh (0x18991A0) passes them; they must match SLOTS. The
    -- primary weapon is read from the block start (its instruction has no displacement).
    local function pinned(rva)
        for _,pin in ipairs(pins) do if pin[1]==rva then return pin[2] end end
        error(string.format('Equipment pin 0x%X missing',rva))
    end
    local R=P.derive({{name='equipment_refresh',rva=0x18991A0,text=pinned(0x18991A0),fields={
        helmet_offset={'u32',{80}},helmet_widget={'u32',{87}},helmet_category={'u32',{93}},
        armor_offset={'u32',{104}},armor_widget={'u32',{111}},armor_category={'u32',{117}},
        cape_offset={'u32',{128}},cape_widget={'u32',{135}},cape_category={'u32',{141}},
        primary_widget={'u32',{155}},primary_category={'u32',{161}},
        secondary_offset={'u8',{172}},secondary_widget={'u32',{176}},secondary_category={'u32',{182}},
        grenade_offset={'u32',{193}},grenade_widget={'u32',{200}},grenade_category={'u32',{206}}}}})
    R.primary_offset=0
    for _,slot in ipairs(SLOTS) do
        local block_offset=slot.offset or slot.current_offset
        assert(R[slot.name..'_offset']==block_offset and R[slot.name..'_widget']==slot.widget
            and R[slot.name..'_category']==slot.category,'Equipment slot facts disagree: '..slot.name)
    end
    local C={
        open=P.bind('void (*)(uint64_t)',0x146E9D0),
        close=P.bind('void (*)(uint64_t)',L.close_list),
        mode=P.bind('void (*)(uint64_t,uint32_t)',0x189A2B0),
        focus=P.bind('void (*)(uint64_t,uint32_t)',0x1898910),
        weapon=P.bind('uint8_t (*)(uint64_t,uint64_t,uint32_t,uint32_t,uint32_t)',0x1365EF0),
        grid_focus=P.bind('void (*)(uint64_t,int)',0x1895770),
        widget_item=P.bind('void (*)(uint64_t,uint32_t,uint32_t)',0x18975D0),
    }
    for _,slot in ipairs(SLOTS) do
        if slot.setter then slot.call=P.bind('void (*)(uint64_t,uint32_t,uint32_t)',slot.setter) end
    end
    local E={slots=SLOTS}
    -- The open routine picks stratagem or equipment lists by this view mode.
    function E.mode(screen) return P.u32(screen+MODE) end
    function E.set_mode(screen,mode)
        assert(mode==0 or mode==1,'Invalid loadout view mode')
        C.mode(screen+PANEL,mode)
        assert(P.u32(screen+MODE)==mode,'Loadout view mode did not change')
    end
    local function local_peer()
        local peers=assert(P.pointer(P.base+PEERS),'Session peers unavailable')
        local id_address=P.base+PEER_DEFAULT
        if P.u32(peers+PEERS_COUNT)~=0 then id_address=assert(P.pointer(peers+PEERS_LIST),'Peer list unavailable')+8 end
        local id=assert(P.u32(id_address),'Local peer unreadable')
        assert(id~=P.u32(P.base+PEER_NONE_A) and id~=P.u32(P.base+PEER_NONE_B),'Local player is not in a session')
        return id
    end
    -- The confirm's offer -> item lookup: first progression row whose offer matches.
    local function offer_items()
        local root=assert(P.pointer(P.base+PROGRESSION),'Progression unavailable')
        local count=assert(P.u32(root+OFFER_COUNT),'Progression count unreadable')
        local capacity=assert(RLM.ownership and RLM.ownership.capacity,'Progression capacity unavailable')
        assert(count>0 and count<=capacity,'Invalid progression count')
        local rows=assert(P.read(root+OFFER_ROWS,count*OFFER_STRIDE),'Progression rows unreadable')
        local map={}
        for i=0,count-1 do
            local offer,item=P.decode32(rows,i*OFFER_STRIDE+4),P.decode32(rows,i*OFFER_STRIDE+8)
            if offer~=0 and map[offer]==nil then map[offer]=item end
        end
        return map
    end
    local function block_of(before) return before.screen+L.block_base+before.index*L.block_stride end

    local function current_of(before,slot)
        local offset=slot.offset or slot.current_offset
        return offset and P.u32(block_of(before)+offset)
    end
    function E.current(before)
        local out={}
        for _,slot in ipairs(SLOTS) do out[slot.name]=current_of(before,slot) end
        return out
    end
    local function pick_slot(before,slot,choose,items,peer)
        local screen=before.screen
        C.focus(screen+EQUIP_GRID,slot.focus)
        C.open(screen)
        local ok,result=pcall(function()
            assert(S.same(before),'Loadout changed while opening '..slot.name..' list')
            assert(P.byte(screen+L.list_open)~=0 and P.u32(screen+L.category)==slot.category
                and P.u32(screen+SUBSLOT)==slot.sub,'Native '..slot.name..' list did not open')
            local list=screen+L.list
            local n=assert(P.u32(list+L.list_count),'Unreadable '..slot.name..' list count')
            assert(n>0 and n<=L.list_capacity,'Invalid '..slot.name..' list count')
            local block=block_of(before)
            local current=current_of(before,slot)
            local selectable_rows=0
            local candidates={}
            for i=0,n-1 do
                local offer=P.u32(list+L.ids+i*4)
                local item=offer and items[offer]
                local selectable=P.byte(list+L.selectable+i)
                if selectable==1 then
                    selectable_rows=selectable_rows+1
                    if item and item~=0 and item~=current then candidates[#candidates+1]={offer=offer,item=item} end
                end
            end
            local pool=#candidates
            P.log(string.format('%s list: rows=%d selectable=%d candidates=%d current=%s',
                slot.name,n,selectable_rows,pool,tostring(current)))
            local chosen=choose(slot,candidates,current)
            assert(S.same(before) and P.u32(screen+SUBSLOT)==slot.sub,slot.name..' list changed before applying')
            -- Same writes, calls and arguments as the stock confirm branch.
            if slot.offset then
                ffi.cast('uint32_t *',block+slot.offset)[0]=chosen.item
                slot.call(assert(P.pointer(P.base+ARMOR_SESSION),'Armor session unavailable'),peer,chosen.item)
                assert(P.u32(block+slot.offset)==chosen.item,slot.name..' was not stored')
            else
                local stored=C.weapon(0,block,slot.slot,slot.kind,chosen.item)
                P.log(string.format('%s equip returned %s',slot.name,tostring(stored)))
            end
            P.log(string.format('%s requested: offer=%u item=%u',slot.name,chosen.offer,chosen.item))
            return chosen
        end)
        -- The stock confirm leaves closing to the list; close it the same way as elsewhere.
        if S.screen()==screen and P.byte(screen+L.list_open)~=0 then C.close(screen) end
        assert(ok,result)
        return result
    end

    -- Runs every equipment slot independently and returns {name=true|reason}.
    -- choose(slot,candidates,current) picks a candidate; skip(slot,current) leaves a slot as is.
    function E.run(before,choose,skip)
        local screen=before.screen
        assert(S.same(before),'Loadout changed before equipment selection')
        assert(P.byte(screen+L.list_open)==0,'Close the individual equipment selector first')
        local previous_mode=P.u32(screen+MODE)
        assert(previous_mode==0 or previous_mode==1,'Unknown loadout panel mode')
        local previous_equip=P.u32(screen+EQUIP_FOCUS)
        local previous_grid=P.u32(screen+L.grid+L.grid_focus)
        local items=offer_items()
        local peer=local_peer()
        local results={}
        local ok,err=pcall(function()
            if previous_mode~=1 then C.mode(screen+PANEL,1) end
            assert(P.u32(screen+MODE)==1,'Equipment view did not open')
            for _,slot in ipairs(SLOTS) do
                local done,why=true,nil
                if not (skip and skip(slot,current_of(before,slot))) then
                    done,why=pcall(pick_slot,before,slot,choose,items,peer)
                end
                results[slot.name]=done and true or tostring(why):gsub('^.-:%d+: ','')
                if not done then P.log(slot.name..' refused/error: '..results[slot.name]) end
                if S.screen()~=screen then break end
            end
            -- The grid refreshes its slot widgets from the block only when it is bound to
            -- another block, so a change made on this screen could show the old item (seen
            -- for the last slot, the grenade). Refresh each widget the way 0x18991A0 does;
            -- 0x18975D0 leaves a widget alone when it already shows that item.
            if S.screen()==screen then
                local block=block_of(before)
                for _,slot in ipairs(SLOTS) do
                    local item=current_of(before,slot)
                    if item then C.widget_item(screen+EQUIP_GRID+slot.widget,item,slot.category) end
                end
            end
        end)
        -- Put the view back the way the player left it.
        pcall(function()
            if S.screen()==screen then
                if P.byte(screen+L.list_open)~=0 then C.close(screen) end
                C.focus(screen+EQUIP_GRID,previous_equip or 4294967295)
                if previous_mode~=1 then C.mode(screen+PANEL,previous_mode) end
                if previous_grid and previous_grid~=4294967295 then
                    C.grid_focus(screen+L.grid,previous_grid)
                end
            end
        end)
        assert(ok,err)
        return results
    end
    function E.randomize(before,random)
        return E.run(before,function(slot,candidates)
            assert(#candidates>0,'No other selectable '..slot.name)
            return candidates[random(#candidates)]
        end)
    end
    -- Saved items: a slot already wearing its saved item is left alone; otherwise the
    -- item must be a row the stock list offers right now.
    function E.load(before,saved)
        return E.run(before,function(slot,candidates)
            for _,candidate in ipairs(candidates) do
                if candidate.item==saved[slot.name] then return candidate end
            end
            error('Saved '..slot.name..' is not selectable now',0)
        end,function(slot,current)
            return saved[slot.name]==nil or saved[slot.name]==current
        end)
    end
    return E
end
