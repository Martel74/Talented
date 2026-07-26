local BUTTON_GAP = 6
local FRAME_PADDING = 10
local HEADER_HEIGHT = 28 -- top row holding the "Talented" label and the lock button
local LOCK_BUTTON_SIZE = 24
local MAX_SPECS = 4 -- Druids currently have the most specializations (4)

local ICON_SIZES = {
	{ key = "small", label = "Small", size = 24 },
	{ key = "medium", label = "Medium", size = 32 },
	{ key = "large", label = "Large", size = 40 },
}

local frame
local buttons = {}
local lockButton
local sizeDropdown

local function Talented_GetIconSize()
	for _, opt in ipairs(ICON_SIZES) do
		if opt.key == Talented_DB.iconSize then
			return opt.size
		end
	end
	return 32
end

local function Talented_GetSizeLabel(key)
	for _, opt in ipairs(ICON_SIZES) do
		if opt.key == key then
			return opt.label
		end
	end
	return "Medium"
end

-- Wrapped instead of called directly: Blizzard has been migrating these from bare
-- globals to the C_SpecializationInfo namespace piecemeal (GetSpecialization and
-- GetSpecializationInfo made the move, but the no-arg GetNumSpecializations hasn't
-- as of 12.0.7 -- only GetNumSpecializationsForClassID exists under the namespace),
-- so probing for whichever form exists avoids hardcoding a guess that might be wrong.
local function Talented_GetNumSpecs()
	local fn = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations
	if fn then
		return fn()
	end
	return GetNumSpecializations and GetNumSpecializations() or 0
end

local function Talented_GetActiveSpec()
	local fn = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
	if fn then
		return fn()
	end
	return GetSpecialization and GetSpecialization() or nil
end

local function Talented_GetSpecInfo(index)
	local fn = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
	if fn then
		return fn(index)
	end
	return GetSpecializationInfo(index)
end

local function Talented_SetSpec(index)
	local fn = C_SpecializationInfo and C_SpecializationInfo.SetSpecialization
	if fn then
		return fn(index)
	end
	return SetSpecialization(index)
end

local function Talented_GetDefaultDB()
	return {
		point = "CENTER",
		relPoint = "CENTER",
		x = 0,
		y = 200,
		locked = false,
		scale = 1,
		iconSize = "medium",
	}
end

local function Talented_ApplyPosition()
	frame:ClearAllPoints()
	frame:SetPoint(Talented_DB.point, UIParent, Talented_DB.relPoint, Talented_DB.x, Talented_DB.y)
end

local function Talented_ApplyLock()
	if Talented_DB.locked then
		frame:RegisterForDrag()
		lockButton.icon:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
	else
		frame:RegisterForDrag("LeftButton")
		lockButton.icon:SetTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
	end
end

local function Talented_Button_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(self.specName, 1, 1, 1)
	if self.specRole and _G[self.specRole] then
		GameTooltip:AddLine(_G[self.specRole], 0.7, 0.7, 0.7)
	end
	if self.specIndex == Talented_GetActiveSpec() then
		GameTooltip:AddLine(CURRENT or "Current specialization", 0.1, 1, 0.1)
	end
	GameTooltip:Show()
end

local function Talented_Button_OnLeave()
	GameTooltip:Hide()
end

local function Talented_Button_OnClick(self)
	if InCombatLockdown() then
		UIErrorsFrame:AddMessage(SPELL_FAILED_AFFECTING_COMBAT or "Can't change specialization in combat.", 1.0, 0.1, 0.1, 1.0)
		return
	end
	if self.specIndex == Talented_GetActiveSpec() then
		return
	end
	Talented_SetSpec(self.specIndex)
end

local function Talented_CreateButton(index)
	local button = CreateFrame("Button", "TalentedButton"..index, frame)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the default icon border art

	-- Same marching-ants ring the pet action bar uses for an active/autocast ability
	-- (AutoCastOverlayTemplate, Blizzard_UIPanelTemplates); ShowAutoCastEnabled(true)
	-- both shows and spins it, ShowAutoCastEnabled(false) hides it again.
	button.Shine = CreateFrame("Frame", nil, button, "AutoCastOverlayTemplate")
	button.Shine:SetPoint("CENTER", button, "CENTER")
	button.Shine:Show()

	local highlight = button:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")

	button:SetScript("OnEnter", Talented_Button_OnEnter)
	button:SetScript("OnLeave", Talented_Button_OnLeave)
	button:SetScript("OnClick", Talented_Button_OnClick)

	return button
end

local function Talented_UpdateButtons()
	local numSpecs = Talented_GetNumSpecs() or 0
	local currentSpec = Talented_GetActiveSpec()
	local size = Talented_GetIconSize()

	frame:Show()

	for i = 1, MAX_SPECS do
		local button = buttons[i]
		if i <= numSpecs then
			local specID, name, description, icon, role = Talented_GetSpecInfo(i)
			button.icon:SetTexture(icon)
			button.specIndex = i
			button.specName = name
			button.specRole = role
			button:ClearAllPoints()
			if i == 1 then
				button:SetPoint("TOPLEFT", frame, "TOPLEFT", FRAME_PADDING, -HEADER_HEIGHT)
			else
				button:SetPoint("LEFT", buttons[i - 1], "RIGHT", BUTTON_GAP, 0)
			end
			button.Shine:ShowAutoCastEnabled(i == currentSpec)
			button:Show()
		else
			button:Hide()
		end
	end

	local shown = numSpecs > 0 and numSpecs or 1
	local width = FRAME_PADDING * 2 + shown * size + (shown - 1) * BUTTON_GAP
	frame:SetSize(width, HEADER_HEIGHT + size + FRAME_PADDING)
end

local function Talented_ApplyIconSize()
	local size = Talented_GetIconSize()
	for i = 1, MAX_SPECS do
		buttons[i]:SetSize(size, size)
		buttons[i].Shine:SetSize(size + 8, size + 8)
	end
	Talented_UpdateButtons()
end

local function Talented_SetButtonsEnabled(enabled)
	for i = 1, MAX_SPECS do
		local button = buttons[i]
		button.icon:SetDesaturated(not enabled)
		button.icon:SetAlpha(enabled and 1 or 0.5)
	end
end

local function Talented_CreateFrame()
	frame = CreateFrame("Frame", "TalentedFrame", UIParent, "BackdropTemplate")
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.6)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetScript("OnDragStart", function(self)
		if not Talented_DB.locked then
			self:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		Talented_DB.point, _, Talented_DB.relPoint, Talented_DB.x, Talented_DB.y = self:GetPoint()
	end)

	for i = 1, MAX_SPECS do
		buttons[i] = Talented_CreateButton(i)
	end

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	title:SetPoint("LEFT", frame, "TOPLEFT", FRAME_PADDING, -(HEADER_HEIGHT / 2))
	title:SetJustifyH("LEFT")
	title:SetText("Talented")

	lockButton = CreateFrame("Button", "TalentedLockButton", frame)
	lockButton:SetSize(LOCK_BUTTON_SIZE, LOCK_BUTTON_SIZE)
	lockButton:SetPoint("RIGHT", frame, "TOPRIGHT", -6, -(HEADER_HEIGHT / 2))
	lockButton:SetFrameLevel(frame:GetFrameLevel() + 5)
	lockButton.icon = lockButton:CreateTexture(nil, "ARTWORK")
	lockButton.icon:SetAllPoints()
	lockButton:SetScript("OnClick", function()
		Talented_DB.locked = not Talented_DB.locked
		Talented_ApplyLock()
	end)
	lockButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(Talented_DB.locked and "Click to unlock and move" or "Click to lock in place", 1, 1, 1)
		GameTooltip:Show()
	end)
	lockButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function Talented_CreateOptionsPanel()
	local panel = CreateFrame("Frame")
	panel.name = "Talented"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Talented")

	local sizeLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sizeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -24)
	sizeLabel:SetText("Icon size")

	-- Same dropdown style/pattern as BankItems' Menu-API dropdowns: build the widget
	-- and set its data-dependent SetupMenu callback only after Talented_DB exists
	-- (this function only ever runs from Talented_Initialize, post-PLAYER_LOGIN),
	-- since SetupMenu evaluates its radio callbacks immediately, not lazily on open.
	sizeDropdown = CreateFrame("DropdownButton", "TalentedSizeDropdown", panel, "WowStyle1DropdownTemplate")
	sizeDropdown:SetSize(150, 25)
	sizeDropdown:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -8)
	sizeDropdown:SetupMenu(function(dropdown, rootDescription)
		for _, opt in ipairs(ICON_SIZES) do
			rootDescription:CreateRadio(opt.label,
				function(key) return Talented_DB.iconSize == key end,
				function(key)
					Talented_DB.iconSize = key
					sizeDropdown:OverrideText(Talented_GetSizeLabel(key))
					Talented_ApplyIconSize()
				end,
				opt.key)
		end
	end)
	sizeDropdown:OverrideText(Talented_GetSizeLabel(Talented_DB.iconSize))

	local category = Settings.RegisterCanvasLayoutCategory(panel, "Talented")
	Settings.RegisterAddOnCategory(category)
end

local function Talented_Initialize()
	local defaults = Talented_GetDefaultDB()
	for key, value in pairs(defaults) do
		if Talented_DB[key] == nil then
			Talented_DB[key] = value
		end
	end

	Talented_CreateFrame()
	Talented_CreateOptionsPanel()
	Talented_ApplyPosition()
	Talented_ApplyLock()
	frame:SetScale(Talented_DB.scale)
	Talented_ApplyIconSize()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		Talented_DB = Talented_DB or {}
		Talented_Initialize()
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
		-- PLAYER_ENTERING_WORLD fires on every login/reload/zone after spec data
		-- is guaranteed to be synced, unlike PLAYER_LOGIN which can beat the server to it
		Talented_UpdateButtons()
	elseif event == "PLAYER_REGEN_DISABLED" then
		Talented_SetButtonsEnabled(false)
	elseif event == "PLAYER_REGEN_ENABLED" then
		Talented_SetButtonsEnabled(true)
	end
end)

SLASH_TALENTED1 = "/talented"
SlashCmdList.TALENTED = function(msg)
	msg = strtrim(strlower(msg or ""))
	if msg == "lock" then
		Talented_DB.locked = true
		Talented_ApplyLock()
		print("|cff33ff99Talented|r: frame locked.")
	elseif msg == "unlock" then
		Talented_DB.locked = false
		Talented_ApplyLock()
		print("|cff33ff99Talented|r: frame unlocked - drag to move.")
	elseif msg == "reset" then
		local defaults = Talented_GetDefaultDB()
		Talented_DB.point, Talented_DB.relPoint, Talented_DB.x, Talented_DB.y = defaults.point, defaults.relPoint, defaults.x, defaults.y
		Talented_DB.scale = defaults.scale
		frame:SetScale(Talented_DB.scale)
		Talented_ApplyPosition()
		print("|cff33ff99Talented|r: position reset.")
	elseif msg == "size small" or msg == "size medium" or msg == "size large" then
		local key = msg:match("size (%a+)")
		Talented_DB.iconSize = key
		if sizeDropdown then
			sizeDropdown:OverrideText(Talented_GetSizeLabel(key))
		end
		Talented_ApplyIconSize()
		print("|cff33ff99Talented|r: icon size set to "..Talented_GetSizeLabel(key)..".")
	elseif msg == "debug" then
		local numSpecs = Talented_GetNumSpecs() or 0
		local currentSpec = Talented_GetActiveSpec()
		print(string.format("|cff33ff99Talented|r: numSpecs=%d currentSpec=%s frame shown=%s point=%s,%s,%.0f,%.0f",
			numSpecs, tostring(currentSpec), tostring(frame and frame:IsShown()),
			tostring(Talented_DB.point), tostring(Talented_DB.relPoint), Talented_DB.x or 0, Talented_DB.y or 0))
	else
		print("|cff33ff99Talented|r commands: /talented lock, /talented unlock, /talented reset, /talented size small|medium|large, /talented debug")
	end
end
