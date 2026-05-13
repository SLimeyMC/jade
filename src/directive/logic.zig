const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const EvalError = eval.EvalError;

pub fn fnOr(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	for (args) |arg| {
		const value = try (try eval.eval(arg, env, fns, allocator)).toBool();
		if (value)
			return Expr.boolean(allocator, true);
	}
	return Expr.boolean(allocator, false);
}

pub fn fnNor(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	for (args) |arg| {
		const value = try (try eval.eval(arg, env, fns, allocator)).toBool();
		if (value)
			return Expr.boolean(allocator, false);
	}
	return Expr.boolean(allocator, true);
}

pub fn fnAnd(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	for (args) |arg| {
		const value = try (try eval.eval(arg, env, fns, allocator)).toBool();
		if (!value)
			return Expr.boolean(allocator, false);
	}
	return Expr.boolean(allocator, true);
}
