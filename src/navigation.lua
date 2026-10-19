-- SPDX-License-Identifier: GPL-3.0-or-later
-- Keyboard and controller focus for the RLMmods buttons, joined to the stock focus
-- order of the Hellpod player card: ... mission row -> "R Equipment" prompt -> buttons.
-- Up on the focused prompt (where the stock panel input does nothing, 0x189BEE6) moves
-- focus to the Randomize button; Up/Down move between the buttons, Select runs one,
-- and Down from the bottom button, Left, Right or Back return focus to the prompt.
-- While a button has focus, the menu actions of that frame are cleared before the game
-- reads them, so the stock card does not react to the same key. Other bindings (the
-- prompt's own R key, Ready, chat) are untouched. Facts: this project's disassembly
-- of build 25480438 (docs/UPDATE-0.5.0.md); input layout as in HD2Runtime's
-- domains/stratagem_selector.lua (SkyeShade, revision 34fba0887b19).
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.create_navigation(P,S)
    local ffi=P.ffi
    local L=S.layout
    local pins={
        -- Direction codes: actions 4/8 left, 3/7 right, 1/5 up, 2/6 down (+0x328, stride 32).
        {0x178E020,'pin:211::cf71d338c173391b'},
        -- Prompt -> grid (panel +0x1B820 prompt, +0x1B81E grid-active flag).
        {0x189BE27,'pin:99::2413c4cf5096cc53'},
        -- Grid -> prompt: highlight the prompt (0x1892200, dl=1), clear the grid flag.
        {0x189BF51,'pin:47::2ee3d934d8b67825'},
        {0x1892200,'pin:53::8e6ef9aa4bd42cdd'},
        -- The card's select check reads the same input object (global 0x347CF18).
        {0x189532C,'pin:25::011b0c2c675a841a'},
        -- Card update: viewed panel index (screen +0x2739C8), panels 0x1EE18 apart.
        {0x146D9C3,'pin:56::d016e4c7581b405a'},
    }
    for _,pin in ipairs(pins) do
        assert(P.match(pin[1],pin[2]),string.format('Unsupported navigation code at 0x%X',pin[1]))
    end
    local INPUT,STATES,STRIDE,CLEAR=0x347CF18,0x328,32,12
    local PANEL0,VIEWED,GRID_ACTIVE,PROMPT=0x53A78,0x2739C8,0x1B81E,0x1B820
    local UP,DOWN,RIGHT,LEFT,BACK,SELECT=1,2,3,4,9,10
    local highlight=P.bind('void (*)(uint64_t,uint8_t)',0x1892200)
    local N={active=false,index=3,fire=nil,screen=nil}

    local function pressed(owner,action) return P.byte(owner+STATES+action*STRIDE)~=0 end
    -- Clears the triggered flag and the held/repeat values of the menu actions 1..10.
    local function consume(owner)
        for action=1,SELECT do ffi.fill(ffi.cast('uint8_t *',owner+STATES+action*STRIDE),CLEAR,0) end
    end
    local function prompt_focused(screen)
        return P.u32(screen+VIEWED)==0 and P.byte(screen+PANEL0+GRID_ACTIVE)==0
    end
    function N.exit(restore)
        local screen=N.screen
        N.active,N.fire,N.screen=false,nil,nil
        P.log('Navigation: focus returned'..(restore and ' to the prompt' or ''))
        -- Give the highlight back to the prompt that still holds the stock focus.
        if restore and screen and S.screen()==screen and prompt_focused(screen) then
            pcall(highlight,screen+PANEL0+PROMPT,1)
        end
    end
    -- Before the game's update: read this frame's menu actions and, while a button has
    -- focus, handle and clear them.
    function N.pre(screen)
        local owner=P.pointer(P.base+INPUT)
        if not owner then return end
        if not N.active then
            -- Idle frames read only the Up flag; the rest only after Up was pressed.
            if not pressed(owner,UP) then return end
            if P.byte(screen+L.list_open)==0 and not RLM.busy and prompt_focused(screen) then
                N.active,N.index,N.screen=true,3,screen
                consume(owner)
                pcall(highlight,screen+PANEL0+PROMPT,0)
                P.log('Navigation: focus on buttons')
            end
            return
        end
        if screen~=N.screen or P.byte(screen+L.list_open)~=0 or P.u32(screen+VIEWED)~=0 then N.exit(false); return end
        if pressed(owner,UP) then N.index=math.max(1,N.index-1)
        elseif pressed(owner,DOWN) then
            if N.index>=3 then N.exit(true) else N.index=N.index+1 end
        elseif pressed(owner,LEFT) or pressed(owner,RIGHT) or pressed(owner,BACK) then
            P.log('Navigation: leave by '..(pressed(owner,LEFT) and 'left' or pressed(owner,RIGHT) and 'right' or 'back'))
            N.exit(true)
        elseif pressed(owner,SELECT) then N.fire=N.index; P.log('Navigation: select button '..N.index) end
        -- Also on the exit frame, so the key that leaves does not move the stock focus too.
        consume(owner)
        -- An action can open and close stock lists, which re-highlight the prompt; keep
        -- the highlight on the buttons while they hold focus (0x1892200 ignores no-ops).
        if N.active then pcall(highlight,screen+PANEL0+PROMPT,0) end
    end
    function N.focus() return N.active and N.index or nil end
    function N.take_fire() local fire=N.fire; N.fire=nil; return fire end
    return N
end
