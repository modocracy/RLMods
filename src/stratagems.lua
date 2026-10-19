-- SPDX-License-Identifier: GPL-3.0-or-later
-- Native ABI/layout research: Alomare/FlexibleLoadouts, GPL-3.0-or-later.
-- Original bounded selection workflow. Does not modify availability, ownership or vehicle flags.
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.create_stratagems(P,ownership)
    assert(ownership and type(ownership.snapshot)=='function','Verified ownership adapter unavailable')
    local wanted={screen=true,category=true,refresh_a=true,refresh_b=true,offers_count=true,
        marker=true,kind_frv=true,ready_toggle=true,equip_tail=true,open_list=true,set_slot=true,focus=true,ready_slots=true}
    local specs={}; for _,s in ipairs(RLM.signatures) do if wanted[s.name] then specs[#specs+1]=s end end
    local L=P.derive(specs)
    assert(L.types>1 and L.types<4096 and L.slot_stride>=256 and L.slot_stride<=65536,'Invalid stratagem layout')
    assert(L.slot>=0 and L.slot<4096 and L.local_index<16777216,'Invalid screen layout')
    -- List buffer capacity, from the stock list's add-row routine (0x18D442D): it writes
    -- the row count, the id (4 bytes per row), the selectable flag (1 byte per row) and a
    -- second per-row byte array that starts right after the selectable flags.
    local A=P.derive({{name='list_add',rva=0x18D442D,text='pin:67::017f427e3e7edd8b',fields={
        count={'u32',{3,21,41,63}},selectable={'u32',{14}},after_selectable={'u32',{34}},ids={'u32',{49}}}}})
    assert(A.count==L.list_count and A.selectable==L.selectable and A.ids==L.ids,'List layout facts disagree')
    L.list_capacity=A.after_selectable-A.selectable
    assert(L.list_capacity>0 and L.list_capacity<=4096 and A.ids+L.list_capacity*4<=A.selectable,
        'Invalid list capacity')
    P.log('List capacity from code: '..L.list_capacity..' rows')
    local widget0=L.grid+L.widget_base
    local widget_type=L.slot_types-widget0
    assert(widget_type>=4 and widget_type<L.slot_stride,'Invalid slot widget')
    local C={
        widget=P.bind('void (*)(uint64_t,uint32_t)',L.set_widget),
        changed=P.bind('void (*)(uint64_t,int64_t)',L.slots_changed),
        save=P.bind('void (*)(uint64_t)',L.save),
        close=P.bind('void (*)(uint64_t)',L.close_list),
        open=P.bind('void (*)(uint64_t)',0x146e9d0),
        focus=P.bind('void (*)(uint64_t,int)',0x1895770),
    }
    local S={layout=L}
    local function global(rva) return P.pointer(P.base+rva) end
    function S.screen()
        local stack=global(L.stack)
        if not stack or P.u32(stack)~=11 then return nil end
        return P.pointer(stack+L.slot)
    end
    function S.snapshot()
        local screen=assert(S.screen(),'Open the Hellpod loadout screen')
        local index=P.u32(screen+L.local_index)
        assert(index and index<=3,'Local player is not ready')
        assert(P.u32(screen+L.panels+L.ready_timer)==L.timer_idle,'Un-ready before randomizing')
        local slots={}
        for i=0,3 do
            local flag=P.byte(screen+L.panels+L.slot_flags+i*L.slot_stride)
            assert(flag and math.floor(flag/4)%2==0,'A stratagem slot is disabled by the mission')
            slots[i+1]=assert(P.u32(screen+L.slot_types+i*L.slot_stride),'Unreadable stratagem slot')
        end
        return {screen=screen,index=index,slots=slots,token=tostring(screen)..':'..index}
    end
    function S.same(before)
        local ok,now=pcall(S.snapshot)
        if not ok or now.token~=before.token then return false end
        for i=1,4 do if now.slots[i]~=before.slots[i] then return false end end
        return true
    end
    local function item_info(enum)
        if enum<1 or enum>=L.types then return nil end
        local ptr=global(L.strat_table+enum*8)
        if not ptr or P.u32(ptr)~=enum then return nil end
        local id,flags=P.u32(ptr+4),P.u32(ptr+L.flags)
        if not id or id==0 or not flags then return nil end
        -- HD2Runtime's native availability research for this same image:
        -- StratagemInfo +0xC0 bit 0 = enabled, +0x80 bit 1 = selectable.
        local enabled,selectable=P.byte(ptr+0xC0),P.byte(ptr+0x80)
        if not enabled or enabled%2~=1 or not selectable or math.floor(selectable/2)%2~=1 then return nil end
        -- RLMmods rules: one vehicle of any kind, one backpack-slot stratagem and one
        -- support weapon among the four. Native kind bits decide (mech 0x100000, FRV 0x200000, tank 0x400000, and
        -- backpack 0x8: set on exactly the 22 known backpack stratagems of 91 in the user's
        -- 0.2.1 trace); the listed IDs are a fallback.
        local groups={}
        local rules=RLM.stratagem_groups or {}
        local vehicle=(rules.vehicle or {})[id]~=nil
        -- The game's own rule (one of each kind) applies to loads of a saved loadout.
        local native_groups={}
        for _,kind in ipairs({{1048576,'mech'},{2097152,'frv'},{4194304,'tank'}}) do
            if math.floor(flags/kind[1])%2==1 then vehicle=true; native_groups[#native_groups+1]=kind[2] end
        end
        if vehicle then groups[#groups+1]='vehicle' end
        if math.floor(flags/8)%2==1 or (rules.backpack or {})[id] then groups[#groups+1]='backpack' end
        -- Support weapon: flag bit 0x1, set on exactly the 33 "support" family stratagems
        -- of 91 in the user's 0.2.1 trace. Backpack-fed weapons are in both groups.
        if flags%2==1 then groups[#groups+1]='support' end
        return {id=id,enum=enum,exclusive_groups=groups,native_groups=native_groups}
    end
    local function offers()
        local root=assert(global(L.offers),'Offer catalog unavailable')
        local first,last,count=P.u32(root+L.first),P.u32(root+L.last),P.u32(root+L.offers_count)
        -- Offer rows, and so their index range, cannot exceed the progression table's
        -- capacity (derived in ownership.lua from the game's code).
        local capacity=assert(ownership.capacity,'Progression capacity unavailable')
        assert(first and last and count and first<=last and last<=capacity and count<=capacity,'Invalid offer catalog')
        local by_item={}
        for k=first,last-1 do
            local index=assert(P.u32(root+L.indices+k*4),'Unreadable offer index')
            assert(index<count,'Offer index out of bounds')
            local entry=root+L.entries+index*24
            local offer_id,item_id=P.u32(entry+4),P.u32(entry+8)
            if offer_id and item_id then
                by_item[item_id]=by_item[item_id] or {}
                by_item[item_id][#by_item[item_id]+1]=offer_id
            end
        end
        return by_item
    end
    function S.catalog(before)
        assert(S.same(before),'Loadout changed before catalog read')
        local screen=before.screen
        assert(P.byte(screen+L.list_open)==0,'Close the individual equipment selector first')
        -- Use the stock picker to expose only real selectable offers. This opens and closes
        -- the game's own list; it does not change a loadout item or an ownership bit.
        local previous_focus=P.u32(screen+L.grid+L.grid_focus)
        -- Restored exactly afterwards: a slot (0..4), a mission-row slot (5..11) or no
        -- focus (-1, e.g. while the Equipment prompt or RLMmods' buttons hold focus).
        if previous_focus==4294967295 then previous_focus=-1 end
        if not previous_focus or previous_focus>11 then
            P.log('Catalog blocked: grid_focus='..tostring(previous_focus))
            error('Focus a stratagem slot, close its selector, then retry',0)
        end
        local ok,pool=pcall(function()
            C.focus(screen+L.grid,0)
            C.open(screen)
            assert(S.same(before),'Loadout changed while opening picker')
            assert(P.byte(screen+L.list_open)~=0 and P.u32(screen+L.category)==10,'Native stratagem picker did not open')
            local list=screen+L.list
            local n=assert(P.u32(list+L.list_count),'Unreadable picker count')
            assert(n>0 and n<=L.list_capacity,'Invalid native picker count')
            local listed,selectable_count={},0
            for i=0,n-1 do
                local id=P.u32(list+L.ids+i*4)
                local selectable=P.byte(list+L.selectable+i)
                if id and selectable==1 then listed[id]=true; selectable_count=selectable_count+1 end
            end
            P.log(string.format('Picker: rows=%d selectable=%d focus=%d',n,selectable_count,previous_focus))
            local catalog=offers()
            local owned=ownership.snapshot('stratagem')
            -- A failed observer is not an empty inventory. Keep its actual error.
            if not owned.available then
                P.log('Ownership snapshot unavailable: '..tostring(owned.reason))
                error('Ownership unavailable; see RLMmods.log',0)
            end
            local out={}
            local counts={items=0,mapped=0,listed=0}
            local refused={}
            for enum=1,L.types-1 do
                local item=item_info(enum)
                if item then
                    counts.items=counts.items+1
                    if catalog[item.id] then counts.mapped=counts.mapped+1 end
                    -- Worn/equipped state cannot override the current mission picker.
                    -- Multiple offers can refer to one item; retain a selectable, owned one.
                    for _,offer in ipairs(catalog[item.id] or {}) do
                        if listed[offer] then
                            counts.listed=counts.listed+1
                            local eligible,proof,reason=owned.owns(item.id,offer)
                            if eligible then
                                item.owned=true; item.selectable=true; item.offer=offer
                                item.ownership_proof=proof
                                out[#out+1]=item
                                break
                            else
                                reason=tostring(reason or 'Unknown ownership refusal')
                                refused[reason]=(refused[reason] or 0)+1
                            end
                        end
                    end
                end
            end
            local grouped={vehicle=0,backpack=0,support=0}
            for _,item in ipairs(out) do
                for _,g in ipairs(item.exclusive_groups) do grouped[g]=(grouped[g] or 0)+1 end
            end
            P.log(string.format('Catalog: items=%d mapped_items=%d selectable_offer_matches=%d owned_candidates=%d vehicle=%d backpack=%d support=%d',
                counts.items,counts.mapped,counts.listed,#out,grouped.vehicle,grouped.backpack,grouped.support))
            local reasons={}; for reason in pairs(refused) do reasons[#reasons+1]=reason end
            table.sort(reasons)
            for _,reason in ipairs(reasons) do P.log('Ownership refusal x'..refused[reason]..': '..reason) end
            return out
        end)
        -- Never touch a stale controller during cleanup.
        local cleaned,cleanup_error=pcall(function()
            if S.screen()==screen then
                if P.byte(screen+L.list_open)~=0 then C.close(screen) end
                C.focus(screen+L.grid,previous_focus)
            end
        end)
        assert(ok,pool)
        assert(cleaned,cleanup_error)
        assert(S.same(before),'Loadout changed during catalog read')
        return pool
    end
    -- Items already in the loadout's slots: the stock picker does not list them, but
    -- keeping or reordering them is what the player's own loadout already holds.
    local function current_items(before)
        local out={}
        for i=1,4 do
            local info=before.slots[i]~=0 and item_info(before.slots[i]) or nil
            if info then info.current=true; out[#out+1]=info end
        end
        return out
    end
    function S.current_ids(before)
        local ids={}
        for i=1,4 do
            local info=before.slots[i]~=0 and item_info(before.slots[i]) or nil
            ids[i]=info and info.id or 0
        end
        return ids
    end
    -- opts.keep_current also accepts the slots' current items; opts.native_groups checks
    -- the game's one-per-kind vehicle rule instead of RLMmods' random-only rules.
    function S.apply(before,chosen,opts)
        opts=opts or {}
        assert(#chosen==4 and S.same(before),'Loadout changed before applying')
        local allowed={}; for _,item in ipairs(S.catalog(before)) do allowed[item.enum]=item end
        if opts.keep_current then
            for _,item in ipairs(current_items(before)) do allowed[item.enum]=allowed[item.enum] or item end
        end
        local seen,groups={},{}
        for _,item in ipairs(chosen) do
            -- An empty slot (enum 0) is only accepted from a saved loadout.
            if not (item.empty and opts.keep_current) then
                local live=allowed[item.enum]
                assert(live and live.id==item.id and not seen[item.enum],'A stratagem is no longer available')
                seen[item.enum]=true
                for _,g in ipairs(opts.native_groups and live.native_groups or live.exclusive_groups) do
                    assert(not groups[g],'One-'..g..' rule would be exceeded'); groups[g]=true
                end
            end
        end
        assert(S.same(before),'Loadout changed during preflight')
        for _,item in ipairs(chosen) do
            if not item.empty then
                local live=allowed[item.enum]
                local info=item_info(item.enum)
                assert(info and info.id==live.id,'Stratagem definition became unavailable')
                if not live.current then
                    assert(ownership.recheck(live.ownership_proof,live.id,live.offer),'Ownership changed before applying')
                end
            end
        end
        local screen=before.screen
        for i,item in ipairs(chosen) do C.widget(screen+widget0+(i-1)*L.slot_stride,item.enum) end
        C.changed(screen+L.panels,-1)
        C.save(screen+L.block_base+before.index*L.block_stride)
        local after=S.snapshot()
        assert(after.token==before.token,'Screen changed during native apply')
        for i,item in ipairs(chosen) do assert(after.slots[i]==item.enum,'Native selection was not confirmed') end
        P.log('Stratagem selection confirmed in native slot data; gameplay not validated')
        return true
    end
    -- Saved stratagems, in their saved slot order. Each must be selectable now or already
    -- in the loadout; otherwise nothing changes.
    function S.load(before,ids)
        local now=S.current_ids(before)
        if now[1]==ids[1] and now[2]==ids[2] and now[3]==ids[3] and now[4]==ids[4] then return false end
        local by_id={}
        for _,item in ipairs(current_items(before)) do by_id[item.id]=item end
        for _,item in ipairs(S.catalog(before)) do by_id[item.id]=by_id[item.id] or item end
        local chosen={}
        for i=1,4 do
            if ids[i]==0 then chosen[i]={id=0,enum=0,empty=true}
            else chosen[i]=by_id[ids[i]] or error('Saved stratagem '..tostring(ids[i])..' is not selectable now',0) end
        end
        S.apply(before,chosen,{keep_current=true,native_groups=true})
        return true
    end
    return S
end
