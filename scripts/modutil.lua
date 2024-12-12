function AddPrefab(file) table.insert(PrefabFiles, file) end

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

local containers = require "containers"

AllContainers = containers.params

--\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

local fx = require "fx"

function AddEffect(name, params)
	params.name = name
	table.insert(fx, params)
end