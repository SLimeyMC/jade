const std = @import("std");
const Expr = @import("reader.zig").Expr;

pub const Binding = struct {
	value: Expr,
	mutable: bool,
};

// TODO: Accept pair symbol
// e.g (let (x ()) 2) then (x ()) become 2
pub const Env = struct {
	map: std.StringHashMap(Binding),
	allocator: std.mem.Allocator,

	pub fn init(allocator: std.mem.Allocator) Env {
		return .{ .map = std.StringHashMap(Binding).init(allocator), .allocator = allocator };
	}

	pub fn def(self: *Env, name: []const u8, value: Expr, mutable: bool) !void {
		try self.map.put(name, .{ .value = value, .mutable = mutable });
	}

	pub fn get(self: *Env, name: []const u8) ?Binding {
		return self.map.get(name);
	}

	pub fn getExpr(self: *Env, allocator: std.mem.Allocator, name: []const u8) ?*Expr {
		return if (get(self, name)) |b|
			Expr.clone(allocator, &b.value) catch null
		else null;
	}

	pub fn set(self: *Env, name: []const u8, value: Expr) !void {
		const entry = self.map.getPtr(name) orelse return error.UnboundSymbol;
		if (!entry.mutable) return error.ImmutableBinding;
		entry.value = value;
	}
};