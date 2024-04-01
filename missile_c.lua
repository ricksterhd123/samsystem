
--math.randomseed(tonumber(sha256(getRealTime().timestamp), 16)^(1/4))
local function LOSRate(rm, rt, vm, vt)
    local R = {rt[1] - rm[1], rt[2] - rm[2], rt[3] - rm[3]}
    local r = (R[1] ^ 2 + R[2] ^ 2 + R[3] ^ 2) ^ (1 / 2)
    local vcl = {vm[1] - vt[1], vm[2] - vt[2], vm[3] - vt[3]}
    local abVcl = (vcl[1]^2 + vcl[2]^2 + vcl[3]^2) ^ (1 / 2)

    local LOSRate = {}
    for i = 1, 3 do
        LOSRate[i] = r > 0 and ((vt[i] - vm[i]) / r) + (R[i] * abVcl) / r^2 or 0
    end
    return LOSRate
end

local function proportionalNavigation(missile, target, NAV_CONST)
	if not isElement(missile) or not isElement(target) then
		return false
	end

    local playerPosition = Vector3(getElementPosition(target))
    local playerVelocity = Vector3(getElementVelocity(target))
    local missilePosition = Vector3(getElementPosition(missile))
    local missileVelocity = Vector3(getElementVelocity(missile))
    local closingVelocity = missileVelocity - playerVelocity
    local x, y, z = missilePosition:getX(), missilePosition:getY(), missilePosition:getZ()
    local px, py, pz = playerPosition:getX(), playerPosition:getY(), playerPosition:getZ()
    local vx, vy, vz = missileVelocity:getX(), missileVelocity:getY(), missileVelocity:getZ()
    local pvx, pvy, pvz = playerVelocity:getX(), playerVelocity:getY(), playerVelocity:getZ()
    local LOSRate = LOSRate({x, y, z}, {px, py, pz}, {vx, vy, vz}, {pvx, pvy, pvz})
    return missileVelocity, NAV_CONST * closingVelocity:getLength() * Vector3(unpack(LOSRate))
end

-- Utility function which makes the projectile p face towards vector forward.
local function setProjectileMatrix(p, forward)
    forward = forward:getNormalized()
    forward = Vector3(forward:getX(), forward:getY(), forward:getZ())
    local up = Vector3(0, 0, 1)
    local left = forward:cross(up)

    local ux, uy, uz = left:getX(), left:getY(), left:getZ()
    local vx, vy, vz = forward:getX(), forward:getY(), forward:getZ()
    local wx, wy, wz = up:getX(), up:getY(), up:getZ()
    local x, y, z = getElementPosition(p)

    setElementMatrix(p, {{ux, uy, uz, 0}, {vx, vy, vz, 0}, {wx, wy, wz, 0}, {x, y, z, 1}})
    return true
end

local missiles = {}

local function createMissile(creator, target, p)
    missiles[p] = target
end

local function update(deltaTime)
    for missile, target in pairs(missiles) do
        if target and missile and isElement(missile) then
            local missileVelocity, acceleration = proportionalNavigation(missile, target, 5)    -- Set NAV_CONST should = 4 or 5 but idk why check wiki
            if missileVelocity then
                local currentCounter = getProjectileCounter(missile)
                local fuelPercent = (currentCounter/10000)
		    	local newVelocity = (missileVelocity):getNormalized() * 1.75 * fuelPercent + acceleration * fuelPercent

		    	setElementVelocity(missile, newVelocity)
		    	setProjectileMatrix(missile, newVelocity)
		    end
        else
            missiles[missile] = nil
        end
    end
end
addEventHandler("onClientPreRender", root, update)

addEventHandler("onClientVehicleDamage", root, 
function(attacker, wep, loss, x, y, z, tire)
    if source ~= getPedOccupiedVehicle(localPlayer) or wep ~= 51 then return false end
    
    local attackerType = getElementType(attacker)
    local vehicle

    if attackerType == "player" then
        vehicle = getPedOccupiedVehicle(attacker)
        if not vehicle then 
            return
        end
    elseif attackerType == "vehicle" then
        vehicle = attacker
    end

    if getElementModel(vehicle) == SAMSYSTEM_MODEL then
        cancelEvent()
        local dmg = 100
        loss = math.max(dmg, math.min(2*dmg, loss))
        setElementHealth(source, getElementHealth(source) - loss)
        if getElementHealth(source) <= 0 then
            blowVehicle(source)
        end
    end
end)

--- Sync SAMs created by other people
-- @params {element} creator - The creator of the missile
local function syncOtherMissiles(creator)
    if not isElement(source) then
        return
    end

    local creatorType = getElementType(creator)
    if not isElement(creator) or creatorType ~= "vehicle" and getElementModel(creator) ~= SAMSYSTEM_MODEL then
        return false
    end

    local pType = getProjectileType(source)
    if pType ~= 20 then
        return false
    end

    local target = getProjectileTarget(source)

    if target and getElementModel(target) == 520 then
        createMissile(creator, target, source)
    end
end
addEventHandler("onClientProjectileCreation", root, syncOtherMissiles)

--- Sync sams created by us
local function syncMissile(creator, x, y, z, target)
    -- Apply velocity into the direction of the target to avoid explosion with creator
    local direction = (Vector3(getElementPosition(target)) - Vector3(x, y, z)):getNormalized()
    local dx, dy, dz = direction.x, direction.y, direction.z
    local speed = 1.3
    local projectile = createProjectile(creator, 20, x, y, z, 1, target, 0, 0, 0, dx*speed, dy*speed, dz*speed)
    createMissile(creator, target, projectile)
end
addEvent("onClientMissileCreation", true)
addEventHandler("onClientMissileCreation", resourceRoot, syncMissile)

function launchSAM(creator, x, y, z, target)
    triggerServerEvent("onMissileCreation", resourceRoot, creator, x, y, z, target)
end
