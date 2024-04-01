-- arbitrary rotation ZYX
function rotateZYX(matrix4x4, yaw, roll, pitch)
    local gamma = math.rad(yaw)
    local beta = math.rad(roll)
    local alpha = math.rad(pitch)
    local m = matrix(matrix4x4)
    local r = matrix({
        {math.cos(beta)*math.cos(gamma), math.cos(gamma)*math.sin(alpha)*math.sin(beta)-math.cos(alpha)*math.sin(gamma), math.cos(alpha)*math.cos(gamma)*math.sin(beta) + math.sin(alpha)*math.sin(gamma), 0},
        {math.cos(beta)*math.sin(gamma), math.cos(alpha)*math.cos(gamma)+math.sin(alpha)*math.sin(beta)*math.sin(gamma), -math.cos(gamma)*math.sin(alpha)+math.cos(alpha)*math.sin(beta)*math.sin(gamma), 0},
        {-math.sin(beta), math.cos(beta)*math.sin(alpha), math.cos(alpha)*math.cos(beta), 0},
        {0, 0, 0, 1}
    })
    return matrix.mul(m, r)
end

-- project 3d point onto 2d plane
function angleBetween(v1, v2)
    local dot = v1:dot(v2)

    local v1Length = v1:getLength()
    local v2Length = v2:getLength()

    if v1Length > 0 and v2Length > 0 then
        return dot / (v1Length * v2Length)
    end

    return 0
end
