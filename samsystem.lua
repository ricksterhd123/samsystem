local txd = engineLoadTXD("swatvan.txd")
local dff = engineLoadDFF("swatvan.dff")

engineImportTXD(txd, SAMSYSTEM_MODEL)
engineReplaceModel(dff, SAMSYSTEM_MODEL)

Samsystem = {}
Samsystem.__index = Samsystem

setmetatable(Samsystem, {
    __call = function (cls, ...)
      return cls.new(...)
    end,
})

function Samsystem.new(vehicle)
    local self = setmetatable({}, Samsystem)
    self.element = vehicle

    -- Controllable components
    self.components = {
        ["base"] = "misc_a",
        ["pin"] = "misc_c",
        ["rocket"] = "misc_b"
    }

    -- Config
    self.rounds = 6
    self.isTargetValid = function (vehicle)
        return isElement(vehicle) and isElementStreamedIn(vehicle) and not isVehicleBlown(vehicle) and getElementModel(vehicle) == 520
    end

    self.targets = {}  -- list of valid target vehicle ids

    self.lockedTarget = {}

    -- State
    self.reloading = false

    self.lastShotTick = 0
    self.lastShot = 0

    return self
end

function Samsystem:getTurretBasePosition()
    return Vector3(getVehicleComponentPosition(self.element, "misc_b", "world"))
end

function Samsystem:getTurretBaseRotation()
    local rx, ry, rz = getVehicleComponentRotation(self.element, "misc_b", "root")
    return Vector3(rx, ry, rz)
end

function Samsystem:getTurretLookMatrix()
    -- use the vehicle coordinate frame
    local vehicleMatrix = matrix(getElementMatrix(self.element))

    local turretRotation = self:getTurretBaseRotation()
    local rx, ry, rz = turretRotation.x, turretRotation.y, turretRotation.z
    local turretMatrix = rotateZYX(vehicleMatrix, -rz, 0, 0)

    local lx, ly, lz = unpack(turretMatrix[1])
    local fx, fy, fz = unpack(turretMatrix[2])
    local ux, uy, uz = unpack(turretMatrix[3])
    local turretPosition = self:getTurretBasePosition()
    local tx, ty, tz = turretPosition.x, turretPosition.y, turretPosition.z

    return {
        {lx, ly, lz, 0},
        {fx, fy, fz, 0},
        {ux, uy, uz, 0},
        {tx, ty, tz,  1}
    }
end

function Samsystem:addTarget(vehicle)
    if self.isTargetValid(vehicle) then
        table.insert(self.targets, vehicle)
    end
end

function Samsystem:removeTarget(vehicle)
    for i, v in ipairs(self.targets) do
        if v == vehicle then
            table.remove(self.targets, i)
        end
    end
end

function Samsystem:updateTargets()
    local closestTarget = nil
    local minAngle = 45

    local turretLeft, _, _, turretBase = unpack(self:getTurretLookMatrix())
    turretLeft = Vector3(unpack(turretLeft))
    turretBase = Vector3(unpack(turretBase))

    for i, vehicle in ipairs(self.targets) do
        if self.isTargetValid(vehicle) then
            local tx, ty, tz = getElementPosition(vehicle)
            local sx, sy = getScreenFromWorldPosition(tx, ty, tz)
            if sx and sy then
                local targetPosition = Vector3(tx, ty, tz)
                local offsetFromTarget = (turretBase - targetPosition)
                local angleFromTarget = math.deg(angleBetween(offsetFromTarget, turretLeft))
                local angleFromTarget = math.abs(angleFromTarget)

                if angleFromTarget < minAngle then
                    minAngle = angleFromTarget
                    closestTarget = vehicle
                end
            end
        end
    end

    self.lockedTarget = closestTarget
end

function Samsystem:drawTargets()
    local rectangleWidth = 50
    local rectangleHeight = 50
    local rectangleThickness = 5
    local camX, camY, camZ = getCameraMatrix()

    local target = self.lockedTarget

    if isElement(target) then
        local vehicleX, vehicleY, vehicleZ = getElementPosition(target)
        local screenX, screenY = getScreenFromWorldPosition(vehicleX, vehicleY, vehicleZ)
        if screenX and screenY then
            local rectangleX1 = screenX - rectangleWidth / 2
            local rectangleY1 = screenY - rectangleHeight / 2
            local rectangleX2 = screenX + rectangleWidth / 2
            local rectangleY2 = screenY + rectangleHeight / 2
            dxDrawLine(rectangleX1, rectangleY1, rectangleX2, rectangleY1, tocolor(255, 0, 0, 150), rectangleThickness) 
            dxDrawLine(rectangleX2, rectangleY1, rectangleX2, rectangleY2, tocolor(255, 0, 0, 150), rectangleThickness) 
            dxDrawLine(rectangleX2, rectangleY2, rectangleX1, rectangleY2, tocolor(255, 0, 0, 150), rectangleThickness) 
            dxDrawLine(rectangleX1, rectangleY2, rectangleX1, rectangleY1, tocolor(255, 0, 0, 150), rectangleThickness) 
        end
    end
end

function Samsystem:drawReloading()
    if not isElement(self.element) then
        return
    end

    local playerX, playerY, playerZ = getElementPosition(localPlayer)
    local vehicleX, vehicleY, vehicleZ = getElementPosition(self.element)

    local distance = getDistanceBetweenPoints3D(playerX, playerY, playerZ, vehicleX, vehicleY, vehicleZ)
    if distance < 20 then
        local textToShow = ""

        if self.reloading then
            textToShow = "Reloading..."
        elseif self.lastShot >= self.rounds then
            textToShow = ""
        else
            textToShow = string.format("Missiles: %d", self.rounds - self.lastShot)
        end

        if #textToShow > 0 then
            local x, y, z = vehicleX, vehicleY, vehicleZ + 2
            local sx, sy = getScreenFromWorldPosition(x, y, z)
            if sx and sy then
                dxDrawText(textToShow, sx, sy, sx, sy, tocolor(255, 255, 255), 1.5, "default-bold", "center", "center")
            end
        end
    end
end

function Samsystem:reload()
    self.reloading = true
    setTimer(function ()
        self.reloading = false
        self.lastShot = 0
    end, 10000, 1)
end

function Samsystem:shootTargets()
    if not isElement(self.element) then
        return
    end

    if not isElement(self.element) then
        return
    end

    if not self.lockedTarget then
        return
    end

    if self.reloading then
        playSoundFrontEnd(41)
        return
    end

    if self.lastShot > self.rounds then
        self:reload()
        return
    end

    local target = self.lockedTarget
    if isElement(target) then
        local turretPosition = self:getTurretBasePosition()
        local left, forward, up = unpack(self:getTurretLookMatrix())
        left = Vector3(unpack(left))
        forward = Vector3(unpack(forward))
        up = Vector3(unpack(up))
        local targetPosition = Vector3(getElementPosition(target))
        local projectilePosition = turretPosition + forward * 1
        local x, y, z = projectilePosition.x, projectilePosition.y, projectilePosition.z

        local rocketPods = {
            turretPosition + up*0.2 - left*0.8 - forward,
            turretPosition + up*0.2 - left*0.55 - forward,
            turretPosition + up*0.2 - left*0.3 - forward,
            turretPosition + up*0.2 + left*0.8 - forward,
            turretPosition + up*0.2 + left*0.55 - forward,
            turretPosition + up*0.2 + left*0.3 - forward
        }

        local rocket = rocketPods[math.mod(self.lastShot, #rocketPods) + 1]

        local fx, fy, fz = forward.x, forward.y, forward.z
        local lrx, lry, lrz = rocket.x, rocket.y, rocket.z

        -- TODO: sync tank fire
        fxAddTankFire(lrx, lry, lrz, -fx, -fy, -fz)
        launchSAM(self.element, lrx, lry, lrz, target)

        local vx, vy, vz = getElementVelocity(self.element)
        setElementVelocity(self.element, vx-fx*0.2, vy-fy*0.2, vz-fz*0.2)
        self.lastShot = self.lastShot + 1
    end
end
