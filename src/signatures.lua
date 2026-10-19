-- SPDX-License-Identifier: GPL-3.0-or-later
-- Signature data adapted from Alomare/FlexibleLoadouts (Alomare, 2026).
-- Upstream revision: 39871d310d3942f718648280fe5c60cc4d2beaac.
-- Only code/structure identities are used. No game-rule bypass behavior is included.
local RLM = assert(rawget(_G, 'RLMmods'))
RLM.signatures = {
    {name = 'screen', rva = 0x1082ef0, text = 'pin:25:3-6,10-13,16-19:6dbd5c5a201930ae',
     fields = {stack = {'rip', {3}, {7}}, slot = {'u32', {10}}, local_index = {'u32', {16}}}},
    {name = 'category', rva = 0x146e0bc, text = 'pin:18:3-6,8-11,14-17:72e2c07e60e8cf65',
     fields = {category = {'u32', {14}}}},
    {name = 'refresh_a', rva = 0x18d194f, text = 'pin:118:4-7,9,25-28,34-37,39,43-46,49-52,56-59,63-66,92-95,99,104,117:ca2f48f5fb488baf',
     fields = {list_count = {'u32', {4, 34}}, selectable = {'u32', {25}}, block_count = {'u32', {43}}, strat_table = {'rip', {63}, {67}}, block_entries = {'u32', {92}}}},
    {name = 'refresh_b', rva = 0x18d19c5, text = 'pin:100:3-6,10-13,17-20,25,29-32,53-56,67,78,80,85,96-99:6c4d29b9fe123c17',
     fields = {offers = {'rip', {3}, {7}}, first = {'u32', {10}}, last = {'u32', {17}}, indices = {'u32', {29}}, entries = {'u32', {53}}, mark = {'call', {96}, {100}}}},
    {name = 'offers_count', rva = 0x146e1cf, text = 'pin:32:3-6,10,14-17,24,28-31:eede4b48119efc11',
     fields = {offers = {'rip', {3}, {7}}, offers_count = {'u32', {14}}, entries = {'u32', {28}}}},
    {name = 'marker', rva = 0x18d1440, text = 'pin:72:33-36,58,68-71:0f0602b2248a22cb',
     fields = {ids = {'u32', {68}}}},
    {name = 'kind_frv', rva = 0x146e2e0, text = 'pin:55:7,18-21,23,34,47-50:7aa15280d239e613',
     fields = {types = {'u32', {18}}, flags = {'u32', {47}}}},
    {name = 'ready_slots', rva = 0x189c3b8, optional = true, text = 'pin:223:3-6,22-25,40-43,58-61,66-69,75,78,81,91,185-188,191,200-203,209-212,219-222:517ea702c1d89793',
     fields = {slot_flags = {'u32', {3}}, flash = {'u8', {78, 191}}, slot_stride = {'u32', {200}}, ui_sound = {'call', {219}, {223}}}},
    {name = 'ready_toggle', rva = 0x189c4d0, optional = true, text = 'pin:298:3-6,9-12,16-19,24,28-31,35-38,46,51,64,72,87,92-95,99-102,107-110,114-117,119,121,125,129,152-155,159-162,165-172,175-178,181,185-188,194,197-200,208-211,238-241,251,268-271,274-281,285,287-290,292,294-297:8334987e51c265a1',
     fields = {player_count = {'u32', {16}}, panel_entity = {'u32', {9}}, panel_local = {'u32', {92}}, ready_timer = {'u32', {107, 165, 274}}, players = {'rip', {3, 159}, {7, 163}}, player_active = {'u32', {175}}, player_entries = {'u32', {35, 185}}, player_flags = {'u32', {28, 197}}, ui_sound = {'call', {208}, {212}}, timer_idle = {'u32', {169}}, ready_time = {'u32', {278}}, sound_ready_last = {'u32', {287}}, sound_ready = {'u32', {294}}}},
    {name = 'equip_tail', rva = 0x146e5f6, optional = true, text = 'pin:228:3-6,15-18,21-24,27,31-34,38-41,53,61-64,67-70,77-80,85,96,102-105,110,117-120,125-128,131-134,138-141,145-148,152,157-160,164-167,169-172,175-178,182-185,189,194-197,199-202,207,211-214,218-221,224-227:24f70efc1b83e970',
     fields = {panels = {'u32', {3}}, slots_changed = {'call', {15}, {19}}, refresh = {'call', {157}, {161}}, list_grid = {'u32', {164}}, grid_refresh = {'call', {169}, {173}}, block_stride = {'u32', {145, 182}}, block_base = {'u8', {152, 189}}, save = {'call', {194}, {198}}, grid_mode = {'u32', {21}}, slot_types = {'u32', {38}}, slot_stride = {'u32', {102}}, ui_sound = {'call', {117}, {121}}, close_list = {'call', {125}, {129}}, local_index = {'u32', {131, 175}}, list = {'u32', {138}}, grid = {'u32', {211}}, focus_call = {'call', {218}, {222}}, edit_slot = {'u32', {224}}, type_last = {'u32', {61}}}},
    {name = 'open_list', rva = 0x146e9d0, optional = true, text = 'pin:148:12-15,36-39,51,69-72,91-94,137-140:2c51d09f1f64a916',
     fields = {panels = {'u32', {91}}, list_open = {'u32', {137}}}},
    {name = 'set_slot', rva = 0x189d050, optional = true, text = 'pin:74:5-8,39-42,46-49,55-58,63-66:2813d2d3af09e308',
     fields = {slot_stride = {'u32', {46}}, widget_base = {'u32', {55}}, set_widget = {'call', {63}, {67}}}},
    {name = 'focus', rva = 0x1895770, optional = true, text = 'pin:23:12-15:eb7534b39b0b3452',
     fields = {grid_focus = {'u32', {12}}}},
}

