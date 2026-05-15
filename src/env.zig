const Env = @This();
const std = @import("std");
const Expr = @import("expr.zig").Expr;

const Binding = struct {
	value: Expr,
	mutable: bool,
};

parent: ?*Env,
map: std.StringHashMap(Binding),

pub fn init(allocator: std.mem.Allocator, parent: ?*Env) Env {
	return .{ .parent = parent, .map = std.StringHashMap(Binding).init(allocator), };
}

pub fn deinit(self: *Env) void {
	self.map.deinit();
}

pub fn push(self: *Env, allocator: std.mem.Allocator) !*Env {
	const env = try allocator.create(Env);
	env.* = Env.init(allocator, self);
	return env;
}

pub fn pop(self: *Env, allocator: std.mem.Allocator) ?*Env {
	const parent = self.parent;
	self.deinit();
	allocator.destroy(self);
	return parent;
}

pub fn def(self: *Env, name: []const u8, bind: Binding) !void {
	try self.map.put(name, bind);
}

pub fn get(self: *Env, name: []const u8) ?Binding {
	var env: ?*Env = self;
	while (env) |e| {
		if (e.map.get(name)) |binding|
			return binding;
		env = e.parent;
	}
	return null;
}

pub fn getPtr(self: *Env, name: []const u8) ?*Binding {
	var env: ?*Env = self;
	while (env) |e| {
		if (e.map.getPtr(name)) |binding|
			return binding;
		env = e.parent;
	}
	return null;
}

pub fn getExpr(
	self: *Env,
	name: []const u8,
	allocator: std.mem.Allocator,
) ?*Expr {
	return if (self.get(name)) |b|
		Expr.clone(allocator, &b.value) catch null
	else
		null;
}

pub fn set(
	self: *Env,
	name: []const u8,
	value: Expr,
) !void {
	const binding = self.getPtr(name)
		orelse return error.UnboundSymbol;

	if (!binding.mutable)
		return error.ImmutableBinding;

	binding.value = value;
}