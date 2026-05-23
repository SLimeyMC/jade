const std = @import("std");
const eval = @import("../eval.zig");
const Scope = @import("../scope.zig");
const Expr = @import("../expr.zig").Expr;
const Callables = eval.Callables;
const EvalError = eval.EvalError;

pub fn fnOr(
	args: []const *Expr,
	_: *Scope,
	_: *Callables,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	defer for (args) |arg| allocator.destroy(arg);
	for (args) |arg| {
		const value = try arg.toBool();
		if (value)
			return Expr.boolean(allocator, true);
	}
	return Expr.boolean(allocator, false);
}

pub fn fnNor(
	args: []const *Expr,
	_: *Scope,
	_: *Callables,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	defer for (args) |arg| allocator.destroy(arg);
	for (args) |arg| {
		const value = try arg.toBool();
		if (value)
			return Expr.boolean(allocator, false);
	}
	return Expr.boolean(allocator, true);
}

pub fn fnAnd(
	args: []const *Expr,
	_: *Scope,
	_: *Callables,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	defer for (args) |arg| allocator.destroy(arg);
	for (args) |arg| {
		const value = try arg.toBool();
		if (!value)
			return Expr.boolean(allocator, false);
	}
	return Expr.boolean(allocator, true);
}
