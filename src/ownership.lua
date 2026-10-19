-- SPDX-License-Identifier: GPL-3.0-or-later
-- Original read-only progression ownership observer. No native calls or writes.
-- Factual instruction/layout evidence, not copied implementation:
-- https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/catalog_compat.lua
-- https://github.com/tyrypyrking/HD2-Transmog/blob/f469851dcb5bf241a08be5329728ca649710896c/src/catalog_probe.lua
-- Global-slot corroboration:
-- https://github.com/CowboyBingus/VanillaPlusMegapack/blob/da110a81bf6ac60ba74f04a3c71a2ab5e8cfccfd/components/ArmoryPreviewCache/src/native.lua
-- These repositories are research references, not dependencies. See research/
-- equipment-selection-evidence.md for source reuse limits and unverified scope.
-- Stratagem parent ownership facts: HD2Runtime by SkyeShade, revision
-- 34fba0887b196130df4142933fbe1b6ff6be5020, domains/stratagem_slots.lua and
-- scripts/generate_stratagem_slots.py. Original observer; no runtime dependency.
local RLM = assert(rawget(_G, 'RLMmods'))

function RLM.create_ownership(P)
    -- The 150-byte progression reader, pinned by fingerprint at its location on the
    -- supported build. Offsets 99..102 (its RIP displacement, as catalog_compat.lua
    -- masks it) are excluded; their live target is cross-checked against the
    -- independently matched stratagem offer reader below.
    local signature_rva, signature_bytes
    local signature = 'pin:150:99-102:9dc113c98accd240'
    local maximum_address = 140737488355328
    -- maximum_offers is the progression table's capacity, derived below from the code.
    local maximum_offers, batch_size = nil, 128
    local layout = {
        count = 0x1CE0, entries = 0xB9CE4, entry_stride = 24,
        states = 0x1CE4, state_stride = 184, status = 0x14,
    }
    local O = {available = false, reason = 'Ownership code signature unavailable'}
    local proof_records = setmetatable({}, {__mode = 'k'})
    local global_slot
    -- Native availability reader pins published for this exact game.dll hash.
    -- These are additional guards, not callable functions or replacement code.
    local stratagem_pins={
        {0x136FC74,'pin:5::9a6d12680f9a72b5'},
        {0x136FC89,'pin:8::2893b8a52a14aabf'},
        {0x136FC97,'pin:8::544c84447def4532'},
        {0x136FCC3,'pin:3::7cd9511b0cef217e'},
        {0x136FD04,'pin:3::7cd9511b0cef217e'},
    }
    -- Checked against the pins once; later calls compare the bytes captured then.
    local stratagem_blobs
    local function stratagem_code_matches()
        if not stratagem_blobs then
            local blobs={}
            for _,pin in ipairs(stratagem_pins) do
                local ok,blob=P.match(pin[1],pin[2])
                if not ok then return false end
                blobs[#blobs+1]={pin[1],blob}
            end
            stratagem_blobs=blobs
        end
        for _,entry in ipairs(stratagem_blobs) do
            if P.read(P.base+entry[1],#entry[2])~=entry[2] then return false end
        end
        return true
    end

    local function compatible()
        if not O.available then return false end
        if P.read(P.base+signature_rva,#signature_bytes) ~= signature_bytes then
            O.available = false
            O.reason = 'Ownership code signature changed; reload on a supported build'
            return false
        end
        return true
    end

    local function read(address, size)
        assert(type(address) == 'number' and address % 1 == 0
            and address >= 65536 and address + size <= maximum_address,
            'Ownership read address rejected')
        assert(type(size) == 'number' and size % 1 == 0 and size >= 1 and size <= 4096,
            'Ownership read size rejected')
        local data = P.read(address, size)
        assert(type(data) == 'string' and #data == size, 'Ownership data unreadable')
        return data
    end

    local function item_id_ok(id)
        return type(id) == 'number' and id % 1 == 0 and id > 0 and id < 4294967296
    end

    local function same_session(record)
        return read(global_slot, 8) == record.root_bytes
            and read(record.root + layout.count, 4) == record.count_bytes
    end

    local function recheck_record(record)
        if not compatible() or not same_session(record) then return false end
        -- Bind the item to the same 12 known bytes of its offer catalog row.
        -- Unknown trailing row fields are never treated as compatibility proof.
        if read(record.entry, 12) ~= record.entry_bytes then return false end
        if record.kind=='stratagem' then
            if not stratagem_code_matches() then return false end
            if read(record.entry+16,4)~=record.parent_link_bytes then return false end
            -- A parent proof binds BOTH the selected item/offer and the linked
            -- parent's row and owned state. It cannot grant an unrelated item.
            if record.parent_entry and read(record.parent_entry,12)~=record.parent_entry_bytes then return false end
            if read(record.owned_state+layout.status,4)~=record.status_bytes then return false end
            return read(record.entry,12)==record.entry_bytes and same_session(record) and compatible()
        end
        return false
    end

    local function capture_index()
        if not compatible() then return nil, O.reason end
        local root_bytes = read(global_slot, 8)
        local low, high = P.decode32(root_bytes, 0), P.decode32(root_bytes, 4)
        assert(high < 32768, 'Progression pointer rejected')
        local root = low + high * 4294967296
        assert(root >= 65536 and root + layout.entries + maximum_offers * layout.entry_stride
            <= maximum_address, 'Progression pointer out of bounds')
        local count_bytes = read(root + layout.count, 4)
        local count = P.decode32(count_bytes, 0)
        assert(count >= 1 and count <= maximum_offers, 'Progression count rejected')
        local index = {
            root = root, root_bytes = root_bytes, count_bytes = count_bytes, by_item = {},
        }
        -- One bounded index per transaction, not one full scan per item. This
        -- contains row identities only; it does not cache owned-state decisions.
        for first = 0, count - 1, batch_size do
            local length = math.min(batch_size, count - first)
            local start = root + layout.entries + first * layout.entry_stride
            local rows = read(start, (length - 1) * layout.entry_stride + 12)
            for position = 0, length - 1 do
                local offset = position * layout.entry_stride
                local state_index = P.decode32(rows, offset)
                assert(state_index < count, 'Progression state index rejected')
                local item_id, offer_id = P.decode32(rows, offset + 8), P.decode32(rows, offset + 4)
                if item_id ~= 0 and offer_id ~= 0 then
                    local candidates = index.by_item[item_id]
                    if not candidates then candidates = {}; index.by_item[item_id] = candidates end
                    candidates[#candidates + 1] = {
                        offer_id = offer_id, entry = start + offset, position=first+position,
                        entry_bytes = rows:sub(offset + 1, offset + 12),
                        state = root + layout.states + state_index * layout.state_stride,
                    }
                end
            end
        end
        if not same_session(index) or not compatible() then
            return nil, 'Progression changed during index observation'
        end
        return index
    end

    local function observe_stratagem(index,item_id,expected_offer_id)
        assert(item_id_ok(item_id) and item_id_ok(expected_offer_id),'Invalid stratagem item/offer ID')
        assert(compatible() and stratagem_code_matches(),'Stratagem ownership code changed')
        assert(same_session(index),'Progression snapshot expired')
        local reasons={}
        for _,candidate in ipairs(index.by_item[item_id] or {}) do
            if candidate.offer_id==expected_offer_id then
                assert(read(candidate.entry,12)==candidate.entry_bytes,'Stratagem offer row changed')
                local link_bytes=read(candidate.entry+16,4)
                local back=P.decode32(link_bytes,0)
                local direct_bytes=read(candidate.state+layout.status,4)
                local direct=P.decode32(direct_bytes,0)
                local selected_state,selected_bytes,parent_entry,parent_bytes
                local parent_status
                if direct==2 or direct==4 then
                    selected_state,selected_bytes=candidate.state,direct_bytes
                elseif back>0 then
                    -- Native relation: entry - back * 24. Never follow outside
                    -- this same observed table, or chase an arbitrary chain.
                    assert(back<=candidate.position,'Stratagem parent link out of bounds')
                    parent_entry=candidate.entry-back*layout.entry_stride
                    parent_bytes=read(parent_entry,12)
                    local parent_index=P.decode32(parent_bytes,0)
                    assert(parent_index<P.decode32(index.count_bytes,0),'Parent state index out of bounds')
                    local state=index.root+layout.states+parent_index*layout.state_stride
                    local bytes=read(state+layout.status,4)
                    parent_status=P.decode32(bytes,0)
                    if parent_status==2 or parent_status==4 then selected_state,selected_bytes=state,bytes end
                end
                if selected_state then
                    local record={kind='stratagem',root=index.root,root_bytes=index.root_bytes,
                        count_bytes=index.count_bytes,item_id=item_id,offer_id=expected_offer_id,
                        entry=candidate.entry,entry_bytes=candidate.entry_bytes,parent_link_bytes=link_bytes,
                        owned_state=selected_state,status_bytes=selected_bytes,
                        parent_entry=parent_entry,parent_entry_bytes=parent_bytes}
                    assert(recheck_record(record),'Stratagem ownership changed during observation')
                    return record
                end
                reasons[#reasons+1]='direct='..direct..',parent='..tostring(parent_status)..',back='..back
            end
        end
        return nil,#reasons==0 and 'No progression row matching item and picker offer'
            or 'Stratagem ownership refused: '..table.concat(reasons,'; ')
    end

    -- A snapshot is a private item/offer index, not a cached ownership result.
    -- Its owns() freshly reads candidate rows/states and returns true, proof or
    -- false, nil, reason. A failed snapshot is an object that always returns false.
    function O.snapshot(kind)
        assert(kind=='stratagem','Unsupported ownership policy')
        local ok, index, reason = pcall(function()
            assert(stratagem_code_matches(),'Stratagem availability instructions changed')
            return capture_index()
        end)
        if not ok then reason, index = tostring(index), nil end
        local snapshot = {available = index ~= nil, reason = reason}
        function snapshot.owns(item_id, expected_offer_id)
            if not index then return false, nil, snapshot.reason end
            local observed, record, failure = pcall(observe_stratagem, index, item_id, expected_offer_id)
            if not observed then return false, nil, tostring(record) end
            if not record then return false, nil, failure end
            local proof = {}
            proof_records[proof] = record
            return true, proof
        end
        return snapshot
    end

    -- Call immediately before use; do not serialize or reuse proofs as an
    -- entitlement cache. Proofs are accepted only by the instance that made them.
    -- Optional identifiers bind a proof to the caller's selected item and offer.
    function O.recheck(proof, optional_item_id, optional_offer_id)
        local record = type(proof) == 'table' and proof_records[proof] or nil
        if not record or (optional_item_id ~= nil and optional_item_id ~= record.item_id)
            or (optional_offer_id ~= nil and optional_offer_id ~= record.offer_id) then
            return false
        end
        local ok, current = pcall(recheck_record, record)
        return ok and current == true
    end

    local ok, result = pcall(function()
        assert(P.timestamp == 0x6AB3B43F, 'Unsupported ownership image timestamp')
        -- Fixed location on the supported build (found by the earlier unique scan,
        -- "Ownership resolved: code_rva=0x136F910" in the user's logs), checked by pin.
        signature_rva=0x136F910
        local fields = P.derive({{
            name = 'progression_owned_layout', rva = signature_rva, text = signature,
            fields = {progression = {'rip', {99}, {103}}, count_field = {'u32', {24}},
                entries_field = {'u32', {38}}, entry_stride = {'u8', {59}},
                state_stride = {'u32', {87}}, status_field = {'u32', {108}}},
        }, {
            -- Equipment widget lookup: the category range table that follows the rows.
            name = 'progression_ranges', rva = 0x18975D0, text = 'pin:37::ce4ecf2e443407a2',
            fields = {rows_end = {'u32', {33}}},
        }})
        -- The reader's operands must be the layout used here, and both arrays must hold
        -- the same whole number of rows: states [states, entries), rows [entries, rows_end).
        assert(fields.count_field == layout.count and fields.entries_field == layout.entries
            and fields.entry_stride == layout.entry_stride and fields.state_stride == layout.state_stride
            and fields.status_field == layout.states + layout.status, 'Progression layout facts disagree')
        local rows = (fields.rows_end - layout.entries) / layout.entry_stride
        local states = (layout.entries - layout.states) / layout.state_stride
        assert(rows % 1 == 0 and rows == states and rows > 0 and rows <= 65536,
            'Progression capacity facts disagree')
        maximum_offers = rows
        O.capacity = rows
        P.log('Progression capacity from code: '..rows..' rows')
        local offer_specs={}
        for _,spec in ipairs(RLM.signatures) do
            if spec.name=='offers_count' or spec.name=='refresh_b' then offer_specs[#offer_specs+1]=spec end
        end
        assert(#offer_specs==2,'Independent offer signatures unavailable')
        local offers=P.derive(offer_specs)
        assert(fields.progression==offers.offers,'Ownership and stratagem offer globals disagree')
        assert(offers.entries==layout.entries and offers.offers_count==layout.count,
            'Ownership and stratagem offer layouts disagree')
        local matched,blob=P.match(signature_rva,signature)
        assert(matched,'Ownership code changed during resolution')
        signature_bytes=blob
        P.log(string.format('Ownership resolved: code_rva=0x%X global_rva=0x%X; independent offer layout agrees',
            signature_rva,fields.progression))
        return P.base + fields.progression
    end)
    if ok then
        global_slot = result
        O.available, O.reason = true, nil
    else
        O.reason = tostring(result)
    end
    return O
end
