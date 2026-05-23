const std = @import("std");
const expr_mod = @import("expr.zig");
const Expr = expr_mod.Expr;
const Closure = expr_mod.Closure;
const Scope = @import("scope.zig");

pub const EvalError = error {
UnboundSymbol,
ImmutableBinding,
TypeError,
NilError,
ArityError,
DivisionByZero,
NotCallable,
NotAList,
} || std.mem.Allocator.Error;

const Callable = union(enum) {
	eager: *const fn (args: []const *Expr, allocator: std.mem.Allocator) EvalError!*Expr,
	macro: *const fn (args: []const *Expr, scope: *Scope, callables: *Callables, allocator: std.mem.Allocator) EvalError!*Expr,
	special: *const fn (args: []const *Expr, scope: *Scope, callables: *Callables, allocator: std.mem.Allocator) EvalError!*Expr,
};

pub const Callables = std.StringHashMap(Callable);

pub fn eval(expr: *Expr, scope: *Scope, callables: *Callables, allocator: std.mem.Allocator) EvalError!*Expr {
	return switch (expr.*) {
		.Nil, .Integer, .Bool, .Closure => expr,
		.Symbol => |s| {
			if (scope.getExpr(s, allocator)) |b| {
				return b;
			}
			return expr;
		},
		.Pair => evalPair(expr, scope, callables, allocator),
	};
}

fn evalPair(expr: *Expr, scope: *Scope, callables: *Callables, allocator: std.mem.Allocator) EvalError!*Expr {
	const head = expr.car();
	const rest = expr.cdr();

	const name = switch (head.*) {
		.Symbol => |s| s,
		.Closure => |fun| {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 64);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				const evaluated = try eval(node.car(), scope, callables, allocator);
				try args.append(allocator, evaluated);
			}

			if (args.items.len != fun.params.len) return error.ArityError;
			var child = try fun.scope.push(allocator);

			for (fun.params, args.items) |param, arg| {
				try child.def(param, .{
					.value = arg,
					.mutable = false,
				});
			}

			return eval(fun.body, child, callables, allocator);
		},
		else => return error.TypeError,
	};

	return if (callables.get(name)) |f| switch (f) {
		.eager => |fn_eager| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 64);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				const evaluated = try eval(node.car(), scope, callables, allocator);
				try args.append(allocator, evaluated);
			}

			if (node.* != .Nil) return error.NotAList;

			break :blk fn_eager(args.items, allocator);
		},

		.macro => |fn_macro| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 127);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				try args.append(allocator, node.car());
            }

			if (node.* != .Nil) return error.NotAList;

			const expanded = try fn_macro(args.items, scope, callables, allocator);
			break :blk try eval(expanded, scope, callables, allocator);
		},

		.special => |fn_special| blk: {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 127);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				try args.append(allocator, node.car());
            }

			if (node.* != .Nil) return error.NotAList;

			const expanded = try fn_special(args.items, scope, callables, allocator);
			break :blk expanded;
		},
	} else if (scope.get(name)) |e| switch (e.value.*) {
		.Closure => |fun| {
			var args = try std.ArrayList(*Expr).initCapacity(allocator, 64);
			defer args.deinit(allocator);

			var node = rest;
			while (node.* == .Pair) : (node = node.cdr()) {
				const evaluated = try eval(node.car(), scope, callables, allocator);
				try args.append(allocator, evaluated);
			}

			if (args.items.len != fun.params.len) return error.ArityError;
			var child = try fun.scope.push(allocator);

			for (fun.params, args.items) |param, arg| {
				try child.def(param, .{
					.value = arg,
					.mutable = false,
				});
			}

			return eval(fun.body, child, callables, allocator);
		},
		else => return error.TypeError,
	} else return error.UnboundSymbol;
}