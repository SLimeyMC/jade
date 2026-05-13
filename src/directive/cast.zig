const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const EvalError = eval.EvalError;

pub fn fnInt(
	args: []const *Expr,
	_: *Env,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len != 1) return error.ArityError;
	const i = try args[0].toInteger();
	try allocator.destroy(args[0]);
	return Expr.integer(allocator, i);
}

pub fn fnIntOrZero(
	args: []const *Expr,
	_: *Env,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len != 1) return error.ArityError;
	const i = try args[0].toIntegerOrZero();
	allocator.destroy(args[0]);
	return Expr.integer(allocator, i);
}

pub fn fnBool(
	args: []const *Expr,
	_: *Env,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len != 1) return error.ArityError;
	const b = try args[0].toBool();
	allocator.destroy(args[0]);
	return Expr.bool(allocator, b);
}