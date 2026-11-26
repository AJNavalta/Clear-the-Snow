--!nonstrict
-- Colours, fonts and small helpers for building UI in code.
-- Change the look of the whole game's UI from here.
--
-- Note: Roblox fonts don't include emoji or most symbols (they show up as empty boxes),
-- so every icon in this game is drawn from plain frames instead of text characters.

local Theme = {}

Theme.C = {
	panel = Color3.fromRGB(18, 36, 66),
	panel2 = Color3.fromRGB(32, 58, 98),
	accent = Color3.fromHex("#ffd54f"),
	good = Color3.fromHex("#3cc48a"),
	bad = Color3.fromHex("#e0505a"),
	blue = Color3.fromHex("#4fa3e0"),
	disabled = Color3.fromRGB(93, 109, 134),
	text = Color3.fromRGB(243, 247, 255),
	muted = Color3.fromRGB(169, 187, 214),
	ink = Color3.fromRGB(15, 30, 55),
	coin = Color3.fromHex("#ffca28"),
	coinEdge = Color3.fromHex("#e09a00"),
}
local C = Theme.C

Theme.TitleFont = Enum.Font.FredokaOne
Theme.BodyFont = Enum.Font.Gotham
Theme.BoldFont = Enum.Font.GothamBold

-- new("Frame", { props }, { children })
function Theme.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props or {} do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	for _, c in children or {} do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local new = Theme.new

function Theme.corner(r: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end
function Theme.round()
	return new("UICorner", { CornerRadius = UDim.new(1, 0) })
end
function Theme.pad(px: number)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function merge(base, props)
	for k, v in props do
		base[k] = v
	end
	return base
end

function Theme.label(props)
	return new("TextLabel", merge({
		BackgroundTransparency = 1,
		Font = Theme.BoldFont,
		TextColor3 = C.text,
		TextScaled = true,
	}, props))
end

function Theme.button(props)
	return new("TextButton", merge({
		AutoButtonColor = true,
		BackgroundColor3 = C.accent,
		Font = Theme.TitleFont,
		TextColor3 = C.ink,
		TextScaled = true,
	}, props), { Theme.corner(12) })
end

-- A gold coin drawn from two circles. `size` in pixels.
function Theme.coin(size: number, props: { [string]: any }?)
	local c = new("Frame", merge({ BackgroundColor3 = C.coinEdge, Size = UDim2.fromOffset(size, size) }, props or {}), { Theme.round() })
	new("Frame", {
		BackgroundColor3 = C.coin,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		ZIndex = c.ZIndex,
		Parent = c,
	}, { Theme.round() })
	return c
end

-- An arrow drawn from frames. It points DOWN; set the returned frame's Rotation to aim it
-- (0 = down, 90 = left, 180 = up, -90 = right). `size` in pixels.
function Theme.arrow(size: number, color: Color3?, z: number?)
	color = color or C.accent
	z = z or 1
	local holder = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z })
	local function shape(col: Color3, grow: number, zi: number)
		-- shaft
		new("Frame", {
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.02, -grow),
			Size = UDim2.new(0.3, grow * 2, 0.55, grow * 2),
			ZIndex = zi,
			Parent = holder,
		}, { Theme.corner(math.floor(size * 0.06)) })
		-- head: a square turned 45 degrees, its lower half forms the point
		new("Frame", {
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
			Size = UDim2.new(0.52, grow * 2, 0.52, grow * 2),
			Rotation = 45,
			ZIndex = zi,
			Parent = holder,
		}, { Theme.corner(math.floor(size * 0.05)) })
	end
	shape(Color3.fromRGB(20, 30, 50), math.max(2, math.floor(size * 0.05)), z)
	shape(color, 0, z + 1)
	return holder
end

return Theme
