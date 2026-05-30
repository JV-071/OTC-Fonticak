notificationsController = Controller:new()
function notificationsController:onInit()
    self:registerEvents(g_game, {
        onClientEvent = function(...)
            self:onClientEvent(...)
        end,
    })
end
function notificationsController:onTerminate()
    screenshot_onTerminate()
    infoBanner_onTerminate()
end

local playerLevels = {}
local playerSkills = {}
local playerBaseMagicLevel = nil
local notificationTextMessageModes = {}
local notificationTextMessageCallback = nil

local ScreenshotType = {
    ACHIEVEMENT = 1,
    BESTIARY_ENTRY_COMPLETED = 2,
    BESTIARY_ENTRY_UNLOCKED = 3
}

local otcToProtoSkill = {
    [0] = 5, -- Fist
    [1] = 3, -- Club
    [2] = 2, -- Sword
    [3] = 4, -- Axe
    [4] = 6, -- Distance
    [5] = 7, -- Shielding
    [6] = 8  -- Fishing
}

local function getAchievementName(message)
    if not message then
        return nil
    end

    return message:match("[Yy]ou have earned ['\"]([^'\"]+)['\"]") or
           message:match("[Yy]ou earned ['\"]([^'\"]+)['\"]") or
           message:match("[Aa]chievement[ '%\"]+([^'\"]+)['\"]?")
end

local function getBestiaryProgressFromMessage(message)
    if not message then
        return nil
    end

    local creatureName = message:match("[Yy]ou unlocked the first Bestiary stage for ([^.]+)%.")
    if creatureName then
        return string.format("the first Bestiary stage for %s", creatureName)
    end

    creatureName = message:match("[Yy]ou unlocked the second Bestiary stage for ([^.]+)%.")
    if creatureName then
        return string.format("the second Bestiary stage for %s", creatureName)
    end

    creatureName = message:match("[Yy]ou completed the Bestiary entry for ([^.]+)%.")
    if creatureName then
        return string.format("the completed Bestiary entry for %s", creatureName)
    end

    return nil
end

local function onNotificationTextMessage(mode, message)
    local lowerMessage = message and message:lower() or ""
    if lowerMessage:find("soul point", 1, true) and
       (lowerMessage:find("don't have enough", 1, true) or lowerMessage:find("do not have enough", 1, true) or lowerMessage:find("not enough", 1, true)) then
        showOutOfSoulPointsBanner()
    end

    local achievementName = getAchievementName(message)
    if achievementName then
        showAchievementBanner(achievementName)
    end

    local bestiaryProgress = getBestiaryProgressFromMessage(message)
    if bestiaryProgress then
        showBestiaryBanner(0, bestiaryProgress)
    end
end

local function registerNotificationMessageModes()
    notificationTextMessageCallback = notificationTextMessageCallback or onNotificationTextMessage
    notificationTextMessageModes = {
        MessageModes.Failure,
        MessageModes.Game,
        MessageModes.Status,
        MessageModes.Login
    }

    for _, mode in ipairs(notificationTextMessageModes) do
        registerMessageMode(mode, notificationTextMessageCallback)
    end
end

local function unregisterNotificationMessageModes()
    if not notificationTextMessageCallback then
        return
    end

    for _, mode in ipairs(notificationTextMessageModes) do
        unregisterMessageMode(mode, notificationTextMessageCallback)
    end
    notificationTextMessageModes = {}
end

function notificationsController:onGameStart()
    screenshot_onGameStart()

    playerLevels = {}
    playerSkills = {}
    playerBaseMagicLevel = nil
    self.recentAdvanceEvents = {}
    self.activeAdvanceKey = nil
    self.recentClientEvents = {}

    local player = g_game.getLocalPlayer()
    if player then
        local charName = player:getName()
        if charName then
            playerLevels[charName] = player:getLevel()
        end
        playerBaseMagicLevel = player:getBaseMagicLevel()
        for id, protoId in pairs(otcToProtoSkill) do
            playerSkills[protoId] = player:getSkillBaseLevel(id)
        end
    end

    self:registerEvents(LocalPlayer, {
        onTakeScreenshot = function(player, screenshotType)
            if screenshotType == ScreenshotType.ACHIEVEMENT then
                showAchievementBanner()
            elseif screenshotType == ScreenshotType.BESTIARY_ENTRY_UNLOCKED then
                showBestiaryBanner(0, "Bestiary entry unlocked")
            elseif screenshotType == ScreenshotType.BESTIARY_ENTRY_COMPLETED then
                showBestiaryBanner(0, "Bestiary entry completed")
            end
        end,
        onLevelChange = function(player, level, percent, oldLevel)
            local charName = player:getName()
            oldLevel = playerLevels[charName] or oldLevel
            if not oldLevel or oldLevel == 0 then
                playerLevels[charName] = level
                return
            end
            if level > oldLevel then
                for l = oldLevel + 1, level do
                    self:onClientEvent(4, l)
                end
            end
            playerLevels[charName] = level
        end,
        onBaseMagicLevelChange = function(player, baseMagicLevel, oldBaseMagicLevel)
            oldBaseMagicLevel = playerBaseMagicLevel or oldBaseMagicLevel
            if not oldBaseMagicLevel or oldBaseMagicLevel == 0 then
                playerBaseMagicLevel = baseMagicLevel
                return
            end
            if baseMagicLevel > oldBaseMagicLevel then
                for l = oldBaseMagicLevel + 1, baseMagicLevel do
                    self:onClientEvent(5, 1, l)
                end
            end
            playerBaseMagicLevel = baseMagicLevel
        end,
        onBaseSkillChange = function(player, id, baseLevel, oldBaseLevel)
            local protoId = otcToProtoSkill[id]
            if not protoId then return end
            oldBaseLevel = playerSkills[protoId] or oldBaseLevel
            if not oldBaseLevel or oldBaseLevel == 0 then
                playerSkills[protoId] = baseLevel
                return
            end
            if baseLevel > oldBaseLevel then
                for l = oldBaseLevel + 1, baseLevel do
                    self:onClientEvent(5, protoId, l)
                end
            end
            playerSkills[protoId] = baseLevel
        end
    })

    registerNotificationMessageModes()
end

function notificationsController:onGameEnd()
    unregisterNotificationMessageModes()
    screenshot_onGameEnd()
end

function showBestiaryProgress(raceId, progress)
    local progressText = ({
        [1] = "first Bestiary stage",
        [2] = "second Bestiary stage",
        [3] = "completed Bestiary entry"
    })[progress] or string.format("Bestiary stage %s", tostring(progress))

    showBestiaryBanner(raceId, progressText)
end
