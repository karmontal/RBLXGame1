--!strict
-- Castle map layout (studs, top-down: X east, Z south). Matches the approved
-- plan: a winding belt through the castle with 8 asymmetric rooms whose
-- doors face the belt. Edit positions here; WorldBuilder builds from it.

export type Room = { Center: Vector2, Door: "N" | "S" | "E" | "W" }

local MapLayout = {
	Half = 240, -- castle interior is 480 x 480
	RoomSize = 52,
	BeltWidth = 10,
	-- Belt centerline, from the monster machine to the exit portal.
	Belt = {
		Vector2.new(-235, -150),
		Vector2.new(-130, -150),
		Vector2.new(-100, -172),
		Vector2.new(20, -172),
		Vector2.new(50, -140),
		Vector2.new(180, -140),
		Vector2.new(205, -115),
		Vector2.new(205, -50),
		Vector2.new(180, -30),
		Vector2.new(60, -30),
		Vector2.new(30, -5),
		Vector2.new(-90, -5),
		Vector2.new(-120, -35),
		Vector2.new(-180, -35),
		Vector2.new(-205, -10),
		Vector2.new(-205, 60),
		Vector2.new(-180, 85),
		Vector2.new(-60, 85),
		Vector2.new(-30, 110),
		Vector2.new(100, 110),
		Vector2.new(130, 85),
		Vector2.new(235, 85),
	},
	Rooms = {
		{ Center = Vector2.new(-180, -205), Door = "S" },
		{ Center = Vector2.new(110, -200), Door = "S" },
		{ Center = Vector2.new(-160, -90), Door = "N" },
		{ Center = Vector2.new(95, -82), Door = "S" },
		{ Center = Vector2.new(-20, 45), Door = "N" },
		{ Center = Vector2.new(150, 30), Door = "S" },
		{ Center = Vector2.new(-150, 150), Door = "N" },
		{ Center = Vector2.new(60, 170), Door = "N" },
	} :: { Room },
	Plaza = { Center = Vector2.new(-30, -88), Radius = 34 },
	-- Garden patches: { x, z, width, depth } (top-left corner).
	Gardens = {
		{ 150, -232, 82, 70 },
		{ 150, 108, 82, 124 },
		{ -232, 190, 60, 42 },
		{ -60, 200, 70, 32 },
	},
	Trees = {
		Vector2.new(170, -210),
		Vector2.new(205, -190),
		Vector2.new(220, -218),
		Vector2.new(170, 140),
		Vector2.new(205, 170),
		Vector2.new(180, 205),
		Vector2.new(220, 130),
		Vector2.new(-215, 210),
		Vector2.new(-190, 215),
		Vector2.new(-40, 215),
		Vector2.new(-15, 212),
	},
}

return MapLayout
