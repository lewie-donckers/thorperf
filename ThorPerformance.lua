-- CONSTANTS

local ADDON_NAME = "ThorPerformance"
local ADDON_VERSION = "1.1.1"
local ADDON_AUTHOR = "Thorinsøn"

local DATABASE_DEFAULTS = {
    char = {
        minimap = { hide = false }
    }
}

local COLOR_ORANGE = "|cffff7f00"
local COLOR_RESUME = "|r"
-- TODO rework to own style
local COLOR_GOLD = "|cfffed100%s|r";

local hugeFramerate = 48; -- at 24fps, the fps becomes yellow, higher values color it green, lower values red
local hugeLatency = 200; -- at 100ms, the latency becomes yellow, lower than 100ms colors it green, higher values red


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
    Log("[DBG] " .. message, ...)
end

-- TODO refactor
local function format_kbs(value)
	return ("%.1f "..COLOR_GOLD):format(value, "kb/s");
end

-- TODO refactor
local function format_latency(value, space)
	-- TODO replace LibCrayon
	return ("|cff%s%d|r"..(space and "" or " ")..COLOR_GOLD):format(LibCrayon:GetThresholdHexColor(hugeLatency - value, hugeLatency), value, "ms");
end

-- TODO refactor
local function format_fps(value, space)
	-- TODO replace LibCrayon
	return ("|cff%s%.1f|r"..(space and "" or " ")..COLOR_GOLD):format(LibCrayon:GetThresholdHexColor(value, hugeFramerate), value, "fps");
end

----- CLASS - ThorPerformance

local ThorPerformance = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

function ThorPerformance:UpdateBroker()
	self.ldb.text =
		(format_fps(self.fps, true).." " or "")..
		(format_latency(self.latencyHome, true).." " or "")..
		(format_latency(self.latencyWorld, true).." " or "");
end

function ThorPerformance:UpdateData()	
	self.fps = GetFramerate();
	self.bandwidthDown, self.bandwidthUp, self.latencyHome, self.latencyWorld = GetNetStats();
	
	self:UpdateBroker();
	if self.tooltip ~= nil then
		self:UpdateTooltip()
	end
end

function ThorPerformance:UpdateTooltip()
	local firstDisplay = self.tooltip:GetLineCount() == 0;
	if( firstDisplay ) then
		self.tooltip:SetColumnLayout(2, "LEFT", "RIGHT");

		self.tooltip:AddHeader("ThorPerformance");
		
		self.tooltip:AddSeparator();

		self.tooltip:AddLine();
		self.tooltip:AddLine();
		self.tooltip:AddLine();
		self.tooltip:AddLine();
		self.tooltip:AddLine();

		self.tooltip:SetCell(3, 1, (COLOR_GOLD):format("Framerate"));
		self.tooltip:SetCell(4, 1, (COLOR_GOLD):format("Latency Home"));
		self.tooltip:SetCell(5, 1, (COLOR_GOLD):format("Latency World"));
		self.tooltip:SetCell(7, 1, (COLOR_GOLD):format("Stream download"));
		self.tooltip:SetCell(6, 1, (COLOR_GOLD):format("Stream upload"));
	end

	self.tooltip:SetCell(3, 2, format_fps(self.fps));
	self.tooltip:SetCell(4, 2, format_latency(self.latencyHome));
	self.tooltip:SetCell(5, 2, format_latency(self.latencyWorld));
	self.tooltip:SetCell(6, 2, format_kbs(self.bandwidthDown));
	self.tooltip:SetCell(7, 2, format_kbs(self.bandwidthUp));
end

function ThorPerformance:OnTimer()
    LogDebug("OnTimer")
end

function ThorPerformance:OnLdbClick()
    LogDebug("OnLdbClick")
end

function ThorPerformance:OnLdbEnter(anchor)
    LogDebug("OnLdbEnter")

	if self.qtip:IsAcquired("ThorPerformanceTip") then
        return
    end

    self.tooltip = self.qtip:Acquire("ThorPerformanceTip")
    self.tooltip.OnRelease = function() self:OnTooltipRelease() end
    self.tooltip:SmartAnchorTo(anchor);
    self.tooltip:SetAutoHideDelay(0.25, anchor);
    self:UpdateTooltip()
    self.tooltip:Show();
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

    Log("use \"/thorperformance minimap enable\" to enable the minimap button")
    Log("use \"/thorperformance minimap disable\" to disable the minimap button")
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
        LogDebug("OnChatCommand - minimap disable")
        self.db.char.minimap.hide = true
        self.dbicon:Hide(ADDON_NAME)
        Log("minimap button disabled")
    else
        return self:LogCommandUsage(true)
    end
end

function ThorPerformance:OnEnable()
    LogDebug("OnEnable")

    self.db = LibStub("AceDB-3.0"):New("ThorPerformanceDB", DATABASE_DEFAULTS)

    self.qtip = LibStub("LibQTip-1.0")
    self.tooltip = nil

    self.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
        type = "data source",
        icon = "Interface\\Icons\\achievement_level_80",
        text = ADDON_NAME,})
    self.ldb.OnClick = function() self:OnLdbClick() end
    self.ldb.OnEnter = function(anchor) self:OnLdbEnter(anchor) end
    self.ldb.OnLeave = function() self:OnLdbLeave() end
    
    self.dbicon = LibStub("LibDBIcon-1.0")
    self.dbicon:Register(ADDON_NAME, self.ldb, self.db.char.minimap)

    self:RegisterChatCommand("thorperformance", "OnChatCommand")

	-- TODO make constant?
	local timeToPass = 2.5;
	self.updateTimer = self:ScheduleRepeatingTimer("OnTimer", timeToPass);

	self:UpdateData()

    Log("version " .. ADDON_VERSION .. " by " .. FormatColorClass("HUNTER", ADDON_AUTHOR) ..  " initialized")
    Log("use \"/thorperformance\" to set options")
end
