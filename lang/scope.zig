const Scope = @This();
const std = @import("std");
const Expr = @import("expr.zig").Expr;

const Binding = struct {
	value: *Expr,
	mutable: bool,
};

parent: ?*Scope,
map: std.StringHashMap(Binding),

pub fn init(allocator: std.mem.Allocator, parent: ?*Scope) Scope {
	return .{ .parent = parent, .map = std.StringHashMap(Binding).init(allocator), };
}

/// deinit does not freed the expression inside each binding.
pub fn deinit(self: *Scope) void {
	self.map.deinit();
}

pub fn push(self: *Scope, allocator: std.mem.Allocator) !*Scope {
	const env = try allocator.create(Scope);
	env.* = Scope.init(allocator, self);
	return env;
}

/// pop does not freed the expression inside each binding of the old scope.
pub fn pop(self: *Scope, allocator: std.mem.Allocator) ?*Scope {
	const parent = self.parent;
	self.deinit();
	allocator.destroy(self);
	return parent;
}

/// Ownership of `bind.value` is not transferred and the expression is not cloned. The caller is responsible for
/// ensuring the expression remains valid for the lifetime of the binding.
pub fn def(self: *Scope, name: []const u8, bind: Binding) !void {
	try self.map.put(name, bind);
}

pub fn get(self: *Scope, name: []const u8) ?Binding {
	var env: ?*Scope = self;
	while (env) |e| {
		if (e.map.get(name)) |binding|
			return binding;
		env = e.parent;
	}
	return null;
}

pub fn getPtr(self: *Scope, name: []const u8) ?*Binding {
	var env: ?*Scope = self;
	while (env) |e| {
		if (e.map.getPtr(name)) |binding|
			return binding;
		env = e.parent;
	}
	return null;
}

/// Returns a cloned copy of the bound expression.
///
/// The returned expression is allocated using `allocator` and must be freed by the caller. May returns `null` when
/// cloning cause OutOfMemory error.
///
/// Returns a clone of the bound expression to prevent callers from mutating or taking ownership of the stored value.
pub fn getExpr(
	self: *Scope,
	name: []const u8,
	allocator: std.mem.Allocator,
) ?*Expr {
	return if (self.get(name)) |b|
		Expr.clone(allocator, b.value) catch null
	else
		null;
}

pub fn set(
	self: *Scope,
	name: []const u8,
	value: *Expr,
) !void {
	const binding = self.getPtr(name)
		orelse return error.UnboundSymbol;

	if (!binding.mutable)
		return error.ImmutableBinding;

	binding.value = value;
}