script_name("EliteMenu")
script_description("Elite Menu")
script_version("1.0")
script_authors("Satoru Yamaguchi")

-- Dependencies
require "lib.moonloader"
local imgui = require "mimgui"
local encoding = require "encoding"
local inicfg = require "inicfg"
local sampev = require "samp.events"
local ffi = require "ffi"
local vkeys = require "vkeys"

-- Encoding Setup
encoding.default = "CP1251"
u8 = encoding.UTF8
local VERSION = "1.0"
local AUTHOR = "Satoru Yamaguchi"

local Config = {
    dir = getWorkingDirectory() .. "\\config\\EliteMenu\\",
    configs = {
        Settings = {
            path = nil,
            data = nil,
            default = {
                Settings = {
                    lastModule = "Home",
                    menuKey = 191  -- Default key is "/" (191)
                }
            }
        },
        AutoSetFreq = {
            path = nil,
            data = nil,
            default = {
                Settings = {
                    active = true,
                    freq = "-1",
                    priority = 1
                }
            }
        },
        AutoVester = {
            path = nil,
            data = nil,
            default = {
                Settings = {
                    active = false,
                    autoAccept = true,
                    vestCommand = "autovest",
                    acceptCommand = "aav",
                    vestArmorThreshold = 40,
                    acceptArmorThreshold = 40,
                },
                WhitelistedGangs = {
                    [1] = false,
                    [2] = false,
                    [3] = false,
                    [4] = false,
                    [5] = false,
                    [6] = false,
                    [7] = false,
                    [8] = false,
                    [9] = false,
                    [10] = false
                }
            }
        }
    }
}

function Config:init()
    if not doesDirectoryExist(self.dir) then
        createDirectory(self.dir)
    end

    -- Initialize paths for each module
    for module, config in pairs(self.configs) do
        config.path = self.dir .. module .. ".ini"
    end

    -- Load each module's config
    for module, _ in pairs(self.configs) do
        print(module)
        self:load(module)
    end
end

function Config:load(module)
    local config = self.configs[module]
    if not config then
        sampAddChatMessage("{FF0000}[EliteMenu] {FFFFFF}Invalid module: " .. module, -1)
        return
    end

    if doesFileExist(config.path) then
        config.data = inicfg.load(config.default, config.path)
    else
        local success, err = pcall(function()
            local new_config = io.open(config.path, "w")
            new_config:close()
            new_config = nil
        end)
        if not success then
            sampAddChatMessage("{FF0000}[EliteMenu] {FFFFFF}Failed to create config file for " .. module .. ": " .. err, -1)
            return
        end
        config.data = config.default
        if not self:save(module) then
            sampAddChatMessage("{FF0000}[EliteMenu] {FFFFFF}Failed to save config for " .. module, -1)
        end
    end
end

function Config:save(module)
    local config = self.configs[module]
    if not config then
        sampAddChatMessage("{FF0000}[EliteMenu] {FFFFFF}Invalid module: " .. module, -1)
        return false
    end
    return inicfg.save(config.data, config.path)
end

-- Gang Order
local GangOrder = {
    "6th St. Kingz",
    "10th Ave Junkyard",
    "Yakuza",
    "Liang Shan",
    "Only The Family",
    "Black Hand Triads",
    "Bastards",
    "Pirates",
    "Puente Estrada",
    "Villain Hooligan Mobsters"
}

-- Gang Definitions
local Gangs = {
    ["6th St. Kingz"] = { skins = {0, 195, 293, 271, 269, 270}, color = imgui.ImVec4(0.01, 0.38, 0.10, 1.0), chatColor = "{05631C}" },
    ["10th Ave Junkyard"] = { skins = {261, 156, 176, 41, 21, 297, 69}, color = imgui.ImVec4(0.9843, 0.8706, 0.7020, 1.0), chatColor = "{FBDEB3}" },
    ["Yakuza"] = { skins = {49, 193, 60, 123, 263, 186, 210, 122}, color = imgui.ImVec4(0.60, 0.00, 0.00, 1.0), chatColor = "{990000}" },
    ["Liang Shan"] = { skins = {170, 229, 228, 121, 224, 231, 234, 2}, color = imgui.ImVec4(0.46, 0.62, 0.56, 1.0), chatColor = "{749E8F}" },
    ["Only The Family"] = { skins = {19, 22, 180, 144, 190, 58}, color = imgui.ImVec4(1.00, 0.00, 0.00, 1.0), chatColor = "{FF0000}" },
    ["Black Hand Triads"] = { skins = {294, 59, 117, 118, 120, 141, 169, 208}, color = imgui.ImVec4(0.36, 0.36, 0.36, 1.0), chatColor = "{5C5C5C}" },
    ["Bastards"] = { skins = {1, 192, 132, 100, 181, 247, 248}, color = imgui.ImVec4(0.29, 0.09, 0.09, 1.0), chatColor = "{491818}" },
    ["Pirates"] = { skins = {32, 209, 134, 201, 146, 136}, color = imgui.ImVec4(1.00, 0.26, 0.60, 1.0), chatColor = "{FF4399}" },
    ["Puente Estrada"] = { skins = {175, 268, 114, 115, 116, 174, 44, 53}, color = imgui.ImVec4(0.00, 1.00, 0.98, 1.0), chatColor = "{00FFFB}" },
    ["Villain Hooligan Mobsters"] = { skins = {13, 102, 103, 104, 185, 296}, color = imgui.ImVec4(0.50, 0.00, 0.50, 1.0), chatColor = "{800080}" }
}

-- UI State
local UI = {
    showMenu = imgui.new.bool(false),
    currentModule = nil,
    menuSize = imgui.ImVec2(600, 400),
    messageBuffer = imgui.new.char[128](),
    freqBuffer = nil,
    priorityBuffer = nil,
    vestCommandBuffer = nil,
    acceptCommandBuffer = nil,
    newSkinBuffer = imgui.new.char[8](""),
    vestArmorThresholdBuffer = nil,
    acceptArmorThresholdBuffer = nil,
    menuKeyBuffer = nil,
    waitingForKey = false,
    keyNames = {}
}

-- Color Schemes
local Colors = {
    primary = imgui.ImVec4(0.90, 0.10, 0.10, 1.0),
    primaryHover = imgui.ImVec4(1.0, 0.20, 0.20, 1.0),
    secondary = imgui.ImVec4(0.75, 0.08, 0.08, 1.0),
    background = imgui.ImVec4(0.10, 0.10, 0.11, 0.95),
    backgroundLight = imgui.ImVec4(0.14, 0.14, 0.16, 1.0),
    backgroundDark = imgui.ImVec4(0.08, 0.08, 0.09, 1.0),
    text = imgui.ImVec4(1.0, 1.0, 1.0, 1.0),
    textDim = imgui.ImVec4(0.75, 0.75, 0.75, 1.0),
    border = imgui.ImVec4(0.20, 0.20, 0.22, 1.0),
    success = imgui.ImVec4(0.20, 0.70, 0.20, 1.0),
    warning = imgui.ImVec4(0.90, 0.70, 0.0, 1.0),
    disabled = imgui.ImVec4(0.50, 0.50, 0.50, 0.6),
    moduleAutoSetFreq = imgui.ImVec4(0.95, 0.40, 0.40, 1.0),
    moduleAutoVester = imgui.ImVec4(0.40, 0.60, 0.95, 1.0),
    moduleHighCommand = imgui.ImVec4(0.95, 0.70, 0.20, 1.0),
    moduleMisc = imgui.ImVec4(0.60, 0.40, 0.95, 1.0),
    discord = imgui.ImVec4(0.40, 0.45, 0.90, 1.0)
}

local ChatColors = {
    main = "{FF0000}",
    autoSetFreq = "{F26666}",
    autoVester = "{6699FF}",
    highCommand = "{F2B233}",
    misc = "{9966F2}",
    success = "{33CC33}",
    warning = "{FFCC00}",
    error = "{FF3333}"
}

-- Module Management
local Modules = {
    list = {}, -- Sub-table to store actual modules
    order = {} -- Array to maintain module order
}

function Modules:register(name, renderFunc)
    self.list[name] = { name = name, render = renderFunc }
    table.insert(self.order, name)
end

-- UI Components
local UIComponents = {}

function UIComponents:DrawButton(label, size, primaryColor)
    local btnColor = primaryColor and Colors.primary or Colors.backgroundLight
    local hoverColor = primaryColor and Colors.primaryHover or Colors.border
    
    imgui.PushStyleColor(imgui.Col.Button, btnColor)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, hoverColor)
    imgui.PushStyleColor(imgui.Col.ButtonActive, primaryColor and Colors.secondary or Colors.backgroundDark)
    
    local result = imgui.Button(label, size)
    
    imgui.PopStyleColor(3)
    return result
end

function UIComponents:DrawToggle(value, size)
    local result = value
    local toggleSize = size or imgui.ImVec2(36, 18)
    local p = imgui.GetCursorScreenPos()
    local drawList = imgui.GetWindowDrawList()
    
    local bgColor = value and Colors.primary or Colors.backgroundLight
    local bgColorU32 = imgui.ColorConvertFloat4ToU32(bgColor)
    drawList:AddRectFilled(p, imgui.ImVec2(p.x + toggleSize.x, p.y + toggleSize.y), bgColorU32, 9.0)
    
    local circlePos = value and (p.x + toggleSize.x - toggleSize.y/2 - 2) or (p.x + toggleSize.y/2 + 2)
    local circleColor = value and Colors.text or Colors.textDim
    local circleColorU32 = imgui.ColorConvertFloat4ToU32(circleColor)
    drawList:AddCircleFilled(imgui.ImVec2(circlePos, p.y + toggleSize.y/2), toggleSize.y/2 - 4, circleColorU32)
    
    imgui.InvisibleButton("##toggle", toggleSize)
    if imgui.IsItemClicked() then
        result = not value
    end
    
    return result
end

-- Helper Functions
local Helpers = {}

function Helpers:isPlayerInGang(playerId, gangList)
    local result, ped = sampGetCharHandleBySampPlayerId(playerId)
    if not result then return false, nil end
    
    local playerSkin = getCharModel(ped)
    -- Convert boolean gangList to list of whitelisted gang names
    local whitelistedGangNames = {}
    for i, isWhitelisted in ipairs(gangList) do
        if isWhitelisted and GangOrder[i] then
            table.insert(whitelistedGangNames, GangOrder[i])
        end
    end
    
    for _, gangName in ipairs(whitelistedGangNames) do
        if Gangs[gangName] then
            for _, skinId in ipairs(Gangs[gangName].skins) do
                if playerSkin == skinId then
                    return true, gangName
                end
            end
        end
    end
    return false, nil
end

function Helpers:getPlayerIdByName(playerName)
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) then
            name = sampGetPlayerNickname(i)
            if name == playerName then
                return i
            end
        end
    end
    return -1 -- Return -1 if player not found
end

function Helpers:hasOneFreq(text)
    local _, count = text:gsub("[-]?%d+", "")
    return count == 1 or false
end

function Helpers:getKeyName(keyCode)
    if UI.keyNames[keyCode] then
        return UI.keyNames[keyCode]
    end
    
    -- Default key names for common keys
    local keyNames = {
        [VK_LBUTTON] = "Left Mouse",
        [VK_RBUTTON] = "Right Mouse",
        [VK_MBUTTON] = "Middle Mouse",
        [VK_BACK] = "Backspace",
        [VK_TAB] = "Tab",
        [VK_RETURN] = "Enter",
        [VK_SHIFT] = "Shift",
        [VK_CONTROL] = "Ctrl",
        [VK_MENU] = "Alt",
        [VK_PAUSE] = "Pause",
        [VK_CAPITAL] = "Caps Lock",
        [VK_ESCAPE] = "Escape",
        [VK_SPACE] = "Space",
        [VK_PRIOR] = "Page Up",
        [VK_NEXT] = "Page Down",
        [VK_END] = "End",
        [VK_HOME] = "Home",
        [VK_LEFT] = "Left Arrow",
        [VK_UP] = "Up Arrow",
        [VK_RIGHT] = "Right Arrow",
        [VK_DOWN] = "Down Arrow",
        [VK_INSERT] = "Insert",
        [VK_DELETE] = "Delete",
        [0x30] = "0", [0x31] = "1", [0x32] = "2", [0x33] = "3", [0x34] = "4",
        [0x35] = "5", [0x36] = "6", [0x37] = "7", [0x38] = "8", [0x39] = "9",
        [0x41] = "A", [0x42] = "B", [0x43] = "C", [0x44] = "D", [0x45] = "E",
        [0x46] = "F", [0x47] = "G", [0x48] = "H", [0x49] = "I", [0x50] = "J",
        [0x4B] = "K", [0x4C] = "L", [0x4D] = "M", [0x4E] = "N", [0x4F] = "O",
        [0x50] = "P", [0x51] = "Q", [0x52] = "R", [0x53] = "S", [0x54] = "T",
        [0x55] = "U", [0x56] = "V", [0x57] = "W", [0x58] = "X", [0x59] = "Y",
        [0x5A] = "Z",
        [VK_NUMPAD0] = "Numpad 0", [VK_NUMPAD1] = "Numpad 1", [VK_NUMPAD2] = "Numpad 2",
        [VK_NUMPAD3] = "Numpad 3", [VK_NUMPAD4] = "Numpad 4", [VK_NUMPAD5] = "Numpad 5",
        [VK_NUMPAD6] = "Numpad 6", [VK_NUMPAD7] = "Numpad 7", [VK_NUMPAD8] = "Numpad 8",
        [VK_NUMPAD9] = "Numpad 9",
        [VK_MULTIPLY] = "Numpad *", [VK_ADD] = "Numpad +", [VK_SUBTRACT] = "Numpad -",
        [VK_DECIMAL] = "Numpad .", [VK_DIVIDE] = "Numpad /",
        [VK_F1] = "F1", [VK_F2] = "F2", [VK_F3] = "F3", [VK_F4] = "F4", [VK_F5] = "F5",
        [VK_F6] = "F6", [VK_F7] = "F7", [VK_F8] = "F8", [VK_F9] = "F9", [VK_F10] = "F10",
        [VK_F11] = "F11", [VK_F12] = "F12",
        [VK_NUMLOCK] = "Num Lock", [VK_SCROLL] = "Scroll Lock",
        [VK_LSHIFT] = "Left Shift", [VK_RSHIFT] = "Right Shift",
        [VK_LCONTROL] = "Left Ctrl", [VK_RCONTROL] = "Right Ctrl",
        [VK_LMENU] = "Left Alt", [VK_RMENU] = "Right Alt",
        [0xBA] = ";", [0xBB] = "=", [0xBC] = ",", [0xBD] = "-", [0xBE] = ".",
        [0xBF] = "/", [0xC0] = "`", [0xDB] = "[", [0xDC] = "\\", [0xDD] = "]",
        [0xDE] = "'",
        [191] = "/"
    }
    
    return keyNames[keyCode] or "Key " .. keyCode
end

-- AutoSetFreq Module
local AutoSetFreq = {}

function AutoSetFreq:toggle()
    Config.configs.AutoSetFreq.data.Settings.active = not Config.configs.AutoSetFreq.Settings.data.active
    Config:save("AutoSetFreq")
    local status = Config.configs.AutoSetFreq.data.Settings.active and "Activated" or "Deactivated"
    local color = Config.configs.AutoSetFreq.data.Settings.active and ChatColors.success or ChatColors.error
    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoSetFreq .. "AutoSetFreq {FFFFFF}has been " .. color .. status, 0xFFFFFF)
end

function AutoSetFreq:setPriority(index)
    index = tonumber(index)
    if index ~= 1 and index ~= 2 then return end
    Config.configs.AutoSetFreq.data.Settings.priority = index
    UI.priorityBuffer[0] = index
    Config:save("AutoSetFreq")
    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoSetFreq .. "AutoSetFreq {FFFFFF}Priority set to " .. ChatColors.success .. index, 0xFFFFFF)
end

function AutoSetFreq:processServerMessage(color, text)
    if not Config.configs.AutoSetFreq.data.Settings.active then return end
    if text:find("^You have set the frequency of your portable radio to") and color == -86 then
        lua_thread.create(function()
            wait(0)
            Config.configs.AutoSetFreq.data.Settings.freq = text:match("[-]?%d+")
            imgui.StrCopy(UI.freqBuffer, tostring(Config.configs.AutoSetFreq.data.Settings.freq))
            Config:save("AutoSetFreq")
        end)
    elseif text:find("^Family MOTD:") and color == -65366 then
        lua_thread.create(function()
            wait(0)
            local freq = Helpers:hasOneFreq(text) and text:match("[-]?%d+") or text:match("%[?(-?%d+)%]?.-%[?(-?%d+)%]?")
            if not Helpers:hasOneFreq(text) then
                local primary, secondary = text:match("%[?(-?%d+)%]?.-%[?(-?%d+)%]?")
                freq = Config.configs.AutoSetFreq.data.Settings.priority == 2 and secondary or primary
            end
            if Config.configs.AutoSetFreq.data.Settings.freq ~= freq then
                Config.configs.AutoSetFreq.data.Settings.freq = freq
                imgui.StrCopy(UI.freqBuffer, tostring(freq))
                Config:save("AutoSetFreq")
                sampSendChat("/setfreq " .. freq)
                sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoSetFreq .. "AutoSetFreq {FFFFFF}Successfully Updated Frequency", 0xFFFFFF)
            end
        end)
    end
end

-- AutoVester Module
local AutoVester = {}

function AutoVester:toggle()
    Config.configs.AutoVester.data.Settings.active = not Config.configs.AutoVester.data.Settings.active
    Config:save("AutoVester")
    local status = Config.configs.AutoVester.data.Settings.active and "Activated" or "Deactivated"
    local color = Config.configs.AutoVester.data.Settings.active and ChatColors.success or ChatColors.error
    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoVester .. "AutoVester {FFFFFF}has been " .. color .. status, 0xFFFFFF)
end

function AutoVester:toggleAccept()
    Config.configs.AutoVester.data.Settings.autoAccept = not Config.configs.AutoVester.data.Settings.autoAccept
    Config:save("AutoVester")
    local status = Config.configs.AutoVester.data.Settings.autoAccept and "Activated" or "Deactivated"
    local color = Config.configs.AutoVester.data.Settings.autoAccept and ChatColors.success or ChatColors.error
    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoVester .. "Auto Accept Vest {FFFFFF}has been " .. color .. status, 0xFFFFFF)
end

function AutoVester:processServerMessage(color, text)
    if Config.configs.AutoVester.data.Settings.autoAccept and text:find("wants to protect you for $%d+") and color == 869072810 then
        lua_thread.create(function ()
            wait(0)
            local amount = tonumber(text:match("wants to protect you for $(%d+)"))
            
            local myId = select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))
            local myArmor = sampGetPlayerArmor(myId)
            
            if amount <= 200 and myArmor <= Config.configs.AutoVester.data.Settings.acceptArmorThreshold then
                sampSendChat("/accept bodyguard")
            end
        end)
    end
end

function AutoVester:run()
    lua_thread.create(function()
        while true do
            wait(1000)
            if Config.configs.AutoVester.data.Settings.active then
                local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
            
                for i = 0, sampGetMaxPlayerId(false) do
                    if sampIsPlayerConnected(i) and not sampIsPlayerPaused(i) then
                        local result, ped = sampGetCharHandleBySampPlayerId(i)
                        if result and not sampIsPlayerPaused(i) then
                            local playerX, playerY, playerZ = getCharCoordinates(ped)
                            local distance = getDistanceBetweenCoords3d(myX, myY, myZ, playerX, playerY, playerZ)
                            local playerArmor = sampGetPlayerArmor(i)
                            
                            -- Check if player is in range and their armor is below threshold
                            if distance < 5.0 and 
                               playerArmor <= Config.configs.AutoVester.data.Settings.vestArmorThreshold then
                                -- Check if player is in whitelisted gang
                                local isWhitelisted, gangName = Helpers:isPlayerInGang(i, Config.configs.AutoVester.data.WhitelistedGangs)
                                
                                if isWhitelisted and not isKeyDown(vkeys.VK_RBUTTON) then
                                    sampSendChat("/guard " .. i .. " 200")
                                    wait(12500)
                                    break
                                end
                            end
                        end
                    end
                end
            end            
        end
    end)
end

-- Settings Module
local Settings = {}

function Settings:setMenuKey(keyCode)
    if keyCode > 0 then
        Config.configs.Settings.data.menuKey = keyCode
        Config:save("Settings")
        sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.success .. "Menu hotkey set to " .. Helpers:getKeyName(keyCode), 0xFFFFFF)
    end
end

-- Main Function
function main()
    if not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    Config:init()
    UI.currentModule = Config.configs.Settings.data.Settings.lastModule
    UI.freqBuffer = imgui.new.char[32](tostring(Config.configs.AutoSetFreq.data.Settings.freq))
    UI.priorityBuffer = imgui.new.int(Config.configs.AutoSetFreq.data.Settings.priority)
    UI.vestCommandBuffer = imgui.new.char[32](Config.configs.AutoVester.data.Settings.vestCommand)
    UI.acceptCommandBuffer = imgui.new.char[32](Config.configs.AutoVester.data.Settings.acceptCommand)
    UI.vestArmorThresholdBuffer = imgui.new.int(Config.configs.AutoVester.data.Settings.vestArmorThreshold)
    UI.acceptArmorThresholdBuffer = imgui.new.int(Config.configs.AutoVester.data.Settings.acceptArmorThreshold)
    UI.menuKeyBuffer = imgui.new.char[32](Helpers:getKeyName(Config.configs.Settings.data.Settings.menuKey))
    
    sampAddChatMessage(ChatColors.main .. "EliteMenu " .. "{D3D3D3}(" .. VERSION .. ") {FFFFFF}- Made by " .. AUTHOR .. " | " .. ChatColors.main .. "/elitemenu", 0xFFFFFF)
    
    sampRegisterChatCommand("elitemenu", function() UI.showMenu[0] = not UI.showMenu[0] end)
    sampRegisterChatCommand("asf", function() AutoSetFreq:toggle() end)
    sampRegisterChatCommand("asfset", function(arg) AutoSetFreq:setPriority(arg) end)
    sampRegisterChatCommand(Config.configs.AutoVester.data.Settings.vestCommand, function() AutoVester:toggle() end)
    sampRegisterChatCommand(Config.configs.AutoVester.data.Settings.acceptCommand, function() AutoVester:toggleAccept() end)
    
    Modules:register("Home", renderHome)
    Modules:register("Auto Set Freq", renderAutoSetFreq)
    Modules:register("Auto Vester", renderAutoVester)
    Modules:register("Auto Gunner", renderAutoGunner)
    Modules:register("Miscellaneous", renderMisc)
    Modules:register("Settings", renderSettings)
    
    sampev.onServerMessage = function(color, text)
        AutoSetFreq:processServerMessage(color, text)
        AutoVester:processServerMessage(color, text)
    end

    addEventHandler('onWindowMessage', function(msg, wparam, lparam)
        if UI.showMenu[0] and msg == 256 and wparam == 27 then  -- Escape key pressed
            consumeWindowMessage(true, false)  -- Block default Escape behavior
            UI.showMenu[0] = false
        end
    end)
    
    AutoVester:run()
    
    while true do
        wait(0)

        -- Check for menu key press
        if isKeyJustPressed(Config.configs.Settings.data.Settings.menuKey) and not sampIsChatInputActive() and not sampIsDialogActive() then
            UI.showMenu[0] = not UI.showMenu[0]
        end
        
        -- Check for key binding
        if UI.waitingForKey then
            for i = 1, 255 do
                if isKeyJustPressed(i) then
                    Settings:setMenuKey(i)
                    UI.waitingForKey = false
                    imgui.StrCopy(UI.menuKeyBuffer, Helpers:getKeyName(i))
                    break
                end
            end
        end
        
        if UI.showMenu[0] and Config.configs.Settings.data.Settings.lastModule ~= UI.currentModule then
            Config.configs.Settings.data.Settings.lastModule = UI.currentModule
            Config:save("Settings")
        end
    end
end

-- ImGui Styling
local function applyStyles()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    
    style.WindowPadding = imgui.ImVec2(10, 10)
    style.FramePadding = imgui.ImVec2(5, 5)
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.ItemInnerSpacing = imgui.ImVec2(4, 4)
    style.TouchExtraPadding = imgui.ImVec2(0, 0)
    style.IndentSpacing = 20
    style.ScrollbarSize = 10
    style.GrabMinSize = 5
    
    style.WindowRounding = 4.0
    style.ChildRounding = 4.0
    style.FrameRounding = 4.0
    style.PopupRounding = 0.0
    style.ScrollbarRounding = 0.0
    style.GrabRounding = 0.0
    style.TabRounding = 0.0
    
    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    
    style.WindowBorderSize = 0.0
    style.ChildBorderSize = 1.0
    style.PopupBorderSize = 1.0
    style.FrameBorderSize = 0.0
    style.TabBorderSize = 0.0
    
    style.Colors[imgui.Col.WindowBg] = Colors.background
    style.Colors[imgui.Col.TitleBg] = Colors.primary
    style.Colors[imgui.Col.TitleBgActive] = Colors.primary
    style.Colors[imgui.Col.TitleBgCollapsed] = Colors.primary
    style.Colors[imgui.Col.Border] = Colors.border
    style.Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    style.Colors[imgui.Col.FrameBg] = Colors.backgroundLight
    style.Colors[imgui.Col.FrameBgHovered] = Colors.border
    style.Colors[imgui.Col.FrameBgActive] = Colors.backgroundDark
    style.Colors[imgui.Col.CheckMark] = Colors.primary
    style.Colors[imgui.Col.SliderGrab] = Colors.primary
    style.Colors[imgui.Col.SliderGrabActive] = Colors.primaryHover
    style.Colors[imgui.Col.Button] =  Colors.backgroundLight
    style.Colors[imgui.Col.ButtonHovered] = Colors.border
    style.Colors[imgui.Col.ButtonActive] = Colors.backgroundDark
    style.Colors[imgui.Col.Header] = Colors.primary
    style.Colors[imgui.Col.HeaderHovered] = Colors.primaryHover
    style.Colors[imgui.Col.HeaderActive] = Colors.secondary
    style.Colors[imgui.Col.Separator] = Colors.border
    style.Colors[imgui.Col.SeparatorHovered] = Colors.border
    style.Colors[imgui.Col.SeparatorActive] = Colors.primary
    style.Colors[imgui.Col.ResizeGrip] = Colors.backgroundLight
    style.Colors[imgui.Col.ResizeGripHovered] = Colors.border
    style.Colors[imgui.Col.ResizeGripActive] = Colors.primary
    style.Colors[imgui.Col.Tab] = Colors.backgroundLight
    style.Colors[imgui.Col.TabHovered] = Colors.primary
    style.Colors[imgui.Col.TabActive] = Colors.secondary
    style.Colors[imgui.Col.TabUnfocused] = Colors.backgroundLight
    style.Colors[imgui.Col.TabUnfocusedActive] = Colors.backgroundDark
    style.Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(Colors.primary.x, Colors.primary.y, Colors.primary.z, 0.35)
    style.Colors[imgui.Col.NavHighlight] = Colors.primary
end

imgui.OnInitialize(applyStyles)

-- ImGui Rendering
imgui.OnFrame(function() return UI.showMenu[0] end, function()
    local resX, resY = getScreenResolution()
    imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(UI.menuSize, imgui.Cond.FirstUseEver)
    
    if imgui.Begin("Elite Menu (" .. VERSION .. ")", UI.showMenu, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize) then
        imgui.BeginChild("MainContent", imgui.ImVec2(0, 0), false)
        
        imgui.BeginChild("Sidebar", imgui.ImVec2(140, 0), true)
        -- Use the ordered module list to display sidebar items
        for _, name in ipairs(Modules.order) do
            local isSelected = UI.currentModule == name
            imgui.PushStyleColor(imgui.Col.Button, isSelected and Colors.primary or Colors.backgroundDark)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, isSelected and Colors.primaryHover or Colors.border)
            imgui.PushStyleColor(imgui.Col.ButtonActive, isSelected and Colors.secondary or Colors.backgroundLight)
            imgui.PushStyleColor(imgui.Col.Text, isSelected and Colors.text or Colors.textDim)
            
            if imgui.Button(name, imgui.ImVec2(120, 30)) then
                UI.currentModule = name
            end
            
            imgui.PopStyleColor(4)
            imgui.Dummy(imgui.ImVec2(0, 1))
        end
        imgui.SetCursorPos(imgui.ImVec2(10, imgui.GetWindowHeight() - 25))
        imgui.TextColored(Colors.textDim, "© " .. AUTHOR)
        imgui.EndChild()
        
        imgui.SameLine()
        imgui.BeginChild("Content", imgui.ImVec2(0, 0), true)
        local module = Modules.list[UI.currentModule]
        if module then
            local headerWidth = imgui.GetContentRegionAvail().x
            imgui.TextColored(Colors.text, module.name)
            
            if module.name == "Auto Set Freq" then
                imgui.SameLine(headerWidth - 25)
                local newActive = UIComponents:DrawToggle(Config.configs.AutoSetFreq.data.Settings.active)
                if newActive ~= Config.configs.AutoSetFreq.data.Settings.active then
                    Config.configs.AutoSetFreq.data.Settings.active = newActive
                    Config:save("AutoSetFreq")
                    local status = newActive and "Activated" or "Deactivated"
                    local color = newActive and ChatColors.success or ChatColors.error
                    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoSetFreq .. "AutoSetFreq {FFFFFF}has been " .. color .. status, 0xFFFFFF)
                end
            elseif module.name == "Auto Vester" then
                imgui.SameLine(headerWidth - 25)
                local newActive = UIComponents:DrawToggle(Config.configs.AutoVester.data.Settings.active)
                if newActive ~= Config.configs.AutoVester.data.Settings.active then
                    Config.configs.AutoVester.data.active = newActive
                    Config:save("AutoVester")
                    local status = newActive and "Activated" or "Deactivated"
                    local color = newActive and ChatColors.success or ChatColors.error
                    sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoVester .. "AutoVester {FFFFFF}has been " .. color .. status, 0xFFFFFF)
                end
            end
            
            imgui.Separator()
            module.render()
        end
        imgui.EndChild()
        imgui.EndChild()
    end
    imgui.End()
end)

-- Module Render Functions
function renderHome()
    imgui.TextColored(Colors.text, "Welcome to the Elite Menu")
    imgui.TextColored(Colors.textDim, "Select a module from the sidebar to manage your gang activities.")
    imgui.Dummy(imgui.ImVec2(0, 20))
    
    imgui.TextColored(Colors.primary, "Available Modules:")
    imgui.Dummy(imgui.ImVec2(0, 5))
    
    imgui.Columns(2, "ModuleColumns", false)
    imgui.TextColored(Colors.text, "Auto Set Freq")
    imgui.TextColored(Colors.textDim, "Automatically sets radio frequency")
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.TextColored(Colors.text, "Auto Vester")
    imgui.TextColored(Colors.textDim, "Automatically vests gang members")
    imgui.NextColumn()
    imgui.TextColored(Colors.text, "High Command")
    imgui.TextColored(Colors.textDim, "Manage high command activities")
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.TextColored(Colors.text, "Miscellaneous")
    imgui.TextColored(Colors.textDim, "Additional utilities")
    imgui.Columns(1)
    
    imgui.Dummy(imgui.ImVec2(0, 20))
    if UIComponents:DrawButton("Open Settings", imgui.ImVec2(120, 30), true) then
        UI.currentModule = "Settings"
    end
end

function renderAutoSetFreq()
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Current Frequency")
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.FrameBg, Colors.backgroundDark)
    imgui.PushItemWidth(100)
    imgui.InputText("##Frequency", UI.freqBuffer, 32, imgui.InputTextFlags.ReadOnly)
    imgui.PopItemWidth()
    imgui.PopStyleColor()
    
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 5))
    
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Frequency Priority")
    imgui.SameLine()
    
    imgui.PushStyleColor(imgui.Col.Button, UI.priorityBuffer[0] == 1 and Colors.primary or Colors.backgroundLight)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, Config.configs.AutoSetFreq.data.Settings.priority == 1 and Colors.primaryHover or Colors.border)
    if imgui.Button("Primary (1)", imgui.ImVec2(120, 0)) then
        AutoSetFreq:setPriority(1)
    end
    imgui.PopStyleColor(2)
    
    imgui.SameLine(0, 10)
    imgui.PushStyleColor(imgui.Col.Button, UI.priorityBuffer[0] == 2 and Colors.primary or Colors.backgroundLight)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, Config.configs.AutoSetFreq.data.Settings.priority == 2 and Colors.primaryHover or Colors.border)
    if imgui.Button("Secondary (2)", imgui.ImVec2(120, 0)) then
        AutoSetFreq:setPriority(2)
    end
    imgui.PopStyleColor(2)
    
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 5))
    
    imgui.TextColored(Colors.text, "About:")
    imgui.SameLine()
    imgui.TextColored(Colors.textDim, "Sets the frequency automatically.")
    
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.TextColored(Colors.text, "Commands:")
    imgui.Bullet() imgui.TextColored(Colors.success, "/asf") imgui.SameLine() imgui.TextColored(Colors.textDim, "Toggle the mod ON/OFF")
    imgui.Bullet() imgui.TextColored(Colors.success, "/asfset [1/2]") imgui.SameLine() imgui.TextColored(Colors.textDim, "Toggle Prioritizing 1st or 2nd Freq")
end

function renderAutoVester()
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.TextColored(Colors.text, "Auto Accept Vest")
    imgui.SameLine(imgui.GetContentRegionAvail().x - 25)
    local newAutoAccept = UIComponents:DrawToggle(Config.configs.AutoVester.data.Settings.autoAccept)
    if newAutoAccept ~= Config.configs.AutoVester.data.Settings.autoAccept then
        AutoVester:toggleAccept()
    end
    
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.Separator()

    -- Armor thresholds in a compact layout
    imgui.Columns(2, "ArmorColumns", false)
    
    -- Column 1: Commands 
    imgui.TextColored(Colors.primary, "Command Settings")
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Auto Vest Command")
    imgui.PushItemWidth(100)
    imgui.InputText("##VestCommand", UI.vestCommandBuffer, 32)
    imgui.PopItemWidth()
    
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Auto Accept Command")
    imgui.PushItemWidth(100)
    imgui.InputText("##AcceptCommand", UI.acceptCommandBuffer, 32)
    imgui.PopItemWidth()
    
    if UIComponents:DrawButton("Save Commands", imgui.ImVec2(120, 0), true) then
        local oldVestCmd = Config.configs.AutoVester.data.Settings.vestCommand
        local oldAcceptCmd = Config.configs.AutoVester.data.Settings.acceptCommand
        Config.configs.AutoVester.data.Settings.vestCommand = ffi.string(UI.vestCommandBuffer)
        Config.configs.AutoVester.data.Settings.acceptCommand = ffi.string(UI.acceptCommandBuffer)
        Config:save("AutoVester")
        
        sampUnregisterChatCommand(oldVestCmd)
        sampUnregisterChatCommand(oldAcceptCmd)
        sampRegisterChatCommand(Config.configs.AutoVester.data.Settings.vestCommand, function() AutoVester:toggle() end)
        sampRegisterChatCommand(Config.configs.AutoVester.data.Settings.acceptCommand, function() AutoVester:toggleAccept() end)
        sampAddChatMessage(ChatColors.main .. "[EliteMenu] " .. ChatColors.autoVester .. "AutoVester {FFFFFF}Commands updated", 0xFFFFFF)
    end
    
    imgui.NextColumn()
    
    -- Column 2: Armor thresholds
    imgui.TextColored(Colors.primary, "Armor Thresholds")
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Vest others if their Armor is below:")
    
    if UIComponents:DrawButton("-", imgui.ImVec2(20, 20), false) then
        if UI.vestArmorThresholdBuffer[0] > 0 then
            UI.vestArmorThresholdBuffer[0] = UI.vestArmorThresholdBuffer[0] - 1
            Config.configs.AutoVester.data.vestArmorThreshold = UI.vestArmorThresholdBuffer[0]
            Config:save("AutoVester")
        end
    end
    
    imgui.SameLine(0, 2)
    imgui.PushItemWidth(40)
    imgui.PushStyleColor(imgui.Col.FrameBg, Colors.backgroundDark)
    imgui.InputInt("##VestArmorThreshold", UI.vestArmorThresholdBuffer, 0, 0, imgui.InputTextFlags.ReadOnly)
    imgui.PopStyleColor()
    imgui.PopItemWidth()
    
    imgui.SameLine(0, 2)
    if UIComponents:DrawButton("+", imgui.ImVec2(20, 20), false) then
        if UI.vestArmorThresholdBuffer[0] < 50 then
            UI.vestArmorThresholdBuffer[0] = UI.vestArmorThresholdBuffer[0] + 1
            Config.configs.AutoVester.data.Settings.vestArmorThreshold = UI.vestArmorThresholdBuffer[0]
            Config:save("AutoVester")
        end
    end

    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Accept vest if my armor is below:")
    
    if UIComponents:DrawButton("-", imgui.ImVec2(20, 20), false) then
        if UI.acceptArmorThresholdBuffer[0] > 0 then
            UI.disposeArmorThresholdBuffer[0] = UI.acceptArmorThresholdBuffer[0] - 1
            Config.configs.AutoVester.data.Settings.acceptArmorThreshold = UI.acceptArmorThresholdBuffer[0]
            Config:save("AutoVester")
        end
    end
    
    imgui.SameLine(0, 2)
    imgui.PushItemWidth(40)
    imgui.PushStyleColor(imgui.Col.FrameBg, Colors.backgroundDark)
    imgui.InputInt("##AcceptArmorThreshold", UI.acceptArmorThresholdBuffer, 0, 0, imgui.InputTextFlags.ReadOnly)
    imgui.PopStyleColor()
    imgui.PopItemWidth()
    
    imgui.SameLine(0, 2)
    if UIComponents:DrawButton("+", imgui.ImVec2(20, 20), false) then
        if UI.acceptArmorThresholdBuffer[0] < 50 then
            UI.acceptArmorThresholdBuffer[0] = UI.acceptArmorThresholdBuffer[0] + 1
            Config.configs.AutoVester.data.Settings.acceptArmorThreshold = UI.acceptArmorThresholdBuffer[0]
            Config:save("AutoVester")
        end
    end
    
    imgui.Columns(1)
    
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.Separator()
    
    imgui.TextColored(Colors.primary, "Gang Settings")
    imgui.TextColored(Colors.textDim, "Select which gangs to automatically vest")
    imgui.Dummy(imgui.ImVec2(0, 5))
    
    -- Display gangs in 2 columns
    imgui.Columns(2, "GangColumns", false)

    -- Calculate how many gangs to show per column
    local totalGangs = #GangOrder
    local gangsPerColumn = math.ceil(totalGangs / 2)

    -- First column
    for i = 1, gangsPerColumn do
        local gangName = GangOrder[i]
        local gangInfo = Gangs[gangName]
        
        imgui.TextColored(gangInfo.color, gangName)
        imgui.SameLine(imgui.GetContentRegionAvail().x - 25)
        
        local isWhitelisted = Config.configs.AutoVester.data.WhitelistedGangs[i]
        local newWhitelisted = UIComponents:DrawToggle(isWhitelisted)
        if newWhitelisted ~= isWhitelisted then
            Config.configs.AutoVester.data.WhitelistedGangs[i] = newWhitelisted
            Config:save("AutoVester")
        end
    end

    imgui.NextColumn()

    -- Second column
    for i = gangsPerColumn + 1, totalGangs do
        local gangName = GangOrder[i]
        local gangInfo = Gangs[gangName]
        
        imgui.TextColored(gangInfo.color, gangName)
        imgui.SameLine(imgui.GetContentRegionAvail().x - 25)
        
        local isWhitelisted = Config.configs.AutoVester.data.WhitelistedGangs[i]
        local newWhitelisted = UIComponents:DrawToggle(isWhitelisted)
        if newWhitelisted ~= isWhitelisted then
            Config.configs.AutoVester.data.WhitelistedGangs[i] = newWhitelisted
            Config:save("AutoVester")
        end
    end

    imgui.Columns(1)

    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 5))
    
    imgui.TextColored(Colors.text, "About:") imgui.SameLine() imgui.TextColored(Colors.textDim, "Automatically vests gang members and handles vest acceptance.")
    imgui.Dummy(imgui.ImVec2(0, 5))
    imgui.TextColored(Colors.text, "Commands:")
    imgui.Bullet() imgui.TextColored(Colors.success, "/" .. Config.configs.AutoVester.data.Settings.vestCommand) imgui.SameLine() imgui.TextColored(Colors.textDim, "Toggle auto vesting ON/OFF")
    imgui.Bullet() imgui.TextColored(Colors.success, "/" .. Config.configs.AutoVester.data.Settings.acceptCommand) imgui.SameLine() imgui.TextColored(Colors.textDim, "Toggle auto accept vest ON/OFF")
end

function renderAutoGunner()
    -- Add centered "Feature Coming Soon!" text
    local comingSoonText = "Feature Coming Soon!"
    local textSize = imgui.CalcTextSize(comingSoonText)
    local windowSize = imgui.GetWindowSize()
    
    -- Calculate the centered position
    local centerX = (windowSize.x - textSize.x) / 2
    local centerY = (windowSize.y - textSize.y) / 2
    
    -- Set the cursor position to the center
    imgui.SetCursorPos(imgui.ImVec2(centerX, centerY))
    
    -- Draw the text with a yellowish color
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 0.8, 0, 1))
    imgui.Text(comingSoonText)
    imgui.PopStyleColor()
    
    imgui.EndChild()
end

function renderMisc()
    -- Add centered "Feature Coming Soon!" text
    local comingSoonText = "Feature Coming Soon!"
    local textSize = imgui.CalcTextSize(comingSoonText)
    local windowSize = imgui.GetWindowSize()
    
    -- Calculate the centered position
    local centerX = (windowSize.x - textSize.x) / 2
    local centerY = (windowSize.y - textSize.y) / 2
    
    -- Set the cursor position to the center
    imgui.SetCursorPos(imgui.ImVec2(centerX, centerY))
    
    -- Draw the text with a yellowish color
    imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1, 0.8, 0, 1))
    imgui.Text(comingSoonText)
    imgui.PopStyleColor()
    
    imgui.EndChild()
end

function renderSettings()
    -- Menu Hotkey Settings
    imgui.TextColored(Colors.primary, "Menu Hotkey Settings")
    
    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Current Menu Hotkey:")
    imgui.SameLine()
    
    -- Display current hotkey
    imgui.PushStyleColor(imgui.Col.FrameBg, Colors.backgroundDark)
    imgui.PushItemWidth(120)
    imgui.InputText("##MenuKey", UI.menuKeyBuffer, 32, imgui.InputTextFlags.ReadOnly)
    imgui.PopItemWidth()
    imgui.PopStyleColor()
    
    imgui.SameLine()
    
    -- Change hotkey button
    if UIComponents:DrawButton(UI.waitingForKey and "Press any key..." or "Change", imgui.ImVec2(120, 0), true) then
        UI.waitingForKey = not UI.waitingForKey
    end
    
    imgui.TextColored(Colors.textDim, "Click 'Change' and press any key to set a new menu hotkey.")
    
    imgui.Dummy(imgui.ImVec2(0, 10))
    
    -- About Section
    imgui.Separator()
    imgui.TextColored(Colors.primary, "About EliteMenu")
    imgui.TextWrapped("EliteMenu is a comprehensive tool designed for gang members.")

    imgui.Dummy(imgui.ImVec2(0, 10))
    
    imgui.TextColored(Colors.text, "Version: ") 
    imgui.SameLine()
    imgui.TextColored(Colors.textDim, VERSION)
    
    imgui.TextColored(Colors.text, "Author: ") 
    imgui.SameLine()
    imgui.TextColored(Colors.textDim, AUTHOR)

    imgui.AlignTextToFramePadding()
    imgui.TextColored(Colors.text, "Discord: ")
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.FrameBg, Colors.backgroundDark)
    imgui.PushItemWidth(70)
    imgui.InputText("##DiscordUser", imgui.new.char[32]("x_luc1f3r"), 32, imgui.InputTextFlags.ReadOnly)
    imgui.PopItemWidth()
    imgui.PopStyleColor()
end

-- Utility function to check if a table contains a value
function table.contains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Utility function to remove a value from a table
function table.removeValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            table.remove(tbl, i)
            return
        end
    end
end