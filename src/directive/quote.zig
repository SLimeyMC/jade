const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Scope = @import("../scope.zig");
const Expr = @import("../expr.zig").Expr;
const Callables = eval.Callables;
const EvalError = eval.EvalError;

pub fn fnQuote(
	args: []const *Expr,
	_: *Scope,
	_: *Callables,
	_: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 1)
		return error.ArityError;

	return args[0];
}

pub fn fnQuasiquote(
	args: []const *Expr,
	scope: *Scope,
	callables: *Callables,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len != 1)
		return error.ArityError;

	return quasiquote(
		args[0],
		1,
		scope,
		callables,
		allocator,
	);
}

fn quasiquote(
	expr: *Expr,
	depth: usize,
	scope: *Scope,
	callables: *Callables,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	switch (expr.*) {
		.Pair => {
			const head = expr.car();

			if (head.* == .Symbol and
				std.mem.eql(u8, head.Symbol, "unquote")) {
					if (depth == 1) {
						return eval.eval(
							expr.cdr().car(),
							scope,
							callables,
							allocator,
						);
					}

					return try quasiquote(
						expr.cdr().car(),
						depth - 1,
						scope,
						callables,
						allocator,
					);
				}

			if (head.* == .Symbol and std.mem.eql(u8, head.Symbol, "quasiquote")) {
					return try quasiquote(
						expr.cdr().car(),
						depth + 1,
						scope,
						callables,
						allocator,
					);
				}

			const left = try quasiquote(
				expr.car(),
				depth,
				scope,
				callables,
				allocator,
			);

			const right = try quasiquote(
				expr.cdr(),
				depth,
				scope,
				callables,
				allocator,
			);

			return Expr.pair(
				allocator,
				left,
				right,
			);
		},

		else => return Expr.clone(
			allocator,
			expr,
		),
	}
}