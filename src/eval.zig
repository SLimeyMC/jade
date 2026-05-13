const std = @import("std");
const reader = @import("reader.zig");
const Expr = reader.Expr;
const Env = @import("env.zig");

pub const EvalError = error {
UnboundSymbol,
ImmutableBinding,
TypeError,
NilError,
ArityError,
DivisionByZero,
NotCallable,
NotAList,
OutOfMemory,
};

pub const Fn = union(enum) {
    eager: *const fn (args: []const *Expr, env: *Env, allocator: std.mem.Allocator) EvalError!*Expr,
    macro: *const fn (args: []const *Expr, env: *Env, fns: *FnTable, allocator: std.mem.Allocator) EvalError!*Expr,
    special: *const fn (args: []const *Expr, env: *Env, fns: *FnTable, allocator: std.mem.Allocator) EvalError!*Expr,
};

pub const FnTable = std.StringHashMap(Fn);

pub fn eval(expr: *Expr, env: *Env, fns: *FnTable, allocator: std.mem.Allocator) EvalError!*Expr {
	return switch (expr.*) {
		.Nil, .Integer, .Bool, .Function => expr,
		.Symbol => |s| {
			if (env.getExpr(allocator, s)) |b| {
				return b;
			}
			return expr;
		},
		.Pair => evalPair(expr, env, fns, allocator),
	};
}

fn evalPair(expr: *Expr, env: *Env, fns: *FnTable, allocator: std.mem.Allocator) EvalError!*Expr {
	const head = expr.car();
	const rest = expr.cdr();

	const name = switch (head.*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};

	const f = fns.get(name) orelse return error.UnboundSymbol;

	return switch (f) {
		.eager => |fn_eager| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 64);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				const evaluated = try eval(node.car(), env, fns, allocator);
				try args.append(allocator, evaluated);
			}

			if (node.* != .Nil) return error.NotAList;

			break :blk fn_eager(args.items, env, allocator);
		},

		.macro => |fn_macro| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 127);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				try args.append(allocator, node.car());
            }

			if (node.* != .Nil) return error.NotAList;

			const expanded = try fn_macro(args.items, env, fns, allocator);
			break :blk try eval(expanded, env, fns, allocator);
		},

		.special => |fn_special| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 127);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				try args.append(allocator, node.car());
            }

			if (node.* != .Nil) return error.NotAList;

			const expanded = try fn_special(args.items, env, fns, allocator);
			break :blk expanded;
		},
	};
}