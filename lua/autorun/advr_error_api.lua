-- Automatic error reporting
timer.Simple(0, function()
    http.Fetch("https://raw.githubusercontent.com/Xalalau/SandEv/main/lua/sandev/init/sub/sh_error.lua", function(errorAPI)
        RunString(errorAPI)
        ErrorAPI:RegisterAddon(
            "remover_advanced",
            "2853674790",
            "https://gerror.xalalau.com",
            { "advr_", "removeradvanced.lua" }
        )
    end)
end)
