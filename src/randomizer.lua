-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure selection logic. It never accesses game memory or changes the game's PRNG.
local RLM=assert(rawget(_G,'RLMmods'))
function RLM.new_random(seed)
    local state=math.floor(tonumber(seed) or os.time())%2147483647
    if state<=0 then state=1 end
    return function(limit)
        assert(type(limit)=='number' and limit>=1 and limit%1==0 and limit<=2147483646,'Invalid random range')
        -- Rejection sampling avoids modulo bias. Park-Miller multiplication is exact in doubles here.
        local ceiling=2147483646-(2147483646%limit)
        local sample
        repeat state=(state*48271)%2147483647; sample=state-1 until sample<ceiling
        return (sample%limit)+1
    end
end
function RLM.shuffle(items,random)
    local out={}; for i,item in ipairs(items) do out[i]=item end
    for i=#out,2,-1 do local j=random(i); out[i],out[j]=out[j],out[i] end
    return out
end
function RLM.choose_stratagems(pool,random,count)
    count=count or 4
    local choices,seen={},{}
    for _,item in ipairs(pool) do
        if item.owned==true and item.selectable==true and item.id and not seen[item.id] then
            seen[item.id]=true; choices[#choices+1]=item
        end
    end
    choices=RLM.shuffle(choices,random)
    local selected,groups={},{}
    local function search(first)
        if #selected==count then return true end
        if #choices-first+1<count-#selected then return false end
        for i=first,#choices do
            local item=choices[i]
            local compatible=true
            for _,group in ipairs(item.exclusive_groups or {}) do if groups[group] then compatible=false end end
            if compatible then
                selected[#selected+1]=item
                for _,group in ipairs(item.exclusive_groups or {}) do groups[group]=true end
                if search(i+1) then return true end
                for _,group in ipairs(item.exclusive_groups or {}) do groups[group]=nil end
                selected[#selected]=nil
            end
        end
        return false
    end
    assert(search(1),string.format('Need %d compatible stratagems; %d eligible. See log.',count,#choices))
    return RLM.shuffle(selected,random)
end
