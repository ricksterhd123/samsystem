local samsystem = nil

local screenW, screenH = guiGetScreenSize()
local lastUpdateTick = 0
local FPS = getFPSLimit()
local UPS = FPS * 0.75

function update()
    if not samsystem then
        return
    end
    local now = getTickCount()
    if now - lastUpdateTick > 1000/UPS then
        samsystem:updateTargets()
        lastUpdateTick = now
    end
end

function draw()
    if not samsystem then
        return
    end

    samsystem:drawTargets()
    samsystem:drawReloading()
end

function canShoot()
    return not getElementData(localPlayer, "player:dmprotected")
end

function shoot()
    if not samsystem then
        return
    end

    if canShoot() then
        samsystem:shootTargets()
    end
end

function onTargetStreamIn()
    if not samsystem then
        return
    end

    if getElementType(source) == "vehicle" then
        samsystem:addTarget(source)
    end
end

function onTargetStreamOut()
    if not samsystem then
        return
    end

    if getElementType(source) == "vehicle" then
        samsystem:removeTarget(source)
    end
end

function onStop()
    toggleControl("vehicle_fire", true)
    removeEventHandler("onClientPreRender", root, update)
    removeEventHandler("onClientRender", root, draw)
    removeEventHandler("onClientElementStreamIn", root, onTargetStreamIn)
    removeEventHandler("onClientElementStreamOut", root, onTargetStreamOut)
    removeEventHandler("onClientElementModelChange", samsystem.element, onStop)
    removeEventHandler("onClientVehicleExit", samsystem.element, onStop)
    removeEventHandler("onClientVehicleExplode", samsystem.element, onStop)

    unbindKey("vehicle_fire", "down", shoot)
    samsystem = nil
end

function onStart(vehicle)
    if getElementModel(vehicle) == SAMSYSTEM_MODEL then
        samsystem = Samsystem(vehicle)

        for i, v in ipairs(getElementsByType("vehicle")) do
            if getElementType(v) == "vehicle" then
                samsystem:addTarget(v)
            end
        end

        toggleControl("vehicle_fire", false)

        addEventHandler("onClientPreRender", root, update)
        addEventHandler("onClientRender", root, draw)
        addEventHandler("onClientElementStreamIn", root, onTargetStreamIn)
        addEventHandler("onClientElementStreamOut", root, onTargetStreamOut)
        addEventHandler("onClientElementModelChange", vehicle, onStop)
        addEventHandler("onClientVehicleExit", vehicle, onStop)
        addEventHandler("onClientVehicleExplode", vehicle, onStop)

        bindKey("vehicle_fire", "down", shoot)
    end
end
addEventHandler("onClientPlayerVehicleEnter", localPlayer, onStart)

addEventHandler("onClientResourceStart", resourceRoot, function ()
    local vehicle = getPedOccupiedVehicle(localPlayer)

    if vehicle then
        onStart(vehicle)
    end
end)
