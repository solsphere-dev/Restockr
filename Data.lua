-- Restockr/Data.lua
local ADDON = ...
local R = _G[ADDON]

-- Item key: respects rank/quality via bonusID or quality
local function itemKey(itemID, qualityOrBonus)
  return tostring(itemID) .. ":" .. tostring(qualityOrBonus or 0)
end
R.itemKey = itemKey

-- Resolve key pieces from a link
function R.parseItemLink(link)
  if not link then return end
  local itemID = tonumber(link:match("item:(%d+)"))
  local quality = select(3, GetItemInfo(link)) -- 0..7 as a hint
  -- Prefer exact bonus stack if available
  local bonus = 0
  local bonusText = link:match("item:%d+:[^|]+")
  if bonusText then
    local ids = {string.match(bonusText, "item:%d+:(%d*):(%d*):(%d*):(%d*):(%d*):(%d*):(%d*)")}
    -- pick one stable bonus slot as rank marker when present (defensive)
    bonus = tonumber(ids and ids[2]) or quality or 0
  end
  return itemID, bonus, quality
end

-- Character role helpers
function R.getRole(char) return (R.db.characters[char] and R.db.characters[char].role) or "None" end
function R.setRole(char, role)
  R.db.characters[char] = R.db.characters[char] or { faction=R.factionKey(), guildName=GetGuildInfo("player") }
  R.db.characters[char].role = role
end

-- Item registry
function R.addItem(link)
  local id, bonus, quality = R.parseItemLink(link)
  if not id then return nil, "Invalid item link" end
  local k = R.itemKey(id, bonus)
  local entry = R.db.items[k] or { itemID=id, qualityHint=quality, variants={[bonus]=true}, warehouseTarget=0 }
  entry.variants[bonus] = true
  R.db.items[k] = entry
  return k
end

-- Targets
function R.setHeroTarget(hero, key, qty)
  R.db.targets[hero] = R.db.targets[hero] or {}
  R.db.targets[hero][key] = math.max(0, tonumber(qty) or 0)
end

function R.setWarehouseTarget(key, qty)
  local e = R.db.items[key]; if not e then return end
  e.warehouseTarget = math.max(0, tonumber(qty) or 0)
end

-- Snapshots and totals
local function zeroT() return {bags=0,bank=0,reagents=0,guild=0,mailbox=0} end

function R.pushSnapshot(char, part, counts)
  local ss = R.db.stockSnapshots[char] or { time=R.now(), bags=0,bank=0,reagents=0,guild=0,mailbox=0 }
  for key, qty in pairs(counts) do
    ss[part] = ss[part] or 0 -- keep field existence
  end
  R.db.stockSnapshots[char] = ss
  ss.time = R.now()
  for k, v in pairs(counts) do
    ss[k] = ss[k] or zeroT()
    ss[k][part] = v
  end
end

-- Aggregate across account scope
function R.accountTotals()
  local totals = {}
  local scopeFaction = R.factionKey()
  local scopeRealm = R.realmKey()
  local cross = R.db.settings.crossFaction == true

  for char, meta in pairs(R.db.characters) do
    if meta then
      if cross or meta.faction == scopeFaction then
        local ss = R.db.stockSnapshots[char]
        if ss then
          for itemKey, parts in pairs(ss) do
            if type(parts) == "table" and parts.bags then
              totals[itemKey] = (totals[itemKey] or 0) + (parts.bags or 0) + (parts.bank or 0) + (parts.reagents or 0) + (parts.guild or 0) + (parts.mailbox or 0)
            end
          end
        end
      end
    end
  end

  -- Subtract pending deliveries to avoid double mailing
  local now = R.now()
  for _, p in ipairs(R.db.pendingDeliveries) do
    if (p.expiresAt or 0) > now then
      totals[p.itemKey] = math.max(0, (totals[p.itemKey] or 0) - (p.qty or 0))
    end
  end
  return totals
end

-- === Hero/Vault listing & removal (appended) ===
function R.listHeroes()
  local out = {}
  if not R.db or not R.db.characters then return out end
  for name, meta in pairs(R.db.characters) do
    if meta and meta.role == "Hero" then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

function R.listVaults()
  local out = {}
  if not R.db or not R.db.characters then return out end
  for name, meta in pairs(R.db.characters) do
    if meta and meta.role == "Vault" then table.insert(out, name) end
  end
  table.sort(out)
  return out
end

function R.removeHero(name)
  if not name or not R.db or not R.db.characters or not R.db.characters[name] then return end
  R.db.characters[name].role = "None"
  if R.db.targets then R.db.targets[name] = nil end -- wipe hero targets
  if R.UI and R.UI.RefreshHeroes then R.UI:RefreshHeroes() end
  R.msg(("Removed Hero: %s"):format(name))
end

function R.removeVault(name)
  if not name or not R.db or not R.db.characters or not R.db.characters[name] then return end
  R.db.characters[name].role = "None"
  if R.UI and R.UI.RefreshVaults then R.UI:RefreshVaults() end
  R.msg(("Removed Vault: %s"):format(name))
end
