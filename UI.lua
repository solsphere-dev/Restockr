-- Restockr/UI.lua
local ADDON = ...
local R = _G[ADDON]

local UI = { tabs = {}, currentTab = "Items" }
R.UI = UI

local function SolidFrame(name, parent, BORDER)
  local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
  f:SetBackdrop(BORDER)
  f:SetBackdropColor(0.08,0.09,0.11,0.95) -- solid dark
  f:SetBackdropBorderColor(0.20,0.22,0.25,1) -- crisp border
  return f
end

function UI:Init(BORDER)
  if self.root then return end
  local root = SolidFrame("RestockrRoot", UIParent, BORDER)
  root:SetSize(740, 480)
  root:SetPoint("CENTER")
  root:EnableMouse(true)
  root:SetMovable(true)
  root:RegisterForDrag("LeftButton")
  root:SetScript("OnDragStart", function(s) s:StartMoving() end)
  root:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  root:Hide()

  local title = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText("Restockr")

  local btnClose = CreateFrame("Button", nil, root, "UIPanelCloseButton")
  btnClose:SetPoint("TOPRIGHT", 0, 0)

  local btnRestock = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
  btnRestock:SetPoint("TOPRIGHT", -36, -12)
  btnRestock:SetSize(100, 24)
  btnRestock:SetText("Restock")
  btnRestock:SetScript("OnClick", function()
    R.Tasks:Generate()
    UI:ShowTab("Tasks")
  end)

  -- Tab strip
  local tabNames = {"Items","Heroes","Vaults","Tasks","Settings"}
  local last
  for _, name in ipairs(tabNames) do
    local b = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    b:SetSize(90, 22)
    b:SetText(name)
    if not last then b:SetPoint("TOPLEFT", 12, -44) else b:SetPoint("LEFT", last, "RIGHT", 6, 0) end
    b:SetScript("OnClick", function() UI:ShowTab(name) end)
    last = b
  end

  -- Content pane
  local pane = SolidFrame(nil, root, BORDER)
  pane:SetPoint("TOPLEFT", 12, -74)
  pane:SetPoint("BOTTOMRIGHT", -12, 12)

  -- Items tab
  local items = CreateFrame("Frame", nil, pane)
  items:SetAllPoints()
  items:Hide()
  self.tabs["Items"] = items

  local lblAdd = items:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lblAdd:SetPoint("TOPLEFT", 12, -12)
  lblAdd:SetText("Drop an item link here or paste, then Set Warehouse & Hero targets.")

  local edit = CreateFrame("EditBox", nil, items, "InputBoxTemplate")
  edit:SetSize(420, 22); edit:SetPoint("TOPLEFT", 12, -36); edit:SetAutoFocus(false)
  local btnAdd = CreateFrame("Button", nil, items, "UIPanelButtonTemplate")
  btnAdd:SetSize(120, 22); btnAdd:SetPoint("LEFT", edit, "RIGHT", 6, 0); btnAdd:SetText("Add Item")

  btnAdd:SetScript("OnClick", function()
    local text = edit:GetText()
    if not text or text == "" then R.msg("Paste an item link."); return end
    local key, err
    key, err = R.addItem(text)
    if not key then R.msg(err) return end
    R.msg("Added: ".. key)
    UI:RefreshItems()
  end)

  edit:SetScript("OnEnterPressed", function() btnAdd:Click() end)

  -- Drop target area
  local drop = SolidFrame(nil, items, {bgFile="Interface/Buttons/WHITE8x8", edgeFile="Interface/Buttons/WHITE8x8", edgeSize=1, insets={left=1,right=1,top=1,bottom=1}})
  drop:SetBackdropColor(0.10,0.11,0.13,0.6); drop:SetBackdropBorderColor(0.35,0.35,0.4,1)
  drop:SetPoint("TOPLEFT", 12, -70); drop:SetPoint("RIGHT", -12, 0); drop:SetHeight(120)

  local dropText = items:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dropText:SetPoint("CENTER", drop, "CENTER")
  dropText:SetText("Drag item from bags here")

  drop:EnableMouse(true)
  drop:SetScript("OnMouseUp", function()
    local cursorType, itemID = GetCursorInfo()
    if cursorType == "item" then
      local link = select(2, GetItemInfo(itemID))
      if link then
        edit:SetText(link)
        ClearCursor()
      end
    end
  end)

  -- Item list
  local scroll = CreateFrame("ScrollFrame", nil, items, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -200); scroll:SetPoint("BOTTOMRIGHT", -12, 12)
  local list = CreateFrame("Frame"); list:SetSize(1,1)
  scroll:SetScrollChild(list)
  items.list = list

  -- Heroes tab
  local heroes = CreateFrame("Frame", nil, pane); heroes:SetAllPoints(); heroes:Hide()
  self.tabs["Heroes"] = heroes
  local roleBtn = CreateFrame("Button", nil, heroes, "UIPanelButtonTemplate")
  roleBtn:SetSize(160,22); roleBtn:SetPoint("TOPLEFT", 12, -12); roleBtn:SetText("Set Me As Hero")
  roleBtn:SetScript("OnClick", function()
    R.setRole(UnitName("player"), "Hero"); R.msg("This character is a Hero.")
    UI:RefreshAll()
  end)

  -- Heroes list
  local heroesScroll = CreateFrame("ScrollFrame", nil, heroes, "UIPanelScrollFrameTemplate")
  heroesScroll:SetPoint("TOPLEFT", 12, -44)
  heroesScroll:SetPoint("BOTTOMRIGHT", -12, 12)
  local heroesList = CreateFrame("Frame"); heroesList:SetSize(1,1)
  heroesScroll:SetScrollChild(heroesList)
  self.heroesList = heroesList

  -- Vaults tab
  local vaults = CreateFrame("Frame", nil, pane); vaults:SetAllPoints(); vaults:Hide()
  self.tabs["Vaults"] = vaults
  local vaultBtn = CreateFrame("Button", nil, vaults, "UIPanelButtonTemplate")
  vaultBtn:SetSize(170,22); vaultBtn:SetPoint("TOPLEFT", 12, -12); vaultBtn:SetText("Set Me As Vault")
  vaultBtn:SetScript("OnClick", function()
    R.setRole(UnitName("player"), "Vault"); R.msg("This character is a Vault.")
    UI:RefreshAll()
  end)

  -- Vaults list
  local vaultsScroll = CreateFrame("ScrollFrame", nil, vaults, "UIPanelScrollFrameTemplate")
  vaultsScroll:SetPoint("TOPLEFT", 12, -44)
  vaultsScroll:SetPoint("BOTTOMRIGHT", -12, 12)
  local vaultsList = CreateFrame("Frame"); vaultsList:SetSize(1,1)
  vaultsScroll:SetScrollChild(vaultsList)
  self.vaultsList = vaultsList

  -- Tasks tab
  local tasks = CreateFrame("Frame", nil, pane); tasks:SetAllPoints(); tasks:Hide()
  self.tabs["Tasks"] = tasks

  local taskScroll = CreateFrame("ScrollFrame", nil, tasks, "UIPanelScrollFrameTemplate")
  taskScroll:SetPoint("TOPLEFT", 12, -12); taskScroll:SetPoint("BOTTOMRIGHT", -12, 12)
  local taskList = CreateFrame("Frame"); taskList:SetSize(1,1)
  taskScroll:SetScrollChild(taskList)
  tasks.list = taskList

  -- Settings tab
  local settings = CreateFrame("Frame", nil, pane); settings:SetAllPoints(); settings:Hide()
  self.tabs["Settings"] = settings

  local cbFaction = CreateFrame("CheckButton", nil, settings, "InterfaceOptionsCheckButtonTemplate")
  cbFaction:SetPoint("TOPLEFT", 12, -12)
  cbFaction.Text:SetText("Merge factions in one pool")
  cbFaction:SetScript("OnClick", function(s) R.db.settings.crossFaction = s:GetChecked() and true or false end)
  settings.cbFaction = cbFaction

  self.root, self.itemsList, self.taskList = root, list, taskList
  function UI:RefreshAll()
    UI:RefreshItems()
    UI:RefreshTasks()
    UI:RefreshHeroes()
    UI:RefreshVaults()
    settings.cbFaction:SetChecked(R.db.settings.crossFaction == true)
  end

  UI:ShowTab("Items")
end

function UI:Toggle() if self.root:IsShown() then self.root:Hide() else self.root:Show() end end
function UI:ShowTab(name)
  for k, frame in pairs(self.tabs) do frame:SetShown(k == name) end
  self.currentTab = name
  if name == "Heroes" then self:RefreshHeroes()
  elseif name == "Vaults" then self:RefreshVaults()
  elseif name == "Items" then self:RefreshItems()
  elseif name == "Tasks" then self:RefreshTasks()
  end
  self.root:Show()
end


-- Render Items list with warehouse+hero targets inline
function UI:RefreshItems()
  if not self.itemsList then return end
  local parent = self.itemsList
  for i, child in ipairs({parent:GetChildren()}) do child:Hide(); child:SetParent(nil) end

  local y = -2
  for key, e in pairs(R.db.items) do
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetSize(680, 26)

    local itemID = e.itemID
    local name, link, _, quality, _, _, _, stackSize, _, icon = GetItemInfo(itemID)
    icon = icon or 134400

    local tex = row:CreateTexture(nil, "ARTWORK"); tex:SetSize(20,20); tex:SetPoint("LEFT", 6, 0); tex:SetTexture(icon)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", tex, "RIGHT", 6, 0)
    fs:SetWidth(240); fs:SetJustifyH("LEFT")
    fs:SetText(link or ("item:"..itemID))

    -- Warehouse target
    local wEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    wEdit:SetSize(60,22); wEdit:SetPoint("LEFT", fs, "RIGHT", 8, 0); wEdit:SetAutoFocus(false)
    wEdit:SetText(tostring(e.warehouseTarget or 0))
    local wSet = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    wSet:SetSize(60,22); wSet:SetPoint("LEFT", wEdit, "RIGHT", 4, 0); wSet:SetText("Store")
    wSet:SetScript("OnClick", function()
      R.setWarehouseTarget(key, tonumber(wEdit:GetText()) or 0)
      R.msg("Warehouse target set.")
    end)

    -- Per-Hero target editor for current char if Hero
    local me = UnitName("player")
    if R.getRole(me) == "Hero" then
      local hEdit = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
      hEdit:SetSize(60,22); hEdit:SetPoint("LEFT", wSet, "RIGHT", 12, 0); hEdit:SetAutoFocus(false)
      hEdit:SetText(tostring((R.db.targets[me] and R.db.targets[me][key]) or 0))
      local hSet = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      hSet:SetSize(60,22); hSet:SetPoint("LEFT", hEdit, "RIGHT", 4, 0); hSet:SetText("Hero")
      hSet:SetScript("OnClick", function()
        R.setHeroTarget(me, key, tonumber(hEdit:GetText()) or 0)
        R.msg("Hero target set.")
      end)
    end

    y = y - 28
  end
  parent:SetSize(680, math.abs(y)+30)
end

function UI:RefreshTasks()
  if not self.taskList then return end
  local parent = self.taskList
  for i, child in ipairs({parent:GetChildren()}) do child:Hide(); child:SetParent(nil) end

  local y = -2
  for i, t in ipairs(R.db.tasks or {}) do
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetSize(680, 26)

    local cb = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("LEFT", 6, 0)
    cb:SetScript("OnClick", function(s)
      R.Tasks:Dismiss(i)
    end)
    cb:SetChecked(t.done == true)

    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    local label = ""
    if t.type == "MailToHero" then
      local itemID = tonumber((t.itemKey:match("^(%d+):")))
      local link = select(2, GetItemInfo(itemID)) or ("item:"..itemID)
      label = ("Mail %dx %s → %s"):format(t.qty, link, t.to)
    elseif t.type == "WarehouseTopUp" then
      local itemID = tonumber((t.itemKey:match("^(%d+):")))
      local link = select(2, GetItemInfo(itemID)) or ("item:"..itemID)
      label = ("Buy/Acquire %dx %s → Warehouse"):format(t.qty, link)
    else
      label = "Task"
    end
    fs:SetText(label)

    -- Guidance
    if t.sources and #t.sources > 0 then
      local hint = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      hint:SetPoint("LEFT", fs, "RIGHT", 8, 0)
      if t.sourceCovers then
        hint:SetText("|cff7fff7fCan source from alts. Log and mail to Vault.|r")
      else
        hint:SetText("|cffff7f7fNeed AH buy for remainder.|r")
      end
    end

    -- If on Vault, quick-send button
    if R.getRole(UnitName("player")) == "Vault" and t.type == "MailToHero" and not t.done then
      local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      b:SetSize(80, 22); b:SetPoint("RIGHT", -6, 0); b:SetText("Send")
      b:SetScript("OnClick", function()
        local sent = R.Mail:SendNow(t.to, t.itemKey, t.qty)
        if (sent or 0) > 0 then
          R.Tasks:Remove(i)
        end
      end)
    end

    y = y - 28
  end
  parent:SetSize(680, math.abs(y)+30)
end


-- helper: clear all child frames
local function ClearChildren(parent)
  local children = { parent:GetChildren() }
  for _, child in ipairs(children) do
    child:Hide()
    child:SetParent(nil)
  end
end

function UI:RefreshHeroes()
  if not self.heroesList then return end
  local parent = self.heroesList
  ClearChildren(parent)
  local y = -2
  for _, name in ipairs(R.listHeroes()) do
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetSize(680, 24)

    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetText(name)

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(80, 20)
    remove:SetPoint("RIGHT", -6, 0)
    remove:SetText("Remove")
    remove:SetScript("OnClick", function() R.removeHero(name) end)

    y = y - 26
  end
  parent:SetSize(680, math.abs(y) + 30)
end

function UI:RefreshVaults()
  if not self.vaultsList then return end
  local parent = self.vaultsList
  ClearChildren(parent)
  local y = -2
  for _, name in ipairs(R.listVaults()) do
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 0, y)
    row:SetSize(680, 24)

    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", 6, 0)
    fs:SetText(name)

    local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    remove:SetSize(80, 20)
    remove:SetPoint("RIGHT", -6, 0)
    remove:SetText("Remove")
    remove:SetScript("OnClick", function() R.removeVault(name) end)

    y = y - 26
  end
  parent:SetSize(680, math.abs(y) + 30)
end