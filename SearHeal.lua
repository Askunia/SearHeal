SH = CreateFrame("Frame", "SearingPlasmaHealDisplay", UIParent)
SH.barFrames = {}
SH:RegisterEvent("ADDON_LOADED")
SH:SetScript("OnEvent", function(self,event, ...) SH[event](...) end)

function SH.ADDON_LOADED(...)
	if (SPHD_DB == nil) then
		SPHD_DB = {}
		-- Set Defaults
		SPHD_DB.width = 100
		SPHD_DB.height = 20
		SPHD_DB.yOffSet = 0
		SPHD_DB.xOffSet = 0
	end 
	SLASH_SPHD1 = "/sphd"
	SlashCmdList["SPHD"] = function(message)
		SH.Command(message);
	end
	SH.CreateAnchorFrame()
end

function SH.CreateAnchorFrame()
	local anchorFrame = CreateFrame("Frame", "SPHDAnchorFrame", UIParent)
	anchorFrame:SetWidth(SPHD_DB.width)
	anchorFrame:SetHeight(SPHD_DB.height)
	anchorFrame:SetPoint("CENTER",UIParent,"CENTER",SPHD_DB.xOffSet,SPHD_DB.yOffSet)
	anchorFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	anchorFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	anchorFrame:SetScript("OnEvent", function(self, event, ...)	SH[event](...) end)
	anchorFrame:Hide()
	SH.anchorFrame = anchorFrame
end

function SH.Command(message)
	if strfind(message, "lock" ) then
		-- Show or Hide the AnchorFrame
		if SH.anchorFrame:IsVisible() then
			SH.anchorFrame:Hide()
		else
			SH.anchorFrame:Show()
			SH.MoveAndSize(SH.anchorFrame)
		end
	end
end

function SH.MoveAndSize(anchorFrame)
	anchorFrame:SetMovable(true)
	anchorFrame:EnableMouse(true)
	anchorFrame:SetResizable(true)
	anchorFrame:RegisterForDrag("LeftButton")
	anchorFrame:SetScript("OnDragStart", function(this)
		anchorFrame.oldxOffset = this:GetLeft()
		anchorFrame.oldyOffset = this:GetTop()
		this:StartMoving()
	end)
	anchorFrame:SetScript("OnDragStop", function(this)
		this:StopMovingOrSizing()
		SPHD_DB.yOffset = SPHD_DB.yOffset + this:GetTop() - anchorFrame.oldyOffset
		SPHD_DB.xOffset = SPHD_DB.xOffset + this:GetLeft() - anchorFrame.oldxOffset
	end)
	anchorFrame.Grip = CreateFrame("Button", "SPHDResize", anchorFrame)
	anchorFrame.Grip:SetNormalTexture("Interface\\AddOns\\SearHeal\\ResizeGrip")
	anchorFrame.Grip:SetHighlightTexture("Interface\\AddOns\\SearHeal\\ResizeGrip")
	anchorFrame.Grip:SetWidth(16)
	anchorFrame.Grip:SetHeight(16)
	anchorFrame.Grip:EnableMouse(true)
	anchorFrame.Grip:SetPoint("BOTTOMRIGHT", anchorFrame, 1, 1)
	anchorFrame.Grip:SetScript("OnMouseDown", function(this)
		anchorFrame:StartSizing("BOTTOMRIGHT")
	end)
			
	anchorFrame.Grip:SetScript("OnMouseUp", function(this)
		anchorFrame:SetScript("OnSizeChanged", nil)
		anchorFrame:StopMovingOrSizing()
		SPHD_DB.height = anchorFrame:GetHeight()
		SPHD_DB.width = anchorFrame:GetWidth()
	end)
end
		
function SH.PLAYER_REGEN_DISABLED(...)
	SH:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	SH.anchorFrame:SetScript("OnUpdate", function(self, elapsed)
		SH.UpdBarFrames(SH.anchorFrame, elapsed);
		end);
end

function SH.PLAYER_REGEN_ENABLED(...)
	SH:UnRegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	SH.anchorFrame:SetScript("OnUpdate", nil )
	for index, barFrame in pairs(SH.barFrames) do
		barFrame:Hide()
		barFrame.healed = 0
		barFrame.needed = 0
	end
end

function SH.COMBAT_LOG_EVENT_UNFILTERED(timestamp, event, hideCaster, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	-- Check if someone got the debuff or lost it !
	if event == "SPELL_AURA_APPLIED" then
		local spellId, spellName, spellSchool = select(1, ...)
		if spellId == 109362 or spellId == 109363 or spellId == 109364 then
			-- Debuff on a player, so fire up a bar for him
			SH.CreateHealingBar(dstName,spellId)
			SH[dstName] = {}
			SH[dstName].debuff = true
		end
	elseif event == "SPELL_AURA_REMOVED" then
		local spellId, spellName, spellSchool = select(1, ...)
		if spellId == 109362 or spellId == 109363 or spellId == 109365 then
			-- Debuff removed, so remove his bar!
			SH[dstName].debuff = false
			SH.barFrames[dstName]:Hide()
			SH.UpdateFramePositions()
		end
	elseif event == "SPELL_HEAL" then
		local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(1, ... )
		-- Check if someone healed a player with the debuff
		if SH[dstName].debuff then
			SH.UpdateHealingBar(dstName,absorbed)
		end
	elseif event == "SPELL_PERIODIC_HEAL" then
		local spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(1, ... )
		-- Check if someone healed a player with the debuff
		if SH[dstName].debuff then
			SH.UpdateHealingBar(dstName,absorbed)
		end
	end
end

function SH.CreateHealingBar(dstName,spellId)
	local found=false
	for index, barFrame in pairs(SH.barFrames) do
		if barFrame.playerName==dstName then
			found=true
		end
	end
	if found==true then
		local barFrame = SH.barFrames[dstName]
		barFrame.healed = 0
		barFrame:Show()
		SH.UpdateFramePositions()
	else
		local barFrame = CreateFrame("StatusBar", "SPHD"..dstName, UIParent)
		SH.barFrames[dstName] = barFrame
		barFrame.healed = 0
		barFrame.playerName = dstName
		if spellId == 109362 then
			barFrame.needed = 300000
		elseif spellId == 109363 then
			barFrame.needed = 420000
		elseif spellId == 109364 then
			barFrame.needed = 280000
		end
		barFrame:SetMinMaxValues(0,barFrame.needed)
		local nameFont = barFrame:CreateFontString("$parentText", "ARTWORK", "GameFontNormal")
		local healthFont = barFrame:CreateFontString("$parentText", "ARTWORK", "GameFontNormal")
		barFrame:SetWidth(SPHD_DB.width)
		barFrame:SetHeight(SPHD_DB.height)
		local class, classFileName = UnitClass(dstName)
		local color = RAID_CLASS_COLORS[classFileName]
		barFrame:SetStatusBarColor(color.r,color.g,color.b)
		nameFont:SetFont("Fonts\\FRIZQT__.TTF",12)
		healthFont:SetFont("Fonts\\FRIZQT__.TTF",12)
		nameFont:SetPoint("LEFT",barFrame,"LEFT",0,0)
		healthFont:SetPoint("RIGHT",barFrame,"RIGHT",0,0)
		nameFont:SetTextColor(1,1,1,1)
		healthFont:SetTextColor(1,1,1,1)
		barFrame.nameFont = nameFont
		barFrame.healthFont = healthFont
		barFrame.nameFont:SetText(string.format("%s",barFrame.playerName))
	end
end

function SH.UpdateHealingBar(dstName,absorbed)
	local barFrame = SH.barFrames[dstName]
	barFrame.healed = barFrame.healed + absorbed
	if barFrame.healed <= barFrame.needed then
		barFrame:SetValue(barFrame.needed-barFrame.healed)
		barFrame.healthFont:SetText(string.format("%3.0fk",(barFrame.needed-barFrame.healed)/1000))
	end
end

function SH.UpdateFramePositions()
	local barpos = {}
	local i = 1
	for index, barFrame in pairs(SH.barFrames) do
		if barFrame:IsVisible() then
			barpos[i] = barFrame.healed
			i = i + 1
		end
	end
	table.sort(barpos, function(a,b) return a>b end)
	
	for index, barFrame in pairs(SH.barFrames) do
		if barFrame:IsVisible() then
			for i, healed in pairs(barpos) do
				if healed==barFrame.healed then
					local yOffset = (SPHD_DB.height*i)-(SPHD_DB.height*i*2)
					barFrame:SetPoint("CENTER",SH.anchorFrame,"CENTER",0,yOffset)
				end
			end
		end
	end
end

function SH.UpdBarFrames(anchorFrame, elapsed)
	anchorFrame.elapsed = anchorFrame.elapsed + elapsed
	if (anchorFrame.elapsed >= 1 ) then
		SH.UpdateFramePositions()
		anchorFrame.elapsed = 0
	end
end