-- Restockr/Scan.lua
local ADDON = ...
local R = _G[ADDON]

R.Scan = R.Scan or {}
local Scan = R.Scan

-- Compact count collector for current character
local function collectBags()
  local counts = {}
  for bag = 0, NUM_BAG_SLOTS do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for s = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, s)
      if info and info.hyperlink and info.stackCount then
        local id, bonus = R.parseItemLink(info.hyperlink)
        if id then
          local key = R.itemKey(id, bonus)
          counts[key] = (counts[key] or 0) + info.stackCount
        end
      end
    end
  end
  return counts
end

local function collectBank()
  local counts = {}
  -- bank bags -1 (bank), 5..11 (bank bags)
  for bag = -1, NUM_BAG_SLOTS + NUM_BANKBAGSLOTS do
    if bag == -1 or (bag >= NUM_BAG_SLOTS + 1 and bag <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS) then
      local slots = C_Container.GetContainerNumSlots(bag) or 0
      for s = 1, slots do
        local info = C_Container.GetContainerItemInfo(bag, s)
        if info and info.hyperlink and info.stackCount then
          local id, bonus = R.parseItemLink(info.hyperlink)
          if id then
            local key = R.itemKey(id, bonus)
            counts[key] = (counts[key] or 0) + info.stackCount
          end
        end
      end
    end
  end
  -- reagents
  if IsReagentBankUnlocked() then
    local numSlots = 98
    for i = 1, numSlots do
      local info = C_Container.GetContainerItemInfo(REAGENTBANK_CONTAINER, i)
      if info and info.hyperlink and info.stackCount then
        local id, bonus = R.parseItemLink(info.hyperlink)
        if id then
          local key = R.itemKey(id, bonus)
          counts[key] = (counts[key] or 0) + info.stackCount
        end
      end
    end
  end
  return counts
end

local function collectMailbox()
  local counts = {}
  local num = GetInboxNumItems()
  for i = 1, num do
    for a = 1, ATTACHMENTS_MAX_RECEIVE do
      local name, itemID, _, count, quality, canUse, _, _, _, _, _, _, _, _, _, _, itemLink = GetInboxItem(i, a)
      if itemLink and count then
        local id, bonus = R.parseItemLink(itemLink)
        if id then
          local key = R.itemKey(id, bonus)
          counts[key] = (counts[key] or 0) + count
        end
      end
    end
  end
  return counts
end

local function collectGuildBank()
  local counts = {}
  for tab = 1, GetNumGuildBankTabs() or 0 do
    for slot = 1, 98 do
      local itemLink = GetGuildBankItemLink(tab, slot)
      if itemLink then
        local _, count = GetGuildBankItemInfo(tab, slot)
        count = count or 1
        local id, bonus = R.parseItemLink(itemLink)
        if id then
          local key = R.itemKey(id, bonus)
          counts[key] = (counts[key] or 0) + count
        end
      end
    end
  end
  return counts
end

function R.Scan:ScanBags()
  local me = UnitName("player")
  local c = collectBags()
  local out = {}
  for k, v in pairs(c) do out[k] = {bags=v} end
  -- Push in format expected by Data.pushSnapshot
  local ss = R.db.stockSnapshots[me] or { time=R.now() }
  for k, v in pairs(c) do
    ss[k] = ss[k] or {bags=0,bank=0,reagents=0,guild=0,mailbox=0}
    ss[k].bags = v
  end
  ss.time = R.now()
  R.db.stockSnapshots[me] = ss
end

function R.Scan:ScanBank()
  local me = UnitName("player")
  local c = collectBank()
  local ss = R.db.stockSnapshots[me] or { time=R.now() }
  for k, v in pairs(c) do
    ss[k] = ss[k] or {bags=0,bank=0,reagents=0,guild=0,mailbox=0}
    ss[k].bank = v
  end
  ss.time = R.now()
  R.db.stockSnapshots[me] = ss
end

function R.Scan:ScanMailbox()
  local me = UnitName("player")
  local c = collectMailbox()
  local ss = R.db.stockSnapshots[me] or { time=R.now() }
  for k, v in pairs(c) do
    ss[k] = ss[k] or {bags=0,bank=0,reagents=0,guild=0,mailbox=0}
    ss[k].mailbox = v
  end
  ss.time = R.now()
  R.db.stockSnapshots[me] = ss
end

function R.Scan:ScanGuildBank()
  local me = UnitName("player")
  local c = collectGuildBank()
  local ss = R.db.stockSnapshots[me] or { time=R.now() }
  for k, v in pairs(c) do
    ss[k] = ss[k] or {bags=0,bank=0,reagents=0,guild=0,mailbox=0}
    ss[k].guild = v
  end
  ss.time = R.now()
  R.db.stockSnapshots[me] = ss
end

function R.Scan:ScanAllHere()
  self:ScanBags()
  if BankFrame and BankFrame:IsShown() then self:ScanBank() end
  if MailFrame and MailFrame:IsShown() then self:ScanMailbox() end
  if GuildBankFrame and GuildBankFrame:IsShown() then self:ScanGuildBank() end
end