--[[
    Automatic error reporting

    An better way to handle errors: send them to a server instead of waiting for players to report

    This library was initially created to address gm_construct_13_beta issues but evolved to a small
    standalone solution.

    Warning! Non halting errors aren't reported!

    ---------------------------

    Usage example:

    -- Automatic error reporting
    timer.Simple(0, function()
        http.Fetch("https://raw.githubusercontent.com/Xalalau/SandEv/main/lua/sandev/init/sub/sh_error.lua", function(errorAPI)
            RunString(errorAPI)
            ErrorAPI:RegisterAddon(
                "my_workshop_addon",
                "https://myendpoint.com",
                { "prefix_", "somefile.lua" },
                "1231231231"
            )
        end)
    end)

    ---------------------------

    Data to be sent:
        addon        an arbitrary name given to identify the buggy addon
        msg          a brief 1 line message containing a hint as to why the error occurred
        map          knowing the map helps to understand which parts of the code were running
        stack        the text that appears in the console showing the function calls that created the bug
        quantity     how many times the error occurred in the current match
        versionDate  the addon gma timestamp, used to ignore reports from older addon releases

    This information is extremely basic and does not identify users in any way, therefore
    it's collected under the General Data Protection Regulation (GDPR) Legitimate Interest
    legal basis.

    By the way, a system to receive the reports is needed, so I created an small website people can use
    as a start point: https://github.com/Xalalau/gerror



    You can currently see it running here: https://gerror.xalalau.com/

    - Xalalau Xubilozo
]]

-- Vars

local version = 1

local printResponses = false

ErrorAPI_ReportError = ErrorAPI_ReportError or debug.getregistry()[1]

_G["ErrorAPIV" .. version] = _G["ErrorAPIV" .. version] or {
    registered = {
        --[[
        {
            -- User set:
                boolean enabled = if the api is sending errors, -- Usefull while developing
                string  databaseName = SQL table name,
                string  wsid = OPTIONAL addon wsid,
                string  url = server url,
                table   patterns = { string error pattern, ... }, -- At least 3 letters, a unique part of your addon Lua paths
            -- Internal:
                string  versionDate = the time when the addon was las updated
                boolean isUrlOnline = if the url is online,
                table   list = {
                    [string error ID] = { 
                        string error,    -- The main error message, 1 line
                        string stack,    -- Full error stack, multiple lines
                        int    quantity, -- Error count
                        bool   reporting -- If the error is waiting to be sent
                    }, ...
                }
        }, ...
        ]]
    }
}

local ErrorAPI = _G["ErrorAPIV" .. version]

-- Check if the registered URLs are online
local function AutoCheckURL(addonData)
    local function CheckURL()
        http.Post(
            addonData.url .. "/ping.php",
            {},
            function(response)
                if printResponses then
                    print(response)
                end

                addonData.isUrlOnline = true
            end,
            function()
                addonData.isUrlOnline = false
                print("ErrorAPI: WARNING!!! Offline url: " .. addonData.url)
            end
        )
    end

    timer.Simple(0, function() -- Avoids calling http too early
        CheckURL()
    end)
    timer.Create(addonData.url, 600, 0, function()
        CheckURL()
    end)
end

-- Register an addon to send errors
--[[
    Arguments:
        string databaseName = database name,
        string url = server url,
        table  patterns = { string error pattern, ... }, -- At least 3 letters, a unique part of your addon Lua paths
        string wsid = OPTIONAL addon wsid, -- Used to automatically generate addonData.versionDate. If not provided, addonData.versionDate
                                           -- will be set as 0, but you can manually change this value after registering the addon

    return:
        success = table addonData -- Structure explained on ErrorAPI.registered declaration
        fail = nil
]]
function ErrorAPI:RegisterAddon(databaseName, url, patterns, wsid, allowLegacyAddon)
    local upInfo = debug.getinfo(2)
    local errorMsgStart = "Failed to register database " .. databaseName .. "."

    -- Block extracted addons
    if not allowLegacyAddon and string.find(upInfo.source, "addons/", 1, true) then
        print("ErrorAPI: " .. errorMsgStart .. " Legacy addon blocked. (Set allowLegacyAddon parameter to true to allow it)")
        return
    end

    -- Strongly check the arguments to avoid errors
    if not url then print("ErrorAPI: " .. errorMsgStart .. " Missing url.") return end
    if not patterns then print("ErrorAPI: " .. errorMsgStart .. " Missing patterns.") return end
    if not databaseName then print("ErrorAPI: " .. errorMsgStart .. " Missing databaseName.") return end
    if not wsid then print("ErrorAPI: " .. errorMsgStart .. " Missing wsid (optional argument).") end
    if databaseName == "" then print("ErrorAPI: " .. errorMsgStart .. " databaseName can't be an empty string.") return end
    if wsid == "" then print("ErrorAPI: " .. errorMsgStart .. " wsid can't be an empty string.") return end
    if not isstring(url) then print("ErrorAPI: " .. errorMsgStart .. " url must be a string.") return end
    if not isstring(databaseName) then print("ErrorAPI: " .. errorMsgStart .. " databaseName must be a string.") return end
    if not istable(patterns) then print("ErrorAPI: " .. errorMsgStart .. " patterns must be a table.") return end
    if wsid and not isstring(wsid) then print("ErrorAPI: " .. errorMsgStart .. " wsid must be a string.") return end
    if not string.find(url, "http", 1, true) then print("ErrorAPI: " .. errorMsgStart .. " Please write the url in full") return end

    local count = 1
    for k, v in SortedPairs(patterns) do
        if isstring(k) or k ~= count or not isstring(v) then print("ErrorAPI: " .. errorMsgStart .. " patterns table must contain only strings.") return end
        if string.len(v) <= 3 then print("ErrorAPI: " .. errorMsgStart .. " patterns can't be less than 3 characters.") return end
        count = count + 1
    end

    local versionDate = 0
    if wsid then
        for k, addonInfo in ipairs(engine.GetAddons()) do
            if addonInfo.wsid == wsid then
                versionDate = addonInfo.updated
                break
            end
        end
    end
    if versionDate == 0 then
        print("ErrorAPI: Addon gma not found or wsid not provided for database " .. databaseName .. ". addonData.versionDate will be set as 0.")
        return
    end

    -- Unregister older instances of this entry
    if next(ErrorAPI.registered) then
        for k, addonData in ipairs(ErrorAPI.registered) do
            local remove = false

            if wsid then
                if addonData.wsid == wsid then
                    remove = true
                end
            else
                if addonData.databaseName == databaseName then
                    remove = true
                end
            end

            if remove then
                print("ErrorAPI: An old entry for database " .. databaseName .. " has been removed from the API.")
                table.remove(ErrorAPI.registered, k)
                break
            end
        end
    end

    -- Register the addon
    local addonData = {
        enabled = true,
        databaseName = databaseName,
        wsid = wsid,
        url = url,
        patterns = patterns,
        versionDate = versionDate,
        isUrlOnline = nil,
        list = {}
    }

    AutoCheckURL(addonData)

    table.insert(ErrorAPI.registered, addonData)

    print("ErrorAPI: database " .. databaseName .. " registered (wsid " .. wsid .. ")")

    return addonData
end

-- Send script error to server
local function Report(addonData, msg, delay)
    local parameters = {
        realm = SERVER and "SERVER" or "CLIENT",
        databaseName = addonData.databaseName,
        msg = msg,
        stack = addonData.list[msg].stack,
        map = game.GetMap(),
        quantity = tostring(addonData.list[msg].quantity),
        versionDate = tostring(addonData.versionDate)
    }

    -- Force "reporting" to true
    addonData.list[msg].reporting = true

    -- Send the error as it is, so we always register it
    http.Post(addonData.url .. "/add.php", parameters, function(resp) if printResponses then print(resp) end end)

    -- Finish the steps if no delay is provided
    if delay == 0 then
        addonData.list[msg].reporting = false
    -- Send the error again if the error quantity increases after a given delay
    -- The delay is used to protect the webserver from overloading with too many requests
    else
        local initialQuantity = addonData.list[msg].quantity

        timer.Simple(delay, function()
            addonData.list[msg].reporting = false

            timer.Simple(0.1, function() -- Use the next initial Post if the error is being generated constantly
                if addonData.list[msg].reporting == false then
                    if initialQuantity ~= addonData.list[msg].quantity then
                        http.Post(addonData.url .. "/add.php", parameters, function(resp) if printResponses then print(resp) end end)
                    end
                end
            end)
        end)
    end
end

-- Deal with recurring errors
local function Update(addonData, msg)
    -- Increase the error counting
    addonData.list[msg].quantity = addonData.list[msg].quantity + 1

    -- Report the current error count if it's not already waiting to be sent
    if not addonData.list[msg].reporting then
        Report(addonData, msg, 10)
    end
end

-- Decide if a script error should be reported
local function Scan(addonData, msg)
    -- Initialize the error status as "reporting", so it can increase the count while the scan runs
    addonData.list[msg] = {
        quantity = 1,
        reporting = true
    }

    -- Scan the path (once per pattern per registered addon)
    for k, pattern in ipairs(addonData.patterns) do
        if string.find(msg, pattern, nil, true) then -- Patterns feature is actually turned off for performance
            addonData.list[msg].stack = debug.traceback()
            Report(addonData, msg, 0)
            break
        end
    end

    -- Set a final stage for the error if the scan found nothing
    if addonData.list[msg].stack == nil then
        addonData.list[msg] = false
    end
end

-- Detour
debug.getregistry()[1] = function(msg, ...)
    if next(ErrorAPI.registered) then
        for k, addonData in ipairs(ErrorAPI.registered) do
            if addonData.enabled and addonData.isUrlOnline then
                if addonData.list[msg] == nil then
                    pcall(Scan, addonData, msg)
                elseif addonData.list[msg] ~= false then
                    pcall(Update, addonData, msg)
                end
            end
        end
    end

    return ErrorAPI_ReportError(msg, ...)
end

-- -------------------------------------------------
-- -------------------------------------------------
-- -------------------------------------------------

ErrorAPIV1:RegisterAddon(
    "remover_advanced",
    "https://gerror.xalalau.com",
    { "advr_", "removeradvanced.lua" },
    "2853674790"
)