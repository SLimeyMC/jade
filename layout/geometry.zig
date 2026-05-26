pub const Pos = Vec2;
pub const Size = Vec2;

pub const Rect = struct {
	pos: Pos,
	size: Size,

	pub fn right(self: Rect) i32 {
		return self.pos.x + self.size.x;
	}

	pub fn bottom(self: Rect) i32 {
		return self.pos.y + self.size.y;
	}
};

const Vec2 = struct {
	x: i32,
	y: i32,

	pub const Zero = Vec2{.x = 0,.y = 0};
	pub const UnitX = Vec2{.x = 1,.y = 0};
	pub const UnitY = Vec2{.x = 0,.y = 1};

	pub fn add(a: Vec2, b: Vec2) Vec2 {
		return .{
			.x = a.x + b.x,
			.y = a.y + b.y,
		};
	}

	pub fn sub(a: Vec2, b: Vec2) Vec2 {
		return .{
			.x = a.x - b.x,
			.y = a.y - b.y,
		};
	}

	pub fn mul(a: Vec2, b: Vec2) Vec2 {
		return .{
			.x = a.x * b.x,
			.y = a.y * b.y,
		};
	}

	pub fn mulScalar(a: Vec2, scalar: i32) Vec2 {
		return .{
			.x = a.x * scalar,
			.y = a.y * scalar,
		};
	}
};
