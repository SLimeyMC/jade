const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig").Env;
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const EvalError = eval.EvalError;

pub fn fnStrictEql(
	args: []const *Expr,
	env: *Env,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	_ = env;
	if (args.len == 0) return error.ArityError;
	if (args.len == 1)
		return Expr.boolean(allocator, true);

	const first = args[0];

	const eql = struct{
		fn eql(a: *Expr, b: *Expr) bool {
			switch (a.*) {
				.Nil => {
					return b.* == .Nil;
				},
				.Bool => |v| {
					return b.* == .Bool and v == b.Bool;
				},
				.Integer => |v| {
					return b.* == .Integer and v == b.Integer;
				},
				.Symbol => |v| {
					return b.* == .Symbol and
						std.mem.eql(u8, v, b.Symbol);
				},
				.Pair => |p| {
					return b.* == .Pair and
						(eql(p[0], b.car())) and
						(eql(p[1], b.cdr()));
				},
				.Function => {
					return false;
				},
			}
		}
	}.eql;

	for (args[1..]) |arg| {
		if (!(eql(first, arg))) {
			return Expr.boolean(allocator, false);
		}
	}

	return Expr.boolean(allocator, true);
}

pub fn fnEql(args: []const *Expr, env: *Env, allocator: std.mem.Allocator) eval.EvalError!*Expr {
	_ = env;
	if (args.len == 0) return error.ArityError;
	if (args.len == 1)
		return Expr.boolean(allocator, true);

	const eql = struct {
		fn eql(a: *Expr, b: *Expr, allocatorr: std.mem.Allocator) bool {
			switch (a.*) {
				.Nil => return b.* == .Nil,
				.Pair => |p| {
					if (b.* != .Pair) return false;
                    return eql(p[0], b.car(), allocatorr) and eql(p[1], b.cdr(), allocatorr);
				},
				.Symbol => |v| {
                    const b_sym = b.asSymbol(allocatorr) catch return false;
					return std.mem.eql(u8, v, b_sym);
				},
				.Bool => |v| {
					return v == b.asBool() catch return false;
				},
				.Integer => |v| {
					return v == b.asIntegerOrZero() catch return false;
				},
				.Function => {
					return a == b;
				},
			}
		}
	}.eql;

	const first = args[0];
    for (args[1..]) |arg| {
		if (!eql(first, arg, allocator))
			return Expr.boolean(allocator, false);
	}
	return Expr.boolean(allocator, true);
}

// TODO: check type
pub fn fnIs(
	args: []const *Expr,
	env: *Env,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	_ = env;
	if (args.len == 0) return error.ArityError;
	if (args.len == 1)
		return Expr.boolean(allocator, true);

	const first = args[0];

	const eql = struct{
		inline fn eql(a: *const Expr, b: *const Expr) bool {
			switch (a.*) {
				.Nil => {
					return b.* == .Nil;
				},
				.Bool => |v| {
					return b.* == .Bool and v == b.Bool;
				},
				.Integer => |v| {
					return b.* == .Integer and v == b.Integer;
				},
				.Symbol => |v| {
					return b.* == .Symbol and
						std.mem.eql(u8, v, b.Symbol);
				},
				.Pair => |p| {
					return b.* == .Pair and
						(eql(p[0], b.car())) and
						(eql(p[1], b.cdr()));
				},
				.Function => {
					return false;
				},
			}
		}
	}.eql;

	for (args[1..]) |arg| {
		if (!(eql(first, arg))) {
			return Expr.boolean(allocator, false);
		}
	}

	return Expr.boolean(allocator, true);
}

pub fn fnLt(args: []const *Expr, env: *Env, allocator: std.mem.Allocator) EvalError!*Expr {
	_ = env;
	return Expr.boolean(allocator, try compare(args, struct {
		inline fn f(a: i32, b: i32) bool { return a < b; }
	}.f));
}

pub fn fnLte(args: []const *Expr, env: *Env, allocator: std.mem.Allocator) EvalError!*Expr {
	_ = env;
	return Expr.boolean(allocator, try compare(args, struct {
		inline fn f(a: i32, b: i32) bool { return a <= b; }
	}.f));
}

pub fn fnGt(args: []const *Expr, env: *Env, allocator: std.mem.Allocator) EvalError!*Expr {
	_ = env;
	return Expr.boolean(allocator, try compare(args, struct {
		inline fn f(a: i32, b: i32) bool { return a > b; }
	}.f));
}

pub fn fnGte(args: []const *Expr, env: *Env, allocator: std.mem.Allocator) EvalError!*Expr {
	_ = env;
	return Expr.boolean(allocator, try compare(args, struct {
		inline fn f(a: i32, b: i32) bool { return a >= b; }
	}.f));
}

inline fn compare(
	args: []const *Expr,
	comptime f: fn (i32, i32) callconv(.@"inline") bool,
) !bool {
	if (args.len < 2)
		return true;
	var prev = try args[0].asInteger();
	for (args[1..]) |arg| {
		const curr = try arg.asInteger();
		if (!f(prev, curr))
			return false;
		prev = curr;
	}
	return true;
}