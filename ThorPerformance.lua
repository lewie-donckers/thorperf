-- CONSTANTS

local ADDON_NAME = "ThorPerformance"
local ADDON_VERSION = "1.0.0"
local ADDON_AUTHOR = "Thorinsøn"

local TIMER_TIMEOUT = 2.5
local COMMAND_NAME = "thorperformance"
local TOOLTIP_NAME = ADDON_NAME .. "Tip"
local DATABASE_NAME = ADDON_NAME .. "DB"
local DATABASE_DEFAULTS = {
    char = {
        minimap = { hide = false }
    }
}

local THRESHOLD_FRAMERATE = 60
local THRESHOLD_LATENCY = 200

local COLOR_LOG = "|cffff7f00"
local COLOR_GOLD = "|cfffed100"
local COLOR_RESUME = "|r"


-- FUNCTIONS

local function FormatColor(color, message, ...)
    return color .. string.format(message, ...) .. COLOR_RESUME
end

local function FormatColorClass(class, message, ...)
    local _, _, _, color = GetClassColor(class)
    return FormatColor("|c" .. color, message, ...)
end

local function Log(message, ...)
    print(FormatColor(COLOR_LOG, "[" .. ADDON_NAME .. "] " .. message, ...))
end

local function LogDebug(message, ...)
    -- Log("[DBG] " .. message, ...)
end

local function GetThresholdPercentage(value, threshold)
	if value >= threshold then
		return 1
	elseif value <= 0 then		
		return 0
	end

	return value / threshold
end

local function GetThresholdColorRGB(value, threshold)
	local percent = GetThresholdPercentage(value, threshold)

	if percent <= 0 then
		return 1, 0, 0
	elseif percent <= 0.5 then
		return 1, percent*2, 0
	elseif percent >= 1 then
		return 0, 1, 0
	else
		return 2 - percent*2, 1, 0
	end
end

local function GetThresholdColor(quality, ...)
	local r, g, b = GetThresholdColorRGB(quality, ...)
	return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local function FormatLatency(value)
	return FormatColor(GetThresholdColor(THRESHOLD_LATENCY - value, THRESHOLD_LATENCY), "%d", value) .. " " .. FormatColor(COLOR_GOLD, "ms")
end

local function FormatFramerate(value)
	return FormatColor(GetThresholdColor(value, THRESHOLD_FRAMERATE), "%.1f", value) .. " " .. FormatColor(COLOR_GOLD, "fps")
end

local function FormatBandwidth(value)
	return string.format("%.1f %s", value, FormatColor(COLOR_GOLD, "kBps"))
end


----- CLASS - ThorPerformance

local ThorPerformance = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

function ThorPerformance:UpdateBroker()
	self.ldb.text = string.format("%s %s %s", FormatFramerate(self.framerate), FormatLatency(self.latencyHome), FormatLatency(self.latencyWorld))
end

function ThorPerformance:UpdateData()	
	self.framerate = GetFramerate()
	self.bandwidthIn, self.bandwidthOut, self.latencyHome, self.latencyWorld = GetNetStats()
	
	self:UpdateBroker()
	self:UpdateTooltip()
end

function ThorPerformance:UpdateTooltip()
	if self.tooltip == nil then
		return
	end

	local isInitialized = self.tooltip:GetLineCount() ~= 0
	if not isInitialized then
		self.tooltip:SetColumnLayout(2, "LEFT", "RIGHT")

		self.tooltip:AddHeader(ADDON_NAME .. " " .. ADDON_VERSION)
		
		self.tooltip:AddSeparator()

		for i = 1, 5 do
			self.tooltip:AddLine()
		end

		self.tooltip:SetCell(3, 1, FormatColor(COLOR_GOLD, "Framerate"))
		self.tooltip:SetCell(4, 1, FormatColor(COLOR_GOLD, "Latency Home"))
		self.tooltip:SetCell(5, 1, FormatColor(COLOR_GOLD, "Latency World"))
		self.tooltip:SetCell(6, 1, FormatColor(COLOR_GOLD, "Bandwith download"))
		self.tooltip:SetCell(7, 1, FormatColor(COLOR_GOLD, "Bandwith upload"))
	end

	self.tooltip:SetCell(3, 2, FormatFramerate(self.framerate))
	self.tooltip:SetCell(4, 2, FormatLatency(self.latencyHome))
	self.tooltip:SetCell(5, 2, FormatLatency(self.latencyWorld))
	self.tooltip:SetCell(6, 2, FormatBandwidth(self.bandwidthIn))
	self.tooltip:SetCell(7, 2, FormatBandwidth(self.bandwidthOut))
end

function ThorPerformance:OnTimer()
    LogDebug("OnTimer")

	self:UpdateData()
end

function ThorPerformance:OnLdbClick()
    LogDebug("OnLdbClick")
end

function ThorPerformance:OnLdbEnter(anchor)
    LogDebug("OnLdbEnter")

	if self.qtip:IsAcquired(TOOLTIP_NAME) then
        return
    end

    self.tooltip = self.qtip:Acquire(TOOLTIP_NAME)
    self.tooltip.OnRelease = function() self:OnTooltipRelease() end
    self.tooltip:SmartAnchorTo(anchor)
    self.tooltip:SetAutoHideDelay(0.25, anchor)
    self:UpdateTooltip()
    self.tooltip:Show()
end

function ThorPerformance:OnLdbLeave()
    LogDebug("OnLdbLeave")
end

function ThorPerformance:OnTooltipRelease()
    LogDebug("OnTooltipRelease")

    self.tooltip = nil
end

function ThorPerformance:LogCommandUsage(isError)
    if isError then
        Log("invalid command")
    end

    Log("use \"/" .. COMMAND_NAME .. " minimap enable\" to enable the minimap button")
    Log("use \"/" .. COMMAND_NAME .. " minimap disable\" to disable the minimap button")
end

function ThorPerformance:OnChatCommand(str)
    LogDebug("OnChatCommand")

    local action, value, _ = self:GetArgs(str, 2)

    if action == nil then
        return self:LogCommandUsage(false)
    end

    if action ~= "minimap" then
        return self:LogCommandUsage(true)
    end

    if value == "enable" then
        self.db.char.minimap.hide = false
        self.dbicon:Show(ADDON_NAME)
        Log("minimap button enabled")
    elseif value == "disable" then
        self.db.char.minimap.hide = true
        self.dbicon:Hide(ADDON_NAME)
        Log("minimap button disabled")
    else
        return self:LogCommandUsage(true)
    end
end

function ThorPerformance:OnEnable()
    LogDebug("OnEnable")

    self.db = LibStub("AceDB-3.0"):New(DATABASE_NAME, DATABASE_DEFAULTS)

    self.qtip = LibStub("LibQTip-1.0")
    self.tooltip = nil

    self.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
        type = "data source",
        icon = "Interface\\Icons\\inv_gizmo_01",
        text = ADDON_NAME,})
    self.ldb.OnClick = function() self:OnLdbClick() end
    self.ldb.OnEnter = function(anchor) self:OnLdbEnter(anchor) end
    self.ldb.OnLeave = function() self:OnLdbLeave() end
    
    self.dbicon = LibStub("LibDBIcon-1.0")
    self.dbicon:Register(ADDON_NAME, self.ldb, self.db.char.minimap)

	self.updateTimer = self:ScheduleRepeatingTimer("OnTimer", TIMER_TIMEOUT)

    self:RegisterChatCommand(COMMAND_NAME, "OnChatCommand")

	self:UpdateData()

    Log("version " .. ADDON_VERSION .. " by " .. FormatColorClass("HUNTER", ADDON_AUTHOR) ..  " initialized")
    Log("use \"/" .. COMMAND_NAME .. "\" to set options")
end
