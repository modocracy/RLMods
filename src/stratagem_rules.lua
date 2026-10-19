-- SPDX-License-Identifier: GPL-3.0-or-later
-- RLMmods' own loadout rules: at most one backpack-slot stratagem, one vehicle of any
-- kind and one support weapon among the four randomized stratagems. The game allows more.
-- Support weapons are recognised only by their native flag bit (stratagems.lua).
-- Stable stratagem IDs and their families are factual data from HD2Runtime by SkyeShade
-- (https://github.com/SkyeShade/HD2Runtime, revision 34fba0887b196130df4142933fbe1b6ff6be5020):
-- domains/stratagem_authoring.lua ("family") and domains/support_weapon_catalog.lua
-- ("backpackDependent"). These lists are a fallback: stratagems.lua decides by the
-- native kind bits first (vehicles 0x700000, backpack 0x8), which also cover later additions.
local RLM=assert(rawget(_G,'RLMmods'))
RLM.stratagem_groups={
    backpack={
        -- family "backpack"
        [485866824]='AX/AR-23 Guard Dog',
        [1692135420]='AX/ARC-3 K-9',
        [1125307795]='AX/FLAM-75 Hot Dog',
        [951988742]='AX/LAS-5 Rover',
        [5185868]='AX/TX-13 Dog Breath',
        [1907808218]='B-1 Supply Pack',
        [1053576110]='B-100 Portable Hellbomb',
        [2185045091]='LIFT-182 Warp Pack',
        [1753436707]='LIFT-850 Jump Pack',
        [73468749]='LIFT-860 Hover Pack',
        [3353508219]='SH-20 Ballistic Shield Backpack',
        [3843705076]='SH-32 Shield Generator Pack',
        [272480476]='SH-51 Directional Shield',
        -- support weapons delivered with a backpack ("backpackDependent")
        [875551083]='AC-8 Autocannon',
        [3748434442]='B/MD C4 Pack',
        [2271469939]='B/FLAM-80 Cremator',
        [3923676543]='FAF-14 Spear',
        [512147393]='GL-28 Belt-Fed Grenade Launcher',
        [1298599997]='GR-8 Recoilless Rifle',
        [3455841218]='M-1000 Maxigun',
        [2007887745]='RL-77 Airburst Rocket Launcher',
        [890972990]='StA-X3 W.A.S.P. Launcher',
        -- newer than the HD2Runtime catalogue; backpack icon in the user's 0.2.0 screenshot
        [45875024]='unnamed backpack stratagem (explosion icon)',
    },
    vehicle={
        -- family "vehicle": exosuits, FRVs and tanks share one group
        [295629711]='EXO-45 Patriot Exosuit',
        [1290499887]='EXO-49 Emancipator Exosuit',
        [3086305673]='EXO-51 Lumberer Exosuit',
        [563851843]='EXO-55 Breakthrough Exosuit',
        [3935317067]='M-102 Gunner FRV',
        [2636699686]='M-103 Supply FRV',
        [2846457047]='M-104 Incinerator FRV',
        [460870572]='TD-110 Maelstrom',
        [2002187052]='TD-220 Bastion MK XVI',
    },
}
