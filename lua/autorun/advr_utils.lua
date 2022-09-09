function ADVR_GetAllEnts(pos, radius)
    local entsList = {}

    local foundEnts
    if pos and radius then
        foundEnts = ents.FindInSphere(pos, radius)
    else
        foundEnts = ents.GetAll()
    end

    for k, ent in ipairs(foundEnts) do
        if not ent:IsValid() then continue end
        if ent:EntIndex() == -1 then continue end
        if ADVRBlacklist[ent:GetClass()] then continue end
        if not GetConVar("advr_allow_weapons"):GetBool() and ent:IsWeapon() then continue end
        if not GetConVar("advr_allow_no_model"):GetBool() and (ent:GetModel() == "" or ent:GetModel() == nil) then continue end

        local constraineds = {}

        if SERVER and ent:IsConstrained() then
            local constrainedEntities = constraint.GetAllConstrainedEntities(ent)

            for _, cEnt in pairs(constrainedEntities) do
                table.insert(constraineds, cEnt:EntIndex())
            end
        end

        local entInfo = {
			index = ent:EntIndex(),
			pos = ent:GetPos(),
			angles = ent:GetAngles(),
			normal = ent:GetUp(),
			class = ent.GetClass and ent:GetClass() or "",
			name = ent.GetName and ent:GetName() or "",
			model = ent.GetModel and ent:GetModel() or "",
            constraineds = constraineds
		}

        if entInfo.model ~= "" and string.GetExtensionFromFilename(entInfo.model) == "mdl" then
            entInfo.isMissing = not file.Exists(entInfo.model, "GAME")
        end

		table.insert(entsList, entInfo)
	end

    return entsList
end


-- Diretamente do remover tool do GMod
function ADVR_RemoveEnt(ent)
	if not IsValid(ent) or ent:IsPlayer() then return false end

	if CLIENT then return true end

    -- Remove all constraints (this stops ropes from hanging around)
    constraint.RemoveAll(ent)

    -- Remove it properly in 1 second
    timer.Simple(1, function()
        if IsValid(ent) then
            ent:Remove()
        end
    end)

    -- Make it non solid
    ent:SetNotSolid(true)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetNoDraw(true)

    -- Send Effect
    local ed = EffectData()
        ed:SetOrigin(ent:GetPos())
        ed:SetEntity(ent)
    util.Effect("entity_remove", ed, true, true)

    return true
end


-- Removo a entidade e todos os penduricalhos
function ADVR_RemoveEntWithConstraineds(ent)
    if not IsValid(ent) or ent:IsPlayer() then return false end

    if CLIENT then return true end

    local constrainedEntities = constraint.GetAllConstrainedEntities(ent)

    for k, cEnt in pairs(constrainedEntities) do
        ADVR_RemoveEnt(cEnt)
    end

    return true
end