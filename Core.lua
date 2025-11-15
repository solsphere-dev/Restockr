-- Restockr/Core.lua
local ADDON = ...
local R = _G[ADDON] or {}
_G[ADDON] = R

-- SavedVariables root
RestockrDB = RestockrDB or {}

-- Constants
SEC = 1
DAY = 24 * 60 * 60

local BORDER = {
  bgFile   = "Interface/Buttons/WHITE8x8",
  edgeFile = "Interface/Buttons/WHITE8x8",
  edgeSize = 1,
  insets   = { left=1, right=1, top=1, bottom=1 },
}
R.BORDER = BORDER

-- Namespace wiring (filled by other files)
R.Data = R.Data or {}
R.Scan = R.Scan or {}
R.UI = R.UI or {}
R.Mail = R.Mail or {}
R.Tasks = R.Tasks or {}

-- Utils
local function msg(t) DEFAULT_CHAT_FRAME:AddMessage("|cff39c5ffRestockr:|r ".. tostring(t)) end
R.msg = msg

function R.now() return time() end

function R.realmKey()
  local realm = GetRealmName()
  local region = GetCurrentRegionName and GetCurrentRegionName() or "Region"
  return region .. "–" .. realm
end

function R.factionKey()
  return UnitFactionGroup("player") or "Neutral"
end

function R.effectiveScope(db)
  local scope = R.realmKey()
  if not db.settings or db.settings.crossFaction ~= true then
    scope = scope .. "–" .. R.factionKey()
  else
    scope = scope .. "–AllFactions"
  end
  return scope
end

-- Events bootstrap
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BANKFRAME_OPENED")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("GUILDBANKFRAME_OPENED")
f:RegisterEvent("BAG_UPDATE_DELAYED")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    -- Init DB with defaults
    RestockrDB[ADDON] = RestockrDB[ADDON] or {}
    local db = RestockrDB[ADDON]
    db.settings = db.settings or { crossFaction=false, uiScale=1.0 }
    db.characters = db.characters or {}
    db.items = db.items or {}
    db.targets = db.targets or {}
    db.stockSnapshots = db.stockSnapshots or {}
    db.pendingDeliveries = db.pendingDeliveries or {}
    db.tasks = db.tasks or {}
    R.db = db
    -- Register this character if missing
    local me = UnitName("player")
    db.characters[me] = db.characters[me] or { role="None", faction=R.factionKey(), guildName=GetGuildInfo("player") }
    -- Build UI
    R.UI:Init(BORDER)
  elseif event == "PLAYER_LOGIN" then
    C_Timer.After(0.3, function() R.Scan:ScanBags(); R.UI:RefreshAll() end)
  elseif event == "BANKFRAME_OPENED" then
    C_Timer.After(0.1, function() R.Scan:ScanBank(); R.UI:RefreshAll() end)
  elseif event == "MAIL_SHOW" then
    C_Timer.After(0.1, function() R.Scan:ScanMailbox(); R.UI:RefreshAll() end)
  elseif event == "GUILDBANKFRAME_OPENED" then
    C_Timer.After(0.2, function() R.Scan:ScanGuildBank(); R.UI:RefreshAll() end)
  elseif event == "BAG_UPDATE_DELAYED" then
    R.Scan:ScanBags()
  end
end)

-- Slash
SLASH_RESTOCKR1 = "/restockr"
SLASH_RESTOCKR2 = "/rs"
SlashCmdList.RESTOCKR = function(input)
  input = input and input:trim() or ""
  if input == "ui" then R.UI:Toggle() return end
  if input == "scan" then R.Scan:ScanAllHere(); msg("Scanned.") return end
  if input == "restock" then R.Tasks:Generate(); R.UI:ShowTab("Tasks"); return end
  msg("Commands: /rs ui | /rs scan | /rs restock")
end