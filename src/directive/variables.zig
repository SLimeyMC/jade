const std = @import("std");
const eval = @import("../eval.zig");
const Scope = @import("../scope.zig");
const Expr = @import("../expr.zig").Expr;
const Callables = eval.Callables;
const EvalError = eval.EvalError;

pub fn fnDo(
	args: []const *Expr,
	scope: *Scope,
	callable: *Callables,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	var curr = try scope.push(allocator);
	defer _ = curr.pop(allocator);

	var result = try Expr.nil(allocator);
	for (args) |expr|
		result = try eval.eval(expr, curr, callable, allocator);
	return result;
}

pub fn fnLet(
	args: []const *Expr,
	scope: *Scope,
	callable: *Callables,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], scope, callable, allocator);
	try scope.def(name, .{.value = value.*, .mutable = false});
	allocator.destroy(value);
	return Expr.nil(allocator);
}

pub fn fnVar(
	args: []const *Expr,
	scope: *Scope,
	callable: *Callables,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], scope, callable, allocator);
	try scope.def(name, .{.value = value.*, .mutable = true});
	allocator.destroy(value);
	return Expr.nil(allocator);
}

// TODO: (ref ..) support
pub fn fnSet(
	args: []const *Expr,
	scope: *Scope,
	callable: *Callables,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], scope, callable, allocator);
	try scope.set(name, value.*);
	allocator.destroy(value);
	return Expr.nil(allocator);
}