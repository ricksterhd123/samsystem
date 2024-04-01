function onMissileCreation(creator, x, y, z, target)
	if not client or source ~= resourceRoot then
		return
	end

    triggerClientEvent(client, "onClientMissileCreation", resourceRoot, creator, x, y, z, target)
end
addEvent("onMissileCreation", true)
addEventHandler("onMissileCreation", resourceRoot, onMissileCreation)
