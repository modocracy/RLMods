-- SPDX-License-Identifier: GPL-3.0-or-later
-- Entry assembled after bootstrap, platform, signatures, randomizer, ownership, stratagems and UI.
local RLM=assert(rawget(_G,'RLMmods'))
local initialized,why=pcall(function()
    assert(type(rawget(_G,'update'))=='function','Stock update callback unavailable')
    RLM.platform=RLM.create_platform()
    if not RLM.platform.supported then
        -- Developer option: create %LOCALAPPDATA%\RLMmods\enable-code-copy.txt to save
        -- one game.dll code copy (about 48 MB) for update analysis. Off for players.
        local flag=io.open((os.getenv('LOCALAPPDATA') or '')..'\\RLMmods\\enable-code-copy.txt','r')
        if flag then
            flag:close()
            local saved,why=pcall(RLM.platform.dump_code)
            if not saved then RLM.platform.log('Code copy failed: '..tostring(why)) end
        end
        error(string.format('Unsupported game.dll build 0x%08X; RLMmods stays off until updated',RLM.platform.timestamp),0)
    end
    RLM.ownership=RLM.create_ownership(RLM.platform)
    RLM.platform.log('Ownership adapter: '..(RLM.ownership.available and 'signature matched'
        or 'unavailable: '..tostring(RLM.ownership.reason)))
    RLM.stratagems=RLM.create_stratagems(RLM.platform,RLM.ownership)
    RLM.ui=RLM.create_ui(RLM.platform)
    local navigation_ok,navigation=pcall(RLM.create_navigation,RLM.platform,RLM.stratagems)
    if navigation_ok then RLM.navigation=navigation; RLM.platform.log('Navigation adapter: code pins matched')
    else RLM.platform.log('Navigation adapter unavailable: '..tostring(navigation)) end
    -- A booster failure never disables stratagem randomization.
    local boosters_ok,boosters=pcall(RLM.create_boosters,RLM.platform,RLM.stratagems)
    if boosters_ok then RLM.boosters=boosters; RLM.platform.log('Booster adapter: code pins matched')
    else RLM.platform.log('Booster adapter unavailable: '..tostring(boosters)) end
    local equipment_ok,equipment=pcall(RLM.create_equipment,RLM.platform,RLM.stratagems)
    if equipment_ok then RLM.equipment=equipment; RLM.platform.log('Equipment adapter: code pins matched')
    else RLM.platform.log('Equipment adapter unavailable: '..tostring(equipment)) end
    -- Loadout tab: screen +0x8 is the Hellpod tab (0 briefing/drop site, 1 loadout),
    -- written by the tab switch 0x1470D90 and read by the screen update 0x146D55A;
    -- +0x2808 is set once the Hellpod launches (0x146D3A2). Without these pins the
    -- buttons fall back to showing on the whole Hellpod screen.
    local P0=RLM.platform
    RLM.loadout_tab_known=P0.match(0x146D55A,'pin:27::f940da095b2fd4c8')
        and P0.match(0x146D3A2,'pin:12::74b292da2ac4f661')
        and P0.match(0x1470DB3,'pin:16::ca6d2a768a73bc9b')
        and P0.match(0x1470DE0,'pin:3::6a0d2d1b01deb9c5') or false
    P0.log('Loadout tab detection: '..(RLM.loadout_tab_known and 'code pins matched' or 'unavailable'))
    RLM.random=RLM.new_random(os.time())
    RLM.state='ready'; RLM.status='Un-ready and close item selectors.'
end)
if not initialized then
    RLM.state='unavailable'; RLM.reason=tostring(why)
    if RLM.platform then RLM.platform.log(RLM.reason) end
    print('[RLMmods] Disabled: '..RLM.reason)
    return
end
local P,S,U=RLM.platform,RLM.stratagems,RLM.ui
local frames,failures=0,0
-- The loadout snapshot (about a dozen memory reads) only decides whether the buttons
-- are enabled; refresh it every 6 frames, and at once after any action.
local snapshot_ok,snapshot_reason,snapshot_wait=false,nil,0
local function clean(e) return (tostring(e):gsub('^.-:%d+: ','')) end
-- Stratagem and booster lists open only in the stratagem view; the equipment step
-- switches to the equipment view itself. Restore the player's view at the end.
local function run_action(name,steps)
    if RLM.busy then return end
    RLM.busy=true
    P.log(name..' requested')
    local view_screen,previous_view=S.screen(),nil
    if RLM.equipment and view_screen then
        previous_view=RLM.equipment.mode(view_screen)
        if previous_view==1 then
            local switched,why=pcall(RLM.equipment.set_mode,view_screen,0)
            if not switched then P.log('View switch failed: '..tostring(why)) end
        end
    end
    local notes={}
    -- Each category keeps its own outcome; one refusal never stops the others.
    for _,step in ipairs(steps) do
        local ok,note=pcall(step)
        if not ok then note=clean(note); P.log(name..' refused/error: '..note) end
        if note then notes[#notes+1]=note end
    end
    if previous_view==1 and S.screen()==view_screen then
        local restored,why=pcall(RLM.equipment.set_mode,view_screen,1)
        if not restored then P.log('View restore failed: '..tostring(why)) end
    end
    RLM.status=table.concat(notes,' ')
    P.log(name..' result: '..RLM.status)
    RLM.busy=false
    snapshot_wait=0
end
local function equipment_note(results)
    local done,failed=0,{}
    for _,slot in ipairs(RLM.equipment.slots) do
        if results[slot.name]==true then done=done+1 else failed[#failed+1]=slot.name end
    end
    local note=string.format('Equipment %d/%d.',done,#RLM.equipment.slots)
    if #failed>0 then note=note..' Skipped: '..table.concat(failed,', ')..'.' end
    return note
end
local function booster_step(apply)
    return function()
        if not RLM.boosters then return nil end
        local before=S.snapshot()
        local ok,chosen=pcall(apply,before)
        if not ok then error('Booster: '..clean(chosen),0) end
        if not chosen then return 'Booster unchanged.' end
        RLM.pending_booster={id=chosen.id,before=before,frames=0}
        return 'Booster selected.'
    end
end
local function equipment_step(apply)
    return function()
        if not RLM.equipment then return nil end
        local ok,results=pcall(apply,S.snapshot())
        if not ok then error('Equipment: '..clean(results),0) end
        return equipment_note(results)
    end
end

local function randomize()
    run_action('Randomize',{
        function()
            local before=S.snapshot()
            local pool=S.catalog(before)
            P.log('Plan input: '..#pool..' candidates')
            local plan=RLM.choose_stratagems(pool,RLM.random,4)
            local picked={}
            for _,item in ipairs(plan) do
                local g=table.concat(item.exclusive_groups,'+')
                picked[#picked+1]=tostring(item.id)..(g~='' and '('..g..')' or '')
            end
            P.log('Stratagem plan: '..table.concat(picked,' '))
            S.apply(before,plan)
            return 'Four stratagems selected.'
        end,
        booster_step(function(before) return RLM.boosters.randomize(before,RLM.random) end),
        equipment_step(function(before) return RLM.equipment.randomize(before,RLM.random) end),
    })
end

-- One saved loadout per user, beside the log. Plain "key=value" lines of item IDs.
local SAVE_PATH=(os.getenv('LOCALAPPDATA') or '')..'\\RLMmods\\loadout-1.txt'
local SAVED_KEYS={'booster','helmet','armor','cape','primary','secondary','grenade'}
local function read_saved()
    local file=io.open(SAVE_PATH,'r')
    if not file then return nil end
    local text=file:read('*a'); file:close()
    assert(text:match('^RLMmods loadout 1\n'),'Unsupported saved loadout file')
    local saved={}
    for key,value in text:gmatch('\n(%a+)=([%d,]+)') do saved[key]=value end
    local ids={}
    for id in (saved.stratagems or ''):gmatch('%d+') do ids[#ids+1]=tonumber(id) end
    local out={stratagems=#ids==4 and ids or nil}
    for _,key in ipairs(SAVED_KEYS) do
        local n=tonumber(saved[key] or '')
        if n and n>0 and n<4294967296 then out[key]=n end
    end
    return out
end
local function has_saved()
    local file=io.open(SAVE_PATH,'r')
    if file then file:close(); return true end
    return false
end
RLM.has_saved=has_saved()

local function save_loadout()
    if RLM.busy then return end
    RLM.busy=true
    P.log('Save requested')
    local ok,result=pcall(function()
        local before=S.snapshot()
        local lines={'RLMmods loadout 1'}
        -- Empty stratagem slots are saved as 0 and restored as empty.
        local ids=S.current_ids(before)
        lines[#lines+1]='stratagems='..table.concat(ids,',')
        local filled=0
        for i=1,4 do if ids[i]~=0 then filled=filled+1 end end
        local values={}
        if RLM.boosters then values.booster=RLM.boosters.current(before) end
        if RLM.equipment then
            for key,value in pairs(RLM.equipment.current(before)) do values[key]=value end
        end
        local count=filled
        for _,key in ipairs(SAVED_KEYS) do
            local value=values[key]
            if value and value~=0 then lines[#lines+1]=key..'='..tostring(value); count=count+1 end
        end
        local temporary=SAVE_PATH..'.tmp'
        local file=assert(io.open(temporary,'w'),'Cannot write the saved loadout file')
        file:write(table.concat(lines,'\n'),'\n'); file:close()
        os.remove(SAVE_PATH)
        assert(os.rename(temporary,SAVE_PATH),'Cannot replace the saved loadout file')
        P.log('Saved loadout: '..table.concat(lines,' ',2))
        return string.format('Loadout saved (%d items%s).',count,filled==4 and '' or ', '..(4-filled)..' empty stratagem slots')
    end)
    RLM.status=ok and result or 'Save failed: '..clean(result)
    if ok then RLM.has_saved=true else P.log(RLM.status) end
    RLM.busy=false
    snapshot_wait=0
end

local function load_saved()
    local ok,saved=pcall(read_saved)
    if not ok or not saved then
        RLM.status=ok and 'No saved loadout.' or 'Load failed: '..clean(saved)
        P.log(RLM.status)
        return
    end
    run_action('Load',{
        function()
            if not saved.stratagems then return 'No saved stratagems.' end
            return S.load(S.snapshot(),saved.stratagems) and 'Stratagems loaded.' or 'Stratagems unchanged.'
        end,
        booster_step(function(before)
            if not saved.booster then return nil end
            return RLM.boosters.load(before,saved.booster)
        end),
        equipment_step(function(before) return RLM.equipment.load(before,saved) end),
    })
end
RLM.randomize,RLM.save_loadout,RLM.load_saved=randomize,save_loadout,load_saved
-- The game may reflect the booster in the loadout block a few frames later.
local function confirm_booster()
    local pending=RLM.pending_booster
    if not pending then return end
    pending.frames=pending.frames+1
    local ok,current=pcall(RLM.boosters.current,pending.before)
    if ok and current==pending.id then
        P.log(string.format('Booster confirmed in loadout data after %d checks; gameplay not validated',pending.frames))
        RLM.pending_booster=nil
    elseif pending.frames>=120 then
        P.log('Booster not reflected in loadout data; last value='..tostring(current))
        RLM.pending_booster=nil
    end
end
-- One table reused every frame for the UI's callbacks and per-frame inputs.
local actions={save_loadout,load_saved,randomize}
local function tick()
    frames=frames+1
    if RLM.state~='ready' then return end
    local screen=S.screen()
    RLM.on_screen=screen~=nil
    if not screen then if U.gui then U.clear() end; return end
    if RLM.pending_booster then confirm_booster() end
    -- Only on the loadout tab before launch, not while the drop site is chosen.
    if RLM.loadout_tab_known and (P.u32(screen+8)~=1 or P.byte(screen+0x2808)~=0) then
        if U.gui then U.clear() end
        if RLM.navigation and RLM.navigation.active then RLM.navigation.exit(false) end
        return
    end
    snapshot_wait=snapshot_wait-1
    if snapshot_wait<=0 then
        snapshot_ok,snapshot_reason=pcall(S.snapshot)
        snapshot_wait=6
    end
    local N=RLM.navigation
    actions.has_saved=RLM.has_saved
    actions.focus=N and N.focus() or nil
    actions.fire=N and N.take_fire() or nil
    actions.dt=RLM.dt
    U.tick(snapshot_ok and RLM.status or snapshot_reason,snapshot_ok and not RLM.busy,actions)
end
local original_update=update
local function navigation_step()
    local screen=S.screen()
    if screen then RLM.navigation.pre(screen) elseif RLM.navigation.active then RLM.navigation.exit(false) end
end
-- Runs after the stock update and returns its results unchanged (including nil holes)
-- without packing them into a table.
local function after_update(...)
    if frames%10==0 or U.gui or RLM.on_screen then
        local ok,error_text=pcall(tick)
        if not ok then
            failures=failures+1; P.log('Frame error: '..tostring(error_text))
            pcall(U.clear)
            if failures>=3 then RLM.state='disabled'; P.log('Disabled after repeated errors') end
        end
    else frames=frames+1 end
    return ...
end
update=function(...)
    local dt=...
    RLM.dt=type(dt)=='number' and dt>0 and dt<1 and dt or 1/60
    -- Button focus reads (and while focused, clears) this frame's menu actions before
    -- the stock card handles them. Only while RLMmods' buttons are on screen.
    if RLM.navigation and U.gui and RLM.state=='ready' then
        local ok,error_text=pcall(navigation_step)
        if not ok then P.log('Navigation disabled: '..tostring(error_text)); RLM.navigation=nil end
    end
    -- Stock errors propagate.
    return after_update(original_update(...))
end
local original_shutdown=rawget(_G,'shutdown')
shutdown=function(...)
    pcall(U.clear); P.close_log()
    if type(original_shutdown)=='function' then return original_shutdown(...) end
end
P.log('Ready: stratagems'..(RLM.boosters and ', booster' or '')..(RLM.equipment and ', equipment' or ''))
