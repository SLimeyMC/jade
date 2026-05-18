const std = @import("std");
const eval = @import("../eval.zig");
const Expr = @import("../expr.zig").Expr;
const EvalError = eval.EvalError;

pub fn fnAdd(
	args: []const *Expr,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	const acc = try foldInt(
		args,
		0,
		struct {
			inline fn f(a: i32, b: i32) EvalError!i32 {
				return a + b;
			}
		}.f,
	);
	for (args) |arg| allocator.destroy(arg);
	return Expr.integer(allocator, acc);
}

pub fn fnSub(
	args: []const *Expr,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len == 0) return error.ArityError;
	const acc = try foldInt(
		args[1..],
		try args[0].toIntegerOrZero(),
		struct {
			inline fn f(a: i32, b: i32) EvalError!i32 {
				return a - b;
			}
		}.f,
	);
	for (args) |arg| allocator.destroy(arg);
	return Expr.integer(allocator, acc);
}

pub fn fnMul(
	args: []const *Expr,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	const acc = try foldInt(
		args,
		1,
		struct {
			inline fn f(a: i32, b: i32) EvalError!i32 {
				return a * b;
			}
		}.f,
	);
	for (args) |arg| allocator.destroy(arg);
	return Expr.integer(allocator, acc);
}

pub fn fnDiv(
	args: []const *Expr,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len == 0)
		return error.ArityError;
	const acc = try foldInt(
		args[1..],
		try args[0].toIntegerOrZero(),
		struct {
			inline fn f(a: i32, b: i32) EvalError!i32 {
				if (b == 0) return error.DivisionByZero;
				return @divFloor(a, b);
			}
		}.f,
	);
	for (args) |arg| allocator.destroy(arg);
	return Expr.integer(allocator, acc);
}

inline fn foldInt(
	args: []const *Expr,
	init: i32,
	comptime f: fn (i32, i32) callconv(.@"inline") EvalError!i32,
) EvalError!i32 {
	var acc = init;
	for (args) |arg| {
		acc = try f(acc, try arg.toIntegerOrZero());
	}
	return acc;
}

