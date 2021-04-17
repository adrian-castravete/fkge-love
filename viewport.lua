local lg = love.graphics

local width = 360
local height = 240

local outputWidth = 1280
local outputHeight = 720
local internalCanvas = nil

local viewport = {
	offsetX = 0,
	offsetY = 0,
	scale = 2,
}

function viewport.resize(w, h)
	local v = viewport
	outputWidth = w
	outputHeight = h
	v.scale = math.max(1, math.floor(math.min(w / width, h / height)))
	v.offsetX = math.floor((w - width * v.scale) * 0.5)
	v.offsetY = math.floor((h - height * v.scale) * 0.5)
end

function viewport.draw()
	if not internalCanvas then
		return
	end
	
	local v = viewport

	lg.push()
	lg.translate(v.offsetX, v.offsetY)
	lg.scale(v.scale, v.scale)
	lg.draw(internalCanvas, 0, 0)
	lg.pop()

	lg.setCanvas(internalCanvas)
	lg.clear(0, 0, 0)
	lg.setCanvas()
end

function viewport.setup(config)
	width = config.width or width
	height = config.height or height

	viewport.resize(lg.getDimensions())

	internalCanvas = lg.newCanvas(width, height)
	viewport.canvas = internalCanvas
end

return viewport