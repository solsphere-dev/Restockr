-- Restockr/Mail.lua
local ADDON = ...
local R = _G[ADDON]

R.Mail = R.Mail or {}
local Mail = R.Mail

local throttle = 0
local function canSend() return (GetTime() - throttle) > 0.6 end

-- Slice quantity into attachment-sized chunks
local function sliceStacks(total, maxStack)
  local t = {}
  while total > 0 do
    local n = math.min(total, maxStack)
    table.insert(t, n)
    total = total - n
  end
  return t
end

-- Find all stacks matching itemKey in bags
local function findStacks(itemKey)
  local found = {}
  local idStr, bonusStr = itemKey:match("^(%d+):(%d+)")
  for bag = 0, NUM_BAG_SLOTS do
    local slots = C_Container.GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.hyperlink and info.stackCount and info.stackCount > 0 then
        local iid, b = R.parseItemLink(info.hyperlink)
        if iid and tostring(iid) == idStr and tostring(b or 0) == bonusStr then
          table.insert(found, { bag = bag, slot = slot, count = info.stackCount })
        end
      end
    end
  end
  return found
end

-- Pick up exactly `take` items from the stack at bag/slot.
-- Why: Mail attachments consume whatever is on cursor; split when partial.
local function pickupExact(bag, slot, have, take)
  if take >= have then
    C_Container.PickupContainerItem(bag, slot)
    return take
  else
    C_Container.SplitContainerItem(bag, slot, take)
    return take
  end
end

function R.Mail:SendNow(to, itemKey, qty)
  if not InboxFrame or not SendMailFrame or not MailFrame or not MailFrame:IsShown() then
    R.msg("Open your mailbox first.")
    return
  end

  local itemID = tonumber(itemKey:match("^(%d+):"))
  local name, link, _, _, _, _, _, stackSize = GetItemInfo(itemID)
  stackSize = stackSize or 1000

  local slices = sliceStacks(qty, stackSize)
  local stacks = findStacks(itemKey)
  if #stacks == 0 then
    R.msg("No matching stacks found for ".. (link or ("item:"..itemID)))
    return
  end

  local sent = 0
  for _, want in ipairs(slices) do
    ClearSendMail() -- clears subject/body/attachments
    local remaining = want

    -- fill attachments with exact amounts
    for i = #stacks, 1, -1 do
      if remaining <= 0 then break end
      local st = stacks[i]
      if st.count > 0 then
        local take = math.min(st.count, remaining)
        pickupExact(st.bag, st.slot, st.count, take)
        ClickSendMailItemButton()
        st.count = st.count - take
        remaining = remaining - take
      end
    end

    if remaining > 0 then
      R.msg(("Insufficient items to complete %d more for %s."):format(remaining, to))
      break
    end

    -- IMPORTANT: pass recipient to SendMail; there is no SetSendMailName API
    local subject = "Restockr delivery"
    local body = ""
    if canSend() then
      SendMail(to, subject, body)
      throttle = GetTime()
    else
      C_Timer.After(0.7, function() SendMail(to, subject, body) end)
    end
    sent = sent + want
  end

  if sent > 0 then
    table.insert(R.db.pendingDeliveries, {
      to = to, itemKey = itemKey, qty = sent,
      createdAt = R.now(), expiresAt = R.now() + (R.MAIL_LIFETIME or 3*24*60*60),
    })
    R.msg(("Queued %dx %s to %s"):format(sent, link or itemID, to))
    return sent               -- <-- add this
  else
    return 0                  -- <-- and this fallback
  end
end