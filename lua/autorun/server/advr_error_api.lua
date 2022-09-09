--[[
   Automatic error reporting

   An efficient way to handle errors: send them to a server instead of waiting for players to report

   This library is special, I made it disconnected from gm_construct_13_beta so you can copy the
   code easily. There are also checks for it to only be started once and for all addons.

   The errors are listed here: https://gerror.xalalau.com/
   This is the gerror's source code: https://github.com/Xalalau/gerror

   Detailing the data to be sent:
        addon        an arbitrary name given to identify the buggy addon
        msg          a brief 1 line message containing a hint as to why the error occurred
        map          knowing the map helps to understand which parts of the code were running
        stack        the text that appears in the console showing the function calls that created the bug
        quantity     how many times the error occurred in the current match
        versionDate  the addon gma timestamp, used to ignore reports from older addon releases

    This information is extremely basic and does not identify users in any way, therefore
    I collect it under the General Data Protection Regulation (GDPR) Legitimate Interest
    legal basis.

    - Xalalau Xubilozo
]]

ErrorAPI = ErrorAPI or {
    registered = {
        --[[
        {
            -- User set:
            enabled = boolean if the api is sending errors, -- Usefull while developing
            sqlTable = string SQL table name,
            wsid = string addon wsid,
            url = string server url,
            patterns = { string term to look for in the path of the file with errors, ... }, -- At least 3 letters per pattern
            -- Internal:
            isUrlOnline = boolean if the url is online,
            list = { [string error ID] = { string error, int quantity, bool reporting }, ... }
        }, ...
        ]]
    }
}

-- Detour management

ErrorAPI_ReportError = ErrorAPI_ReportError or debug.getregistry()[1]

-- Check if the registered URLs are online
local function AutoCheckURL(addonData)
    local function CheckURL()
        http.Post(
            addonData.url .. "/ping.php",
            {},
            function(response)
                addonData.isUrlOnline = true
            end,
            function()
                addonData.isUrlOnline = false
            end
        )
    end

    CheckURL()
    timer.Create(addonData.url, 600, 0, function()
        CheckURL()
    end)
end

-- Register an addon to send errors
--[[
    Arguments:
        sqlTable = string SQL table name,
        wsid = string addon wsid,
        url = string server url,
        patterns = { string term to look for in the path of the file with errors, ... }, -- At least 3 letters per pattern

    return:
        success = table addonData -- Structure explained on ErrorAPI.registered declaration
        fail = nil
]]
function ErrorAPI:RegisterAddon(sqlTable, wsid, url, patterns)
    -- Strongly check the arguments to avoid errors
    if not wsid or
       not url or
       not patterns or
       not sqlTable or
       not isstring(wsid) or
       not isstring(url) or
       not isstring(sqlTable) or
       not istable(patterns) or
       wsid == "" or
       sqlTable == "" or
       not string.find(url, "http", 1, true)
       then
        print("ErrorAPI: Malformed arguments.")
        return
    end

    local count = 1
    for k, v in SortedPairs(patterns) do
        if isstring(k) or k ~= count or not isstring(v) or string.len(v) <= 3 then
            print("ErrorAPI: Malformed patterns.")
            return
        end
        count = count + 1
    end

    local versionDate = 0
    for k, addonInfo in ipairs(engine.GetAddons()) do
        if addonInfo.wsid == wsid then
            versionDate = addonInfo.updated
            break
        end
    end
    if versionDate == 0 then
        print("ErrorAPI: Addon gma not found. Check the provided wsid.")
        return
    end

    if next(ErrorAPI.registered) then
        for k, addonData in ipairs(ErrorAPI.registered) do
            if addonData.wsid == wsid then
                print("ErrorAPI: An old " .. sqlTable .. " entry has been removed from the API.")
                table.remove(ErrorAPI.registered, k)
                break
            end
        end
    end

    local addonData = {
        enabled = true,
        sqlTable = sqlTable,
        wsid = wsid,
        url = url,
        patterns = patterns,
        versionDate = versionDate,
        isUrlOnline = nil,
        list = {}
    }

    AutoCheckURL(addonData)

    table.insert(ErrorAPI.registered, addonData)

    print("ErrorAPI: " .. sqlTable .. " registered.")

    return addonData
end

-- Send script error to server
local function UploadError(addonData, msg, delay)
    local parameters = {
        sqlTable = addonData.sqlTable,
        msg = msg,
        stack = addonData.list[msg].stack,
        map = game.GetMap(),
        quantity = tostring(addonData.list[msg].quantity),
        versionDate = tostring(addonData.versionDate)
    }

    local function SetCooldown() -- Protect the server
        timer.Create(msg, delay, 1, function()
            addonData.list[msg].reporting = false
        end)
    end

    timer.Create(msg, 0.2, 1, function() -- Accumulate some errors if they are repeating
        http.Post(
            addonData.url .. "/add.php",
            parameters,
            function(response)
                SetCooldown()
            end,
            function(response)
                SetCooldown()
            end
        )
    end)
end

-- Decide if a script error should be reported
local function Report(addonData, msg, ...)
    if addonData.list[msg] and addonData.list[msg].reporting then
        addonData.list[msg].quantity = addonData.list[msg].quantity + 1
        return
    end

    for k, pattern in ipairs(addonData.patterns) do
        if string.find(msg, pattern) then
            if not addonData.list[msg] then
                addonData.list[msg] = {
                    stack = debug.traceback(),
                    quantity = 1,
                    reporting = true
                }
                UploadError(addonData, msg, 0)
            else
                addonData.list[msg].quantity = addonData.list[msg].quantity + 1
                addonData.list[msg].reporting = true
                UploadError(addonData, msg, 10)
            end

            break
        end
    end
end

-- Detour
debug.getregistry()[1] = function(...)
    if next(ErrorAPI.registered) then
        for k, addonData in ipairs(ErrorAPI.registered) do
            if addonData.enabled and addonData.isUrlOnline then
                pcall(Report, addonData, ...)
            end
        end
    end

    return ErrorAPI_ReportError(...)
end




-- REGISTERING REMOVER ADVANCED
ErrorAPI:RegisterAddon("remover_advanced", "2853674790", "https://gerror.xalalau.com", { "advr_", "removeradvanced.lua" })

