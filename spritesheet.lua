local lg = love.graphics

local spritesheet = {}

function spritesheet.build(config)
	if not (config and config.fileName) then
		error("fileName missing from spritesheet config", 2)
	end

	local image = lg.newImage(config.fileName)
	local iw, ih = image:getDimensions()

	local sprs = {
		image = image,
		width = iw,
		height = ih,
	}

	if config.quadGen then
		local quads = {}

		for k, v in pairs(config.quadGen) do
			local x = v.x or 0
			local y = v.y or 0
			local w = v.w or error("Width (w) not given for quad '"..k.."'")
			local h = v.h or error("Height (h) not given for quad '"..k.."'")
			local cellsPerRow = v.c or 1
			local total = v.n or 1
			local labels = v.l or {}
			local qs = {}
			local i = 0
			local o = x
			while i < total do
				local quad = lg.newQuad(o, y, w, h, iw, ih)
				qs[#qs+1] = quad
				i = i + 1
				local label = labels[i]
				if label then
					qs[label] = quad
				end
				o = o + w
				if i % cellsPerRow == 0 then
					y = y + h
					o = x
				end
			end
			quads[k] = qs
		end

		sprs.quads = quads
	end

	return sprs
end

return spritesheet
