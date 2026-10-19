-- SPDX-License-Identifier: GPL-3.0-or-later
-- Game-engine GUI, not ImGui and not an injected stock menu widget.
-- Font/resource and GUI lifecycle research: SHODAN Stat Editor (GPL-3.0).
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.create_ui(P)
    local sr=assert(rawget(_G,'stingray'),'Stingray Lua API unavailable')
    assert(sr.Gui and sr.World and sr.Application and sr.Mouse,'Engine GUI/input unavailable')
    local U={gui=nil,world=nil,pressed=nil,was_down=nil,appear=nil}
    local function live_world(world)
        for _,w in ipairs(sr.Application.worlds() or {}) do if w==world then return true end end
        return false
    end
    -- Decoded once per image/state/size: runs of {x, length, row, palette index}.
    -- Shapes decoded once per image/size: runs of {x, length, row, class+1}. Colours
    -- per state come from the class: background, white-ink or yellow-ink level.
    local shapes,palettes={},{}
    local function palette(state)
        if palettes[state] then return palettes[state] end
        local images=assert(RLM.ui_images,'Button images missing')
        local levels,c=images.levels,assert(images.colors[state],'Button state missing: '..state)
        local out={}
        for class=0,2*levels do
            local ink,t=nil,0
            if class>0 and class<=levels then ink,t=c.white or c.ink,class/levels
            elseif class>levels then ink,t=c.yellow or c.ink,(class-levels)/levels end
            local colour={}
            for k=1,3 do colour[k]=math.floor(c.bg[k]+(ink and (ink[k]-c.bg[k])*t or 0)+0.5) end
            out[class+1]=colour
        end
        palettes[state]=out
        return out
    end
    local function decoded(name,state,size)
        local key=name..'/'..size
        local shape=shapes[key]
        if not shape then
            local source=assert(RLM.ui_images and RLM.ui_images[name] and RLM.ui_images[name][size],
                'Button image missing: '..key)
            local runs,x,row,data={},0,0,source.rows
            for i=1,#data,2 do
                local length=data:byte(i+1)-36
                runs[#runs+1]={x,length,row,data:byte(i)-48+1}
                x=x+length
                if x>=source.n then
                    assert(x==source.n,'Corrupt button image row: '..key)
                    x,row=0,row+1
                end
            end
            assert(row==source.n,'Corrupt button image: '..key)
            shape={n=source.n,runs=runs}
            shapes[key]=shape
        end
        return {n=shape.n,runs=shape.runs,palette=palette(state)}
    end
    function U.clear()
        if U.gui and U.world and live_world(U.world) then pcall(sr.World.destroy_gui,U.world,U.gui) end
        U.gui,U.world,U.pressed,U.was_down=nil,nil,nil,nil
        U.key,U.world_wait=nil,0
        U.appear=nil
    end
    local function resource(address)
        local b=P.read(address,8); if not b then return nil end
        local lo,hi=P.decode32(b,0),P.decode32(b,4)
        if lo==0 and hi==0 then return nil end
        return string.format('%08x%08x',hi,lo)
    end
    local function can_get(kind,name)
        local ok,value=pcall(sr.Application.can_get,kind,name)
        return ok and value==true
    end
    local function font_for(gui)
        local font,atlas=resource(P.base+0x3772268),resource(P.base+0x3772EE8)
        local owner=P.pointer(P.base+0x37C5478)
        local material=owner and resource(owner+24)
        if font and atlas and material and sr.IdString64 and sr.Material then
            font,atlas,material=sr.IdString64.from_hex(font),sr.IdString64.from_hex(atlas),sr.IdString64.from_hex(material)
            if can_get('font',font) and can_get('texture',atlas) and can_get('material',material) then
                local instance=sr.Gui.material(gui,material)
                if instance then
                    sr.Material.set_texture(instance,sr.IdString64.from_hex('88bac99b00000000'),atlas)
                    return font,material
                end
            end
        end
        local debug_font='core/performance_hud/debug'
        if can_get('font',debug_font) and can_get('material',debug_font) then return debug_font,debug_font end
        return nil,nil
    end
    -- actions = {save, load, random, has_saved=boolean, focus=index|nil, fire=index|nil}
    -- focus/fire come from keyboard or controller navigation (navigation.lua).
    function U.tick(status,enabled,actions)
        -- The overlay world is looked up again every 30 frames, not every frame.
        local world=U.world
        U.world_wait=(U.world_wait or 0)-1
        if not world or U.world_wait<=0 then
            U.world_wait=30
            local main=sr.Application.main_world()
            world=nil
            for _,w in ipairs(sr.Application.worlds() or {}) do if w~=main then world=w; break end end
            if not world then U.clear(); return end
            if world~=U.world then U.clear(); U.world=world end
        end
        local width,height=sr.Gui.resolution()
        if not width or not height or width<320 or height<200 then U.clear(); return end
        -- Screenshot reference: a 1920x1080 canvas, inside the first player card's
        -- right edge. Scale with the canvas and center it on wider/taller screens.
        -- This is still an engine overlay, not a discovered native widget anchor.
        local scale=math.min(width/1920,height/1080)
        local left,top=(width-1920*scale)/2,(height-1080*scale)/2
        local bw,bh,gap=68*scale,68*scale,12*scale
        local x=left+397*scale
        local first_y=height-top-405*scale-bh
        -- Entrance with the loadout card: slide up from below and fade in. No input until
        -- the buttons settle.
        U.appear=(U.appear or 0)+(actions.dt or 1/60)
        local progress=math.min(1,U.appear/0.35)
        local eased=1-(1-progress)^3
        local settled=progress>=1
        local offset=(1-eased)*180*scale
        local alpha=math.floor(255*eased+0.5)
        local buttons={
            {label='저장',enabled=enabled,image='save'},
            {label='불러오기',enabled=enabled and actions.has_saved,image='load'},
            {label='랜덤',enabled=enabled,image='random'},
        }
        local mx,my=P.cursor(width,height)
        local hover
        for i,button in ipairs(buttons) do
            button.y=first_y-(i-1)*(bh+gap)-offset
            if settled and mx and mx>=x and mx<=x+bw and my>=button.y and my<=button.y+bh then hover=i end
        end
        local value=sr.Mouse.button(sr.Mouse.button_id('left'))
        local down=value==true or type(value)=='number' and value>0
        if not mx or not settled then U.pressed=nil; U.was_down=nil
        else
            if U.was_down~=nil then
                if down and not U.was_down then U.pressed=hover and buttons[hover].enabled and hover or nil end
                if not down and U.was_down then
                    if U.pressed and U.pressed==hover and buttons[hover].enabled then
                        U.last_action=hover
                        actions[hover]()
                    end
                    U.pressed=nil
                end
            end
            U.was_down=down
        end
        -- Keyboard/controller Select on the focused button, with the same enabled check.
        if settled and actions.fire and buttons[actions.fire] and buttons[actions.fire].enabled then
            U.last_action=actions.fire
            actions[actions.fire]()
        end
        local focus=settled and actions.focus or nil
        local tooltip=hover or focus
        -- Rebuild only when something visible changed; compared field by field so that
        -- unchanged frames allocate nothing.
        local key=U.key
        local floor_offset=math.floor(offset)
        if key and key[1]==width and key[2]==height and key[3]==hover and key[4]==focus
            and key[5]==U.pressed and key[6]==enabled and key[7]==actions.has_saved
            and key[8]==alpha and key[9]==floor_offset then return end
        key=key or {}
        key[1],key[2],key[3],key[4],key[5],key[6],key[7],key[8],key[9]=
            width,height,hover,focus,U.pressed,enabled,actions.has_saved,alpha,floor_offset
        U.key=key
        if U.gui then pcall(sr.World.destroy_gui,world,U.gui); U.gui=nil end
        local gui=sr.World.create_screen_gui(world,'scale',1,1)
        if not gui then return end
        U.gui=gui
        local font,material=font_for(gui)
        if not font then
            U.clear()
            if not U.font_warned then P.log('UI hidden: no loaded game font'); U.font_warned=true end
            return
        end
        local Vector2,Vector3,Color=sr.Vector2 or _G.Vector2,sr.Vector3 or _G.Vector3,sr.Color or _G.Color
        assert(Vector2 and Vector3 and Color,'Engine vector/color constructors unavailable')
        local function rectangle(rx,ry,rw,rh,color)
            sr.Gui.rect(gui,Vector3(rx,ry,950),Vector2(rw,rh),color)
        end
        local function text(value,tx,ty,size,color)
            sr.Gui.text(gui,value,font,size*scale,material,Vector3(tx,ty,953),color)
        end
        local white=Color(255,240,240,225)
        local grey=Color(255,155,158,150)
        -- Finished button PNGs (docs/design), drawn from the run-length rows that
        -- tools/make_ui_images.py generates. They include background, frame and corner
        -- marks, so nothing else is drawn around them. The nearest stored size that is not
        -- smaller than the button keeps them sharp; square pixels keep the aspect ratio.
        local size=bw<=80 and 64 or 128
        for i,button in ipairs(buttons) do
            local state=not button.enabled and 'disabled' or (hover==i or focus==i or U.pressed==i) and 'hover' or 'default'
            local image=decoded(button.image,state,size)
            local px=bw/image.n
            local colors={}
            for k,c in ipairs(image.palette) do colors[k]=Color(alpha,c[1],c[2],c[3]) end
            for _,run in ipairs(image.runs) do
                rectangle(x+run[1]*px,button.y+bh-(run[3]+1)*px,run[2]*px,px,colors[run[4]])
            end
        end
        -- Short label just below the hovered or focused button, above the button art.
        -- Results and refusal reasons go to RLMmods.log only.
        if tooltip then
            local button=buttons[tooltip]
            local size,label=14,button.label
            local lh=20*scale
            local ly=button.y-4*scale-lh
            sr.Gui.rect(gui,Vector3(x,ly,955),Vector2(bw,lh),Color(235,20,23,21))
            -- Hangul glyphs are close to square; centre by character count.
            local glyphs=0
            for k=1,#label do
                local byte=label:byte(k)
                if byte<128 or byte>=192 then glyphs=glyphs+1 end
            end
            local width=glyphs*size*0.95*scale
            sr.Gui.text(gui,label,font,size*scale,material,Vector3(x+(bw-width)/2,ly+5*scale,956),
                button.enabled and white or grey)
        end
    end
    return U
end
