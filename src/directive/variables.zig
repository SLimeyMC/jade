const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const EvalError = eval.EvalError;

pub fn fnDo(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	var scope = try env.push(allocator);
	defer _ = scope.pop(allocator);

	var result = try Expr.nil(allocator);
	for (args) |expr|
		result = try eval.eval(expr, scope, fns, allocator);
	return result;
}

pub fn fnLet(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], env, fns, allocator);
	try env.def(name, .{.value = value.*, .mutable = false});
	allocator.destroy(value);
	return Expr.nil(allocator);
}

pub fn fnVar(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], env, fns, allocator);
	try env.def(name, .{.value = value.*, .mutable = true});
	allocator.destroy(value);
	return Expr.nil(allocator);
}

// TODO: (ref ..) support
pub fn fnSet(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], env, fns, allocator);
	try env.set(name, value.*);
	allocator.destroy(value);
	return Expr.nil(allocator);
}