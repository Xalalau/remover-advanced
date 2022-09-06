--[[
		Created by: M4n0Cr4zy
		Colaborator: Xalalau Xubilozo 
		Special thanks to: Nodge 
]]

util.AddNetworkString("m4n0cr4zy.Remove")
util.AddNetworkString("m4n0cr4zy.Remove_With_Constraineds")
util.AddNetworkString("m4n0cr4zy.Look")
util.AddNetworkString("m4n0cr4zy.Teleport")
util.AddNetworkString("m4n0cr4zy.Change_Blacklist")
util.AddNetworkString("m4n0cr4zy.Highlight")
util.AddNetworkString("m4n0cr4zy.Highlight_Sv_Only_Ent")
util.AddNetworkString("m4n0cr4zy.Remove_Highlight_Sv_Only_Ent")
util.AddNetworkString("m4n0cr4zy.Highlight_Update_Sv_Only_Ent_Pos")
util.AddNetworkString("m4n0cr4zy.Remove_Highlight_Cl")

net.Receive("m4n0cr4zy.Remove", function(len, ply)
    if not ply:IsAdmin() then return end

    local entID = net.ReadUInt(32)
    local ent = ents.GetByIndex(entID)

    if not ent:IsValid() then return end

    ADVR_RemoveEnt(ent)
end)

net.Receive("m4n0cr4zy.Remove_With_Constraineds", function(len, ply)
    if not ply:IsAdmin() then return end

    local entID = net.ReadUInt(32)
    local ent = ents.GetByIndex(entID)

    if not ent:IsValid() then return end

    ADVR_RemoveEntWithConstraineds(ent)
end)

net.Receive("m4n0cr4zy.Look", function(len, ply)
    if not ply:IsAdmin() then return end

    local entPos = net.ReadVector()
    local plyEyeTrPos = ply:GetShootPos()

    ply:SetEyeAngles((entPos - plyEyeTrPos):Angle())
end)

net.Receive("m4n0cr4zy.Teleport", function(len, ply)
    if not ply:IsAdmin() then return end

    local entPos = net.ReadVector()
    local plyEyeTrPos = ply:GetShootPos()

    ply:SetEyeAngles(Vector(0, 0, -1):Angle())
    ply:SetPos(entPos)
end)

net.Receive("m4n0cr4zy.Change_Blacklist", function(len, ply)
    if not ply:IsAdmin() then return end

    local class = net.ReadString()
    local isBlacklisted = net.ReadBool()

    ADVR_BlacklistClass(class, isBlacklisted)
end)

local highlightLastPos = {}
net.Receive("m4n0cr4zy.Highlight_Sv_Only_Ent", function(len, ply)
    if not ply:IsAdmin() then return end

    local entID = net.ReadUInt(32)
    local state = net.ReadBool()

    local ent = ents.GetByIndex(entID)

    if not ent:IsValid() then return end

    local timerName = "Highlight_Update_Sv_Only_Ent_Pos_" .. entID

    if state then
        ent:CallOnRemove("ADVR_remove_highlight_" .. entID, function(ent)
            net.Start("m4n0cr4zy.Remove_Highlight_Cl")
                net.WriteUInt(entID, 32)
            net.Broadcast()

            timer.Remove(timerName)
        end)

        timer.Create(timerName, 1, 0, function()
            if not ent:IsValid() then 
                timer.Remove(timerName)
                return
            end

            local curPos = ent:GetPos()

            local sendPos = false
            if not highlightLastPos[entID] or highlightLastPos[entID] ~= curPos then
                sendPos = true
                highlightLastPos[entID] = curPos
            end

            if sendPos then
                net.Start("m4n0cr4zy.Highlight_Update_Sv_Only_Ent_Pos")
                    net.WriteUInt(entID, 32)
                    net.WriteVector(curPos)
                net.Broadcast()
            end
        end)
    else
        ent:RemoveCallOnRemove("ADVR_remove_highlight_" .. entID)
        timer.Remove(timerName)
        highlightLastPos[entID] = nil
    end
end)

net.Receive("m4n0cr4zy.Remove_Highlight_Sv_Only_Ent", function(len, ply)
    if not ply:IsAdmin() then return end

    local entID = net.ReadUInt(32)
    local ent = ents.GetByIndex(entID)

    if not ent:IsValid() then return end

    ent:RemoveCallOnRemove("ADVR_remove_highlight_" .. entID)
    timer.Remove("Highlight_Update_Sv_Only_Ent_Pos_" .. entID)
end)