local ADDON = ...

-- Buffs each class can cast on others. Only spells the character actually knows are listed.
local CLASS_BUFFS = {
    DRUID   = { 1126, 305497, 774, 8936, 33763, 48438, 102342, 29166 },
    PRIEST  = { 21562, 17, 139, 194384, 41635, 10060, 33206, 47788 },
    MAGE    = { 1459, 130, 54646 },
    WARRIOR = { 6673, 3411 },
    PALADIN = { 53563, 156910, 200025, 1022, 6940, 1044, 465, 156322, 223306 },
    SHAMAN  = { 462854, 974, 61295 },
    MONK    = { 115175, 119611, 124682, 116849 },
    EVOKER  = { 364342, 369459, 366155, 360827, 410089, 357170, 355941 },
    HUNTER  = { 34477 },
    ROGUE   = { 57934 },
    WARLOCK = { 20707 },
}

-- Tracked out of the box: the long-lasting raid/party buffs. Everything else starts untracked.
local DEFAULT_TRACKED = {
    [1126] = true, [305497] = true, [21562] = true, [1459] = true,
    [6673] = true, [462854] = true, [364342] = true,
}

-- Buffs matched by spell NAME, so every rank (and any client's spell IDs) resolves to whatever
-- the character has actually learned. Spells the character doesn't know are not listed.
local CLASSIC_BUFFS = {
    DRUID   = { "Mark of the Wild", "Thorns", "Omen of Clarity", "Nature's Grasp", "Rejuvenation", "Regrowth", "Innervate" },
    PRIEST  = { "Power Word: Fortitude", "Divine Spirit", "Shadow Protection", "Power Word: Shield", "Renew", "Fear Ward",
                "Levitate", "Inner Fire", "Shadowform", "Touch of Weakness" },
    MAGE    = { "Arcane Intellect", "Dampen Magic", "Amplify Magic", "Slow Fall", "Frost Armor", "Ice Armor", "Mage Armor",
                "Mana Shield", "Ice Barrier" },
    WARRIOR = { "Battle Shout" },
    PALADIN = { "Blessing of Might", "Blessing of Wisdom", "Blessing of Kings", "Blessing of Salvation", "Blessing of Light",
                "Blessing of Sanctuary", "Blessing of Freedom", "Blessing of Protection", "Blessing of Sacrifice",
                "Devotion Aura", "Retribution Aura", "Concentration Aura", "Sanctity Aura",
                "Shadow Resistance Aura", "Frost Resistance Aura", "Fire Resistance Aura" },
    SHAMAN  = { "Lightning Shield", "Water Walking", "Water Breathing", "Strength of Earth Totem", "Grace of Air Totem",
                "Windfury Totem", "Stoneskin Totem", "Mana Spring Totem", "Healing Stream Totem", "Tranquil Air Totem",
                "Fire Resistance Totem", "Frost Resistance Totem", "Nature Resistance Totem" },
    HUNTER  = { "Trueshot Aura", "Aspect of the Pack", "Aspect of the Hawk", "Aspect of the Wild" },
    ROGUE   = { "Slice and Dice" },
    WARLOCK = { "Unending Breath", "Detect Invisibility", "Demon Skin", "Demon Armor" },
}

-- Group versions of a buff count as the single-target buff being present (and aren't listed on their own),
-- and totem spells put an aura with a different name on the party.
local ALT_AURAS = {
    ["Mark of the Wild"] = { "Gift of the Wild" },
    ["Power Word: Fortitude"] = { "Prayer of Fortitude" },
    ["Divine Spirit"] = { "Prayer of Spirit" },
    ["Shadow Protection"] = { "Prayer of Shadow Protection" },
    ["Arcane Intellect"] = { "Arcane Brilliance" },
    ["Strength of Earth Totem"] = { "Strength of Earth" },
    ["Grace of Air Totem"] = { "Grace of Air" },
    ["Stoneskin Totem"] = { "Stoneskin" },
    ["Mana Spring Totem"] = { "Mana Spring" },
    ["Healing Stream Totem"] = { "Healing Stream" },
    ["Tranquil Air Totem"] = { "Tranquil Air" },
    ["Fire Resistance Totem"] = { "Fire Resistance" },
    ["Frost Resistance Totem"] = { "Frost Resistance" },
    ["Nature Resistance Totem"] = { "Nature Resistance" },
}
local GROUP_SPELLS = {
    ["Gift of the Wild"] = true, ["Prayer of Fortitude"] = true, ["Prayer of Spirit"] = true,
    ["Prayer of Shadow Protection"] = true, ["Arcane Brilliance"] = true,
}
-- Buffs you can only put on yourself: they're only checked on your own frame.
local SELF_ONLY = {
    ["Omen of Clarity"] = true, ["Nature's Grasp"] = true, ["Inner Fire"] = true, ["Shadowform"] = true,
    ["Touch of Weakness"] = true, ["Frost Armor"] = true, ["Ice Armor"] = true, ["Mage Armor"] = true,
    ["Mana Shield"] = true, ["Ice Barrier"] = true, ["Lightning Shield"] = true, ["Aspect of the Hawk"] = true,
    ["Aspect of the Wild"] = true, ["Slice and Dice"] = true, ["Demon Skin"] = true, ["Demon Armor"] = true,
}
-- What each class normally keeps up: tracked out of the box (everything else starts untracked).
local DEFAULT_TRACKED_NAMES = {
    ["Mark of the Wild"] = true, ["Omen of Clarity"] = true,                                  -- Druid
    ["Power Word: Fortitude"] = true, ["Divine Spirit"] = true, ["Inner Fire"] = true,        -- Priest
    ["Arcane Intellect"] = true,                                                              -- Mage
    ["Battle Shout"] = true,                                                                  -- Warrior
    ["Blessing of Might"] = true, ["Blessing of Wisdom"] = true, ["Blessing of Kings"] = true, -- Paladin
    ["Lightning Shield"] = true,                                                              -- Shaman
    ["Aspect of the Hawk"] = true,                                                            -- Hunter
}
-- Mutually exclusive buffs: only the best one the character knows is tracked by default.
local DEFAULT_BEST_OF = {
    { "Mage Armor", "Ice Armor", "Frost Armor" },
    { "Demon Armor", "Demon Skin" },
}

local DEFAULTS = {
    frameMode = "always",      -- "always" | "party" | "raid"
    buffMode = "missing",      -- "missing" | "active"
    anchor = "BOTTOMRIGHT",    -- corner of the raid frame the icons sit in
    minimapShow = true,
    minimapAngle = 215,
    soloClassColors = true,    -- class-colored health bar on the solo frame
}

local ANCHORS = { "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT", "TOPLEFT" }
local ANCHOR_LABEL = { BOTTOMRIGHT = "Bottom right", BOTTOMLEFT = "Bottom left", TOPRIGHT = "Top right", TOPLEFT = "Top left" }
local ICON = "Interface\\AddOns\\CupCheck\\icon"

local db, playerClass
local tracked = {}                                   -- enabled buffs: { id=, name=, icon= }
local frames = {}                                    -- compact raid/party frames (+ solo)
local overlays = setmetatable({}, { __mode = "k" })  -- frame -> our icon buttons
local pendingApply = false

local function Print(msg) print("|cff66ccffCup Check:|r " .. msg) end

local reported = {}
local function Safe(tag, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[tag] then
        reported[tag] = true
        Print(tag .. " error: " .. tostring(err))
    end
end

---------------------------------------------------------------------------
-- Buff list (class defaults + custom; each is tracked or not)
---------------------------------------------------------------------------
local function Known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) or false
end

-- key is the saved-settings key: the spell ID for ID-listed and custom buffs, the spell name for name-matched ones.
local function IsTracked(key, custom, name, id)
    local v = db.tracked[key]
    if v == nil then return custom or DEFAULT_TRACKED[id] or DEFAULT_TRACKED_NAMES[name] or false end
    return v
end

-- Every buff listed for this class (known spells only; if none resolve, list them all), with tracked state.
local function AllBuffs()
    local out, have, seen = {}, {}, {}
    local function push(key, id, name, custom)
        have[id] = true
        seen[name] = true
        out[#out + 1] = { id = id, key = key, name = name, icon = C_Spell.GetSpellTexture(id), custom = custom,
            tracked = IsTracked(key, custom, name, id) }
    end
    local function add(id, custom, requireKnown)
        if have[id] then return end
        local name = C_Spell.GetSpellName(id)
        if not name or (requireKnown and not Known(id)) then return end
        if not custom and (GROUP_SPELLS[name] or seen[name]) then return end
        push(id, id, name, custom)
    end
    local ids = CLASS_BUFFS[playerClass] or {}
    for _, id in ipairs(ids) do add(id, false, true) end
    -- By name: finds whichever rank the character knows (the spellbook may only hold the newest rank).
    for _, name in ipairs(CLASSIC_BUFFS[playerClass] or {}) do
        if not seen[name] then
            local info = C_Spell.GetSpellInfo(name)
            local id = info and info.spellID
            if id and not have[id] and Known(id) then push(name, id, name, false) end
        end
    end
    if #out == 0 then for _, id in ipairs(ids) do add(id, false, false) end end
    for _, id in ipairs(db.custom[playerClass] or {}) do add(id, true, false) end
    local bestOf = {}
    for _, group in ipairs(DEFAULT_BEST_OF) do
        for _, n in ipairs(group) do
            if seen[n] then bestOf[n] = true break end
        end
    end
    for _, b in ipairs(out) do
        if db.tracked[b.key] == nil and bestOf[b.name] then b.tracked = true end
    end
    return out
end

-- The aura on a unit for a tracked buff, counting group versions of the same buff.
local function FindAura(unit, buff)
    local aura = C_UnitAuras.GetAuraDataBySpellName(unit, buff.name, "HELPFUL")
    if aura then return aura end
    local alt = ALT_AURAS[buff.name]
    if alt then
        for _, n in ipairs(alt) do
            aura = C_UnitAuras.GetAuraDataBySpellName(unit, n, "HELPFUL")
            if aura then return aura end
        end
    end
end

local function LoadBuffs()
    wipe(tracked)
    for _, b in ipairs(AllBuffs()) do
        if b.tracked then tracked[#tracked + 1] = b end
    end
end

---------------------------------------------------------------------------
-- Icons on raid frames. We only READ Blizzard's frames (unit token) and parent our own
-- icons to them; we never call or modify Blizzard's frame code (that taints it).
---------------------------------------------------------------------------
local function NewIcon(frame)
    local b = CreateFrame("Frame", nil, frame)
    b:SetFrameLevel(frame:GetFrameLevel() + 10)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints()
    b.cooldown:SetDrawEdge(false)
    b:Hide()
    return b
end

local function Layout(frame, list)
    local a = db.anchor
    local left = a:find("LEFT") ~= nil
    local top = a:find("TOP") ~= nil
    -- Blizzard's native aura size is 11, scaled with the frame like its own icons; bottom icons sit above the power bar.
    local scale = 1
    local w, h = frame:GetSize()
    if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then scale = math.min(h / 36, w / 72) end
    scale = math.max(0.5, math.min(2, scale))
    local size = 11 * scale
    local pad = 2 * scale
    if not top then
        local pb = frame.powerBar or frame.power
        if pb and pb:IsShown() then
            local ph = pb:GetHeight()
            pad = pad + (type(ph) == "number" and ph or 8 * scale)
        end
    end
    local prev
    for _, b in ipairs(list) do
        b:SetSize(size, size)
        b:ClearAllPoints()
        if b.want then
            if not prev then
                b:SetPoint(a, frame, a, left and 3 or -3, top and -pad or pad)
            else
                b:SetPoint(left and "LEFT" or "RIGHT", prev, left and "RIGHT" or "LEFT", left and 1 or -1, 0)
            end
            b:Show()
            prev = b
        else
            b:Hide()
        end
    end
end

local function UpdateFrame(frame)
    if frame.IsForbidden and frame:IsForbidden() then return end
    local unit = frame.displayedUnit or frame.unit
    if type(unit) ~= "string" then return end
    local list = overlays[frame]
    if not list then list = {}; overlays[frame] = list end
    local canRead = not InCombatLockdown()
    local valid = canRead and UnitExists(unit) and UnitIsPlayer(unit) and UnitIsConnected(unit)
        and not UnitIsDeadOrGhost(unit) and UnitIsFriend("player", unit)
    local isSelf = valid and UnitIsUnit(unit, "player") or false
    for i, buff in ipairs(tracked) do
        local b = list[i]
        if not b then b = NewIcon(frame); list[i] = b end
        if canRead then
            local applies = valid and (isSelf or not SELF_ONLY[buff.name]) or false
            local aura = applies and FindAura(unit, buff) or nil
            if db.buffMode == "missing" then b.want = applies and not aura or false
            else b.want = applies and aura ~= nil or false end
            b.icon:SetTexture(buff.icon)
            if b.want and aura and aura.duration and aura.duration > 0 then
                CooldownFrame_Set(b.cooldown, aura.expirationTime - aura.duration, aura.duration, true)
            else
                CooldownFrame_Clear(b.cooldown)
            end
        end
    end
    for i = #tracked + 1, #list do list[i].want = false end   -- buffs hidden in options
    Layout(frame, list)
end

-- "party" for compact party members, "raid" for raid frames, nil for everything else.
-- Some frames hand back names that aren't plain strings, so this runs under pcall.
local function FrameKind(f)
    local name = f:GetName()
    if type(name) ~= "string" then return nil end
    if string.find(name, "^CompactPartyFrameMember%d+$") then return "party" end
    if string.find(name, "^CompactRaidFrame%d+$") or string.find(name, "^CompactRaidGroup%d+Member%d+$") then return "raid" end
end

local function ScanFrames()
    wipe(frames)
    if CupCheckSolo then frames[1] = CupCheckSolo end   -- always first, so a scan problem can't drop it
    local f = EnumerateFrames()
    while f do
        local ok, kind = pcall(FrameKind, f)
        if ok and kind then
            frames[#frames + 1] = f
            -- Remember the real frame size so the solo copy can match it when Edit Mode can't be read.
            if db and kind == "party" then
                local ok2, w, h = pcall(function() return f:GetSize() end)
                if ok2 and type(w) == "number" and w > 20 and h > 10 then db.lastSize = { w, h } end
            end
        end
        f = EnumerateFrames(f)
    end
end

local function RefreshAll(rescan)
    if rescan then ScanFrames() end
    for _, f in ipairs(frames) do Safe("update", UpdateFrame, f) end
end

---------------------------------------------------------------------------
-- Solo frame (Blizzard's frames don't exist when ungrouped, and can't be driven from addons)
---------------------------------------------------------------------------
local function CreateSolo()
    if CupCheckSolo then return end
    -- Our own copy of Blizzard's raid frame look (their frame code can't be driven from addons here).
    -- Atlases and layout rules are taken from Blizzard's CompactUnitFrame source.
    local f = CreateFrame("Button", "CupCheckSolo", UIParent, "SecureUnitButtonTemplate")
    f.unit, f.displayedUnit = "player", "player"
    f:SetAttribute("unit", "player")
    f:SetAttribute("type1", "target")
    f:SetAttribute("type2", "togglemenu")
    f:RegisterForClicks("AnyUp")
    f:SetFrameStrata("LOW")
    f:SetSize(72, 36)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -200)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() and not InCombatLockdown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        db.pos = { p, rp, x, y }
    end)
    if db.pos then
        f:ClearAllPoints()
        f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    end

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetAtlas("raidframe-hp-bg-white")
    f.bg:SetHorizTile(true); f.bg:SetVertTile(true)
    f.bg:SetVertexColor(0.15, 0.15, 0.15)

    f.health = CreateFrame("StatusBar", nil, f)
    f.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.health:GetStatusBarTexture():SetAtlas("RaidFrame-Hp-Fill")
    f.health:SetFrameLevel(f:GetFrameLevel() + 1)

    f.power = CreateFrame("StatusBar", nil, f)
    f.power:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.power:SetFrameLevel(f:GetFrameLevel() + 2)   -- plain fill so the power color always shows
    f.power.bg = f.power:CreateTexture(nil, "BACKGROUND")
    f.power.bg:SetAllPoints()
    f.power.bg:SetAtlas("_RaidFrame-Resource-Background")

    f.name = f.health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetPoint("CENTER", f, "CENTER", 0, 4)
    f.name:SetWordWrap(false)
    f.name:SetJustifyH("CENTER")
    f.name:SetWidth(60)
    f.name:SetText(UnitName("player"))

    f.status = f.health:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.status:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)

    f.select = f:CreateTexture(nil, "OVERLAY")
    f.select:SetAtlas("RaidFrame-TargetFrame")
    f.select:SetAllPoints()
    f.select:Hide()

    local function UpdateHealth()
        local cur, max = UnitHealth("player"), UnitHealthMax("player")
        f.health:SetMinMaxValues(0, max)
        f.health:SetValue(cur)
        local opts = DefaultCompactUnitFrameOptions or {}
        local mode = opts.displayStatusText ~= false and opts.healthText or "none"
        if UnitIsDeadOrGhost("player") then f.status:SetText(DEAD)
        elseif mode == "health" then f.status:SetText(AbbreviateLargeNumbers(cur))
        elseif mode == "losthealth" and max > cur then f.status:SetText("-" .. AbbreviateLargeNumbers(max - cur))
        elseif mode == "perc" and max > 0 then f.status:SetText(math.ceil(cur / max * 100) .. "%")
        else f.status:SetText("") end
    end
    local function UpdatePower()
        local ptype, token = UnitPowerType("player")
        f.power:SetMinMaxValues(0, UnitPowerMax("player", ptype))
        f.power:SetValue(UnitPower("player", ptype))
        local col = PowerBarColor[token] or PowerBarColor[ptype] or { r = 0, g = 0.4, b = 1 }
        f.power:SetStatusBarColor(col.r, col.g, col.b)
    end
    local function UpdateTarget() f.select:SetShown(UnitIsUnit("target", "player")) end

    f:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_TARGET_CHANGED" then UpdateTarget()
        elseif event:find("POWER") or event == "UNIT_DISPLAYPOWER" then UpdatePower()
        elseif event == "PLAYER_ENTERING_WORLD" then UpdateHealth(); UpdatePower()
        else UpdateHealth() end
    end)
    f:RegisterUnitEvent("UNIT_HEALTH", "player")
    f:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    f:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    f:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    f:RegisterUnitEvent("UNIT_DISPLAYPOWER", "player")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Size, power bar and colors follow the player's raid-frame settings (read-only lookups).
    function f.ApplyLook()
        if InCombatLockdown() then return end
        local w, h
        -- Blizzard's lookup is keyed by the Edit Mode unit-frame system index; the solo frame mirrors the party frame.
        local gt = Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Party
        if EditModeManagerFrame and EditModeManagerFrame.GetRaidFrameWidth then
            local ok, rw, rh = pcall(function()
                return EditModeManagerFrame:GetRaidFrameWidth(gt, 72), EditModeManagerFrame:GetRaidFrameHeight(gt, 36)
            end)
            if ok and type(rw) == "number" and type(rh) == "number" then w, h = rw, rh end
        end
        if not w and db.lastSize then w, h = db.lastSize[1], db.lastSize[2] end
        w, h = w or 72, h or 36
        f:SetSize(w, h)

        local setup = DefaultCompactUnitFrameSetupOptions or {}
        local showPower = setup.displayPowerBar ~= false
        if showPower and setup.displayOnlyHealerPowerBars then
            -- Same rule as Blizzard's option: only healers get a power bar.
            local spec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization()
            local getRole = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole
            local ok, role = pcall(function() return getRole and getRole(spec) end)
            if ok and role then showPower = (role == "HEALER") end
        end
        local barH = showPower and 8 or 0
        f.health:ClearAllPoints()
        f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
        f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1 + barH)
        f.power:ClearAllPoints()
        f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, 0)
        f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
        f.power:SetShown(showPower)
        f.name:SetWidth(w - 12)

        local c = RAID_CLASS_COLORS[playerClass]
        if db.soloClassColors and c then f.health:SetStatusBarColor(c.r, c.g, c.b)
        else f.health:SetStatusBarColor(0, 1, 0) end
        UpdateHealth(); UpdatePower(); UpdateTarget()
    end
    f.ApplyLook()
    f:Hide()
end

---------------------------------------------------------------------------
-- Raid frame display mode (always / 5-mans + raids / raids only)
---------------------------------------------------------------------------
-- Turns Blizzard's "Use Raid-Style Party Frames" Edit Mode option on/off in the active custom layout.
-- Returns true on success, or false plus a reason. Edit Mode presets can't be edited.
local function SetRaidStyleParty(want)
    if not (C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts) then return false, "Edit Mode API not available" end
    local sys = Enum.EditModeSystem and Enum.EditModeSystem.UnitFrame
    local idx = Enum.EditModeUnitFrameSystemIndices and Enum.EditModeUnitFrameSystemIndices.Party
    local setting = Enum.EditModeUnitFrameSetting and Enum.EditModeUnitFrameSetting.UseRaidStylePartyFrames
    if not (sys and idx and setting) then return false, "Edit Mode setting names not found" end
    local info = C_EditMode.GetLayouts()
    if not (info and info.layouts) then return false, "no Edit Mode layouts" end
    local numPresets = 0
    for _ in pairs(Enum.EditModePresetLayouts or {}) do numPresets = numPresets + 1 end
    local layout = info.layouts[info.activeLayout - numPresets]
    if not layout then return false, "your active Edit Mode layout is a preset; copy it to a custom layout first" end
    local value = want and 1 or 0
    for _, s in ipairs(layout.systems or {}) do
        if s.system == sys and s.systemIndex == idx then
            for _, st in ipairs(s.settings or {}) do
                if st.setting == setting then
                    if st.value == value then return true end
                    st.value = value
                    C_EditMode.SaveLayouts(info)
                    if C_EditMode.SetActiveLayout then C_EditMode.SetActiveLayout(info.activeLayout) end
                    return true
                end
            end
        end
    end
    return false, "raid-style party setting not found in your layout"
end

local appliedRaidStyle   -- last value we tried; reset when the user picks a different frame mode

local function ApplyFrameMode()
    if InCombatLockdown() then pendingApply = true return end
    pendingApply = false
    -- "Always" and "5-mans and raids" both need Blizzard's raid-style party frames on; "raids only" turns them off.
    local wantRaidStyle = db.frameMode ~= "raid"
    if appliedRaidStyle ~= wantRaidStyle then
        appliedRaidStyle = wantRaidStyle
        local ok, res, why = pcall(SetRaidStyleParty, wantRaidStyle)
        if not ok then Print("raid-style party frames error: " .. tostring(res))
        elseif not res then Print("couldn't change Blizzard's raid-style party frames: " .. tostring(why)
            .. ". Set it yourself in Edit Mode > Party Frames.") end
    end
    -- Secure state driver: the solo frame vanishes the instant you join a group (even mid-combat),
    -- so it can never overlap Blizzard's own group frames.
    local solo = CupCheckSolo
    if solo then
        RegisterStateDriver(solo, "visibility", db.frameMode == "always" and "[group] hide; show" or "hide")
        if solo.ApplyLook then Safe("solo look", solo.ApplyLook) end
    end
end

local function PositionMinimapButton()
    local b = CupCheckMinimapButton
    if not b then return end
    local a = math.rad(db.minimapAngle)
    local r = Minimap:GetWidth() / 2 + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    b:SetShown(db.minimapShow)
end

local function ApplyAll(rescan)
    PositionMinimapButton()
    Safe("frames", ApplyFrameMode)
    Safe("buffs", LoadBuffs)
    Safe("refresh", RefreshAll, rescan)
end

---------------------------------------------------------------------------
-- Options window
---------------------------------------------------------------------------
local optionsFrame

local function Header(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
end

local function MakeCheck(parent, label, y, get, set)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", 14, y)
    b:SetSize(26, 26)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", b, "RIGHT", 2, 0)
    fs:SetText(label)
    b:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    parent.refreshers[#parent.refreshers + 1] = function() b:SetChecked(get()) end
end

local function MakeRadios(parent, key, choices, y)
    local group = {}
    local function refresh() for _, o in ipairs(group) do o:SetChecked(o.value == db[key]) end end
    for i, c in ipairs(choices) do
        local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        b:SetPoint("TOPLEFT", 14, y - (i - 1) * 26)
        b:SetSize(26, 26)
        b.value = c[1]
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("LEFT", b, "RIGHT", 2, 0)
        fs:SetText(c[2])
        b:SetScript("OnClick", function(self)
            db[key] = self.value
            if key == "frameMode" then appliedRaidStyle = nil end   -- retry the Edit Mode change
            refresh(); ApplyAll()
        end)
        group[i] = b
    end
    parent.refreshers[#parent.refreshers + 1] = refresh
end

local function CreateOptions()
    local f = CreateFrame("Frame", "CupCheckOptions", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(400, 640)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    if f.SetTitle then f:SetTitle("Cup Check")
    elseif f.TitleText then f.TitleText:SetText("Cup Check") end
    f.refreshers = {}
    tinsert(UISpecialFrames, "CupCheckOptions")

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(48, 48)
    logo:SetPoint("TOPRIGHT", -52, -34)
    logo:SetTexture(ICON)

    Header(f, "Raid frames", -34)
    MakeRadios(f, "frameMode", {
        { "always", "Always show (even solo)" },
        { "party",  "Show in 5-mans and raids" },
        { "raid",   "Show in raids only" },
    }, -52)

    Header(f, "Class buffs", -146)
    MakeRadios(f, "buffMode", {
        { "missing", "Show when missing" },
        { "active",  "Show when active" },
    }, -164)

    local pos = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    pos:SetSize(200, 22)
    pos:SetPoint("TOPLEFT", 18, -220)
    pos:SetScript("OnClick", function()
        local idx = 1
        for i, a in ipairs(ANCHORS) do if a == db.anchor then idx = i end end
        db.anchor = ANCHORS[idx % #ANCHORS + 1]
        ApplyAll()
        f:GetScript("OnShow")(f)
    end)
    f.refreshers[#f.refreshers + 1] = function() pos:SetText("Icon position: " .. ANCHOR_LABEL[db.anchor]) end

    Header(f, "Buffs for your class (click to move)", -256)
    local function ColumnHeader(text, x)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", x, -276)
        fs:SetText(text)
    end
    ColumnHeader("Tracked", 20)
    ColumnHeader("Not tracked", 190)

    -- Two columns inside a scroll area; rows are created on demand so any number of buffs fits.
    -- Clicking a row moves that buff to the other column.
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -292)
    scroll:SetSize(340, 220)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(340, 220)
    scroll:SetScrollChild(content)

    local cols = { tracked = {}, untracked = {} }
    local COL_X = { tracked = 0, untracked = 170 }
    local function GetRow(key, i)
        local r = cols[key][i]
        if r then return r end
        r = CreateFrame("Button", nil, content)
        r:SetSize(166, 22)
        r:SetPoint("TOPLEFT", COL_X[key], -(i - 1) * 22)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.pic = r:CreateTexture(nil, "ARTWORK")
        r.pic:SetSize(18, 18)
        r.pic:SetPoint("LEFT", 2, 0)
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        r.label:SetPoint("LEFT", r.pic, "RIGHT", 4, 0)
        r.label:SetWidth(142)
        r.label:SetWordWrap(false)
        r.label:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                if not self.custom then return end
                local list = db.custom[playerClass]
                for k, id in ipairs(list or {}) do if id == self.id then table.remove(list, k) break end end
                db.tracked[self.key] = nil
            else
                db.tracked[self.key] = not self.tracked
            end
            ApplyAll()
            f:GetScript("OnShow")(f)
        end)
        cols[key][i] = r
        return r
    end
    f.refreshers[#f.refreshers + 1] = function()
        local n = { tracked = 0, untracked = 0 }
        for _, b in ipairs(AllBuffs()) do
            local key = b.tracked and "tracked" or "untracked"
            n[key] = n[key] + 1
            local r = GetRow(key, n[key])
            r.id, r.key, r.custom, r.tracked = b.id, b.key, b.custom, b.tracked
            r.pic:SetTexture(b.icon)
            r.label:SetText(b.name)
            r:Show()
        end
        for key, list in pairs(cols) do
            for i = n[key] + 1, #list do list[i]:Hide() end
        end
        content:SetHeight(math.max(220, math.max(n.tracked, n.untracked) * 22))
    end

    local add = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    add:SetSize(130, 22)
    add:SetPoint("TOPLEFT", 24, -524)
    add:SetAutoFocus(false)
    local addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    addBtn:SetSize(150, 22)
    addBtn:SetText("Add spell ID or name")
    addBtn:SetPoint("LEFT", add, "RIGHT", 8, 0)
    local function AddCustom()
        local text = strtrim(add:GetText() or "")
        local id = tonumber(text)
        if not id and text ~= "" then
            local info = C_Spell.GetSpellInfo(text)
            id = info and info.spellID
        end
        if id and C_Spell.GetSpellName(id) then
            db.custom[playerClass] = db.custom[playerClass] or {}
            table.insert(db.custom[playerClass], id)
            add:SetText("")
            ApplyAll()
            f:GetScript("OnShow")(f)
        else
            Print("couldn't find that spell")
        end
    end
    addBtn:SetScript("OnClick", AddCustom)
    add:SetScript("OnEnterPressed", AddCustom)
    add:SetScript("OnEscapePressed", add.ClearFocus)

    MakeCheck(f, "Show minimap button", -556,
        function() return db.minimapShow end,
        function(v) db.minimapShow = v; ApplyAll() end)
    MakeCheck(f, "Class-colored solo frame", -580,
        function() return db.soloClassColors end,
        function(v) db.soloClassColors = v; ApplyAll() end)

    local tagline = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tagline:SetPoint("TOP", logo, "BOTTOM", 0, -4)
    tagline:SetWidth(124)
    tagline:SetJustifyH("CENTER")
    tagline:SetText("Covering the essentials\nsince level 1.")

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", 16, 10)
    note:SetWidth(368)
    note:SetJustifyH("LEFT")
    note:SetText("Shift-drag the solo frame to move it. Right-click a custom spell to remove it.")

    f:SetScript("OnShow", function(self) for _, r in ipairs(self.refreshers) do r() end end)
    return f
end

local function ToggleOptions()
    if not optionsFrame then optionsFrame = CreateOptions() end
    optionsFrame:SetShown(not optionsFrame:IsShown())
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local function CreateMinimapButton()
    local b = CreateFrame("Button", "CupCheckMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(24, 24)
    bg:SetPoint("TOPLEFT", 5, -4.5)
    bg:SetVertexColor(0, 0, 0)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 6, -6)
    icon:SetTexture(ICON)
    -- The art fills its whole square; pad it with its own black edge so the circular mask doesn't clip the cup.
    icon:SetTexCoord(-0.16, 1.16, -0.16, 1.16)
    local mask = b:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    b:SetScript("OnClick", ToggleOptions)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Cup Check")
        GameTooltip:AddLine("Click: options   Drag: move", 1, 1, 1)
        -- Who is missing what, from the icons currently showing on visible frames.
        if db.buffMode == "missing" and #tracked > 0 then
            GameTooltip:AddLine(" ")
            local any = false
            for i, buff in ipairs(tracked) do
                local names, seenUnit = {}, {}
                for _, f in ipairs(frames) do
                    local l = overlays[f]
                    local u = f.displayedUnit or f.unit
                    if l and l[i] and l[i].want and f:IsVisible() and type(u) == "string" and not seenUnit[u] then
                        seenUnit[u] = true
                        names[#names + 1] = UnitName(u) or u
                    end
                end
                if #names > 0 then
                    any = true
                    table.sort(names)
                    GameTooltip:AddLine("|T" .. tostring(buff.icon) .. ":14|t " .. buff.name .. " (" .. #names .. ")", 1, 0.82, 0)
                    GameTooltip:AddLine(table.concat(names, ", "), 1, 1, 1, true)
                end
            end
            if not any then GameTooltip:AddLine("Everyone is buffed", 0.4, 1, 0.4) end
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local mx, my = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            db.minimapAngle = math.deg(math.atan2(my / s - cy, mx / s - cx))
            PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
end

---------------------------------------------------------------------------
-- Events / slash
---------------------------------------------------------------------------
local dirtyUnits, flushQueued = {}, false

local function FlushAuras()
    flushQueued = false
    if InCombatLockdown() then wipe(dirtyUnits) return end
    for _, f in ipairs(frames) do
        local u = f.displayedUnit or f.unit
        if type(u) == "string" and dirtyUnits[u] then Safe("update", UpdateFrame, f) end
    end
    wipe(dirtyUnits)
end

local rescanPending = false
local function QueueRescan()
    if rescanPending then return end
    rescanPending = true
    C_Timer.After(0.5, function()
        rescanPending = false
        ApplyAll(true)
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GROUP_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")   -- layout switched or saved
ev:RegisterEvent("UNIT_AURA")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_AURA" then
        if type(arg1) == "string" and not InCombatLockdown() then
            dirtyUnits[arg1] = true
            if not flushQueued then flushQueued = true; C_Timer.After(0.2, FlushAuras) end
        end
    elseif event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        CupCheckDB = CupCheckDB or {}
        db = CupCheckDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        db.tracked = db.tracked or {}
        db.custom = db.custom or {}
    elseif event == "PLAYER_LOGIN" then
        playerClass = select(2, UnitClass("player"))
        Safe("minimap", CreateMinimapButton)
        Safe("solo", CreateSolo)
        -- Keep the solo frame the same size as the party frame while Edit Mode is open, and after it closes.
        if EventRegistry and EventRegistry.RegisterCallback then
            local editTicker
            local function RefreshSoloLook()
                local s = CupCheckSolo
                if s and s.ApplyLook then Safe("solo look", s.ApplyLook) end
            end
            EventRegistry:RegisterCallback("EditMode.Enter", function()
                if not editTicker then editTicker = C_Timer.NewTicker(0.3, RefreshSoloLook) end
            end, "CupCheck")
            EventRegistry:RegisterCallback("EditMode.Exit", function()
                if editTicker then editTicker:Cancel(); editTicker = nil end
                RefreshSoloLook()
            end, "CupCheck")
        end
        ApplyAll(true)
        -- Spell data can still be loading at login; recompute once things have settled.
        C_Timer.After(2, function() ApplyAll(true) end)
        C_Timer.After(6, function() ApplyAll(true) end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingApply then ApplyAll(true) else RefreshAll() end
    else -- PLAYER_ENTERING_WORLD, GROUP_ROSTER_UPDATE, SPELLS_CHANGED
        if db and playerClass then QueueRescan() end
    end
end)

SLASH_CUPCHECK1 = "/cupcheck"
-- /cupcheck debug: shows how each name-matched buff resolved for this character.
local function DebugDump()
    Print("class " .. tostring(playerClass))
    for _, name in ipairs(CLASSIC_BUFFS[playerClass] or {}) do
        local info = C_Spell.GetSpellInfo(name)
        local id = info and info.spellID
        Print(name .. ": " .. (id and (id .. (Known(id) and " known" or " not known")) or "not found"))
    end
end

SlashCmdList.CUPCHECK = function(msg)
    if strtrim(msg or ""):lower() == "debug" then Safe("debug", DebugDump) else ToggleOptions() end
end
