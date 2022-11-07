-----------------------------------
-- Setting up scope, upvalues and libs
-----------------------------------

local AddonName, ThorPerf = ...;
LibStub("AceEvent-3.0"):Embed(ThorPerf);
LibStub("AceTimer-3.0"):Embed(ThorPerf);

local LibCrayon = LibStub("LibCrayon-3.0");

local _G = _G; -- I always use _G.FUNC when I call a Global. Upvalueing done here.
local format = string.format;

-------------------------------
-- Registering with iLib
-------------------------------

LibStub("iLib"):Register(AddonName, nil, ThorPerf);

-----------------------------------------
-- Variables, functions and colors
-----------------------------------------

local hugeFramerate = 48; -- at 24fps, the fps becomes yellow, higher values color it green, lower values red
local hugeLatency = 200; -- at 100ms, the latency becomes yellow, lower than 100ms colors it green, higher values red

local UpdateTimer;
local Mods = {};

local ThorPerfFramerate = 0;
local ThorPerfLatencyHome = 0;
local ThorPerfLatencyWorld = 0;
local ThorPerfUpload = 0;
local ThorPerfDownload = 0;

local COLOR_GOLD = "|cfffed100%s|r";

------------------------------
-- Formatting Functions
------------------------------

local function format_kbs(value)
	return ("%.1f "..COLOR_GOLD):format(value, "kb/s");
end

local function format_latency(value, space)
	return ("|cff%s%d|r"..(space and "" or " ")..COLOR_GOLD):format(LibCrayon:GetThresholdHexColor(hugeLatency - value, hugeLatency), value, "ms");
end

local function format_fps(value, space)
	return ("|cff%s%.1f|r"..(space and "" or " ")..COLOR_GOLD):format(LibCrayon:GetThresholdHexColor(value, hugeFramerate), value, "fps");
end

-----------------------------
-- Setting up the LDB
-----------------------------

ThorPerf.ldb = LibStub("LibDataBroker-1.1"):NewDataObject(AddonName, {
	type = "data source",
	text = "",
});

ThorPerf.ldb.OnClick = function(_, button)
end

ThorPerf.ldb.OnEnter = function(anchor)
	if( ThorPerf:IsTooltip("Main") ) then
		return;
	end
	ThorPerf:HideAllTooltips();
	
	local tip = ThorPerf:GetTooltip("Main", "UpdateTooltip");
	tip:SmartAnchorTo(anchor);
	tip:SetAutoHideDelay(0.25, anchor);
	
	tip:Show();
end

ThorPerf.ldb.OnLeave = function() end -- some display addons refuse to display brokers when this is not defined

function ThorPerf:Boot()
	self:RefreshTimer();
	self:UnregisterEvent("PLAYER_ENTERING_WORLD");
end
ThorPerf:RegisterEvent("PLAYER_ENTERING_WORLD", "Boot");

function ThorPerf:RefreshTimer(timeToPass)
	if( UpdateTimer ) then
		self:CancelTimer(UpdateTimer);
		UpdateTimer = nil;
	end
	
	if( not timeToPass ) then
		timeToPass = 2.5;
	end
	
	UpdateTimer = self:ScheduleRepeatingTimer("UpdateData", timeToPass);
	self:UpdateData();
end

function ThorPerf:UpdateBroker()
	self.ldb.text =
		(format_fps(ThorPerfFramerate, true).." " or "")..
		(format_latency(ThorPerfLatencyHome, true).." " or "")..
		(format_latency(ThorPerfLatencyWorld, true).." " or "");
end

function ThorPerf:UpdateData()	
	ThorPerfFramerate = _G.GetFramerate();
	ThorPerfDownload, ThorPerfUpload, ThorPerfLatencyHome, ThorPerfLatencyWorld = _G.GetNetStats();
	
	self:CheckTooltips("Main");
	self:UpdateBroker();
end

function ThorPerf:UpdateTooltip(tip)
	local firstDisplay = tip:GetLineCount() == 0;
	if( firstDisplay ) then
		tip:SetColumnLayout(2, "LEFT", "RIGHT");

		tip:AddLine("ThorPerf");
		
		tip:AddLine();
		tip:AddLine();
		tip:AddLine();
		tip:AddLine();
		tip:AddLine();
		tip:AddLine();

		tip:SetCell(3, 1, (COLOR_GOLD):format("Framerate"), nil, "LEFT");
		tip:SetCell(4, 1, (COLOR_GOLD):format("Latency Home"), nil, "LEFT");
		tip:SetCell(5, 1, (COLOR_GOLD):format("Latency World"), nil, "LEFT");
		tip:SetCell(7, 1, (COLOR_GOLD):format("Stream download"), nil, "LEFT");
		tip:SetCell(6, 1, (COLOR_GOLD):format("Stream upload"), nil, "LEFT");
	end

	tip:SetCell(3, 2, format_fps(ThorPerfFramerate), nil, "RIGHT");
	tip:SetCell(4, 2, format_latency(ThorPerfLatencyHome), nil, "RIGHT");
	tip:SetCell(5, 2, format_latency(ThorPerfLatencyWorld), nil, "RIGHT");
	tip:SetCell(6, 2, format_kbs(ThorPerfDownload), nil, "RIGHT");
	tip:SetCell(7, 2, format_kbs(ThorPerfUpload), nil, "RIGHT");
end
