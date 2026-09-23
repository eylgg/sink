-- luacheck configuration for Sink (https://github.com/lunarmodules/luacheck)
std = "lua51"
max_line_length = 140
self = false

-- Globals this addon defines or writes into.
globals = {
    "SinkDB",
    "SinkMapPinMixin",
    "SLASH_SINK1",
    "SlashCmdList",
    "Sink_OnAddonCompartmentClick",
    "StaticPopupDialogs",
}

-- WoW API this addon reads.
read_globals = {
    -- frames and widgets
    "ContainerFrameCombinedBags",
    "CreateFrame",
    "EditModeManagerFrame",
    "GameTooltip",
    "PlayerFrame",
    "UIErrorsFrame",
    "UIParent",
    "WorldMapFrame",
    -- namespaces and mixins
    "C_Container",
    "C_Item",
    "C_Map",
    "C_QuestLog",
    "C_SkillInfo",
    "C_Timer",
    "C_TooltipInfo",
    "Enum",
    "EventRegistry",
    "MapCanvasDataProviderMixin",
    "MapCanvasPinMixin",
    "MinimalSliderWithSteppersMixin",
    "Settings",
    "TooltipDataProcessor",
    -- functions
    "ClearCursor",
    "CreateFromMixins",
    "CursorHasItem",
    "DeleteCursorItem",
    "GetGameMessageInfo",
    "GetMerchantItemID",
    "GetMerchantItemLink",
    "GetMerchantNumItems",
    "GetNumTrainerServices",
    "GetSubZoneText",
    "GetTrainerServiceInfo",
    "GetTrainerServiceSkillLine",
    "GetZoneText",
    "InCombatLockdown",
    "IsPlayerSpell",
    "IsSpellKnown",
    "StaticPopup_Show",
    "UnitClass",
    "UnitExists",
    "UnitFactionGroup",
    "UnitGUID",
    "UnitName",
    "hooksecurefunc",
    "strsplit",
    -- constants and global strings
    "BACKPACK_CONTAINER",
    "BLACK_LISTED_MESSAGE_TYPES",
    "DELETE",
    "ITEM_SPELL_KNOWN",
    "NUM_BAG_SLOTS",
    "NUM_CONTAINER_FRAMES",
    "NUM_TOTAL_EQUIPPED_BAG_SLOTS",
    "UISpecialFrames",
    "UNIT_LEVEL_TEMPLATE",
}
