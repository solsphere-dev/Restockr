-- Restockr/Tasks.lua
local ADDON = ...
local R = _G[ADDON]

R.Tasks = R.Tasks or {}
local Tasks = R.Tasks

local function heroCurrentCount(hero, key)
  local ss = R.db.stockSnapshots[hero]
  if not ss or not ss[key] then return 0 end
  local p = ss[key]
  -- Bags only for live hero holdings; mailbox is still on that hero
  return (p.bags or 0) + (p.mailbox or 0)
end

local function warehouseCurrentOnVaults(key)
  local total = 0
  for char, meta in pairs(R.db.characters) do
    if meta.role == "Vault" then
      local ss = R.db.stockSnapshots[char]
      if ss and ss[key] then
        local p = ss[key]
        total = total + (p.bags or 0) + (p.bank or 0) + (p.reagents or 0) + (p.guild or 0)
      end
    end
  end
  return total
end

local function mailboxPendingFor(hero, key)
  local now = R.now()
  local q = 0
  for _, p in ipairs(R.db.pendingDeliveries) do
    if p.to == hero and p.itemKey == key and (p.expiresAt or 0) > now then
      q = q + (p.qty or 0)
    end
  end
  return q
end

-- Compute a task plan
function R.Tasks:Generate()
  local tasks = {}
  local totals = R.accountTotals()

  -- Hero deficits
  for hero, tgt in pairs(R.db.targets) do
    if R.getRole(hero) == "Hero" then
      for key, need in pairs(tgt) do
        local have = heroCurrentCount(hero, key) + mailboxPendingFor(hero, key)
        local deficit = math.max(0, (need or 0) - have)
        if deficit > 0 then
          table.insert(tasks, { type="MailToHero", to=hero, itemKey=key, qty=deficit })
        end
      end
    end
  end

  -- Warehouse top-up
  for key, e in pairs(R.db.items) do
    local want = e.warehouseTarget or 0
    if want > 0 then
      local onVaults = warehouseCurrentOnVaults(key)
      local deficit = math.max(0, want - onVaults)
      if deficit > 0 then
        table.insert(tasks, { type="WarehouseTopUp", itemKey=key, qty=deficit })
      end
    end
  end

  -- Source guidance: can we source from other non-Hero chars?
  local srcGuide = {}
  for _, t in ipairs(tasks) do
    local key = t.itemKey
    local pool = math.max(0, (totals[key] or 0))
    -- Estimate heroes’ current holdings to avoid asking them to mail away
    for hero, tgt in pairs(R.db.targets) do
      if R.getRole(hero) == "Hero" then
        pool = pool - heroCurrentCount(hero, key)
      end
    end
    local fromToons = {}
    if pool >= (t.qty or 0) then
      -- Propose mail from non-Hero chars
      for char, meta in pairs(R.db.characters) do
        if R.getRole(char) ~= "Hero" then
          local ss = R.db.stockSnapshots[char]
          if ss and ss[key] then
            local p = ss[key]
            local avail = (p.bags or 0) + (p.bank or 0) + (p.reagents or 0) + (p.mailbox or 0) + (p.guild or 0)
            if avail > 0 then
              table.insert(fromToons, { char=char, qty=avail })
            end
          end
        end
      end
    end
    t.sources = fromToons
    t.sourceCovers = pool >= (t.qty or 0)
  end

  R.db.tasks = tasks
  R.UI:RefreshTasks()
  R.msg("Restock plan generated.")
end

-- Mark a task as checked → optionally queue delivery
function Tasks:Check(taskIndex)
  local task = R.db.tasks[taskIndex]; if not task then return end
  task.done = true
  if task.type == "MailToHero" then
    table.insert(R.db.pendingDeliveries, {
      to = task.to,
      itemKey = task.itemKey,
      qty = task.qty,
      createdAt = R.now(),
      expiresAt = R.now() + (R.MAIL_LIFETIME or 3*24*60*60),
    })
  end
  R.UI:RefreshTasks()
end

-- Remove a task by index and refresh UI
function Tasks:Remove(taskIndex)
  if not (R.db.tasks and R.db.tasks[taskIndex]) then return end
  table.remove(R.db.tasks, taskIndex)
  R.UI:RefreshTasks()
end

-- Manual override: dismiss without touching pendingDeliveries
function Tasks:Dismiss(taskIndex)
  return self:Remove(taskIndex)
end
