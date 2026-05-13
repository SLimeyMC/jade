const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const EvalError = eval.EvalError;

pub fn fnQuote(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	_ = env;
	_ = fns;
	_ = allocator;

	if (args.len != 1)
		return error.ArityError;

	return args[0];
}

pub fn fnQuasiquote(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	if (args.len != 1)
		return error.ArityError;

	return quasiquote(
		args[0],
		1,
		env,
		fns,
		allocator,
	);
}

fn quasiquote(
	expr: *Expr,
	depth: usize,
	env: *Env,
	fns: *FnTable,
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
							env,
							fns,
							allocator,
						);
					}

					return try quasiquote(
						expr.cdr().car(),
						depth - 1,
						env,
						fns,
						allocator,
					);
				}

			if (head.* == .Symbol and
				std.mem.eql(u8, head.Symbol, "quasiquote")) {
					return try quasiquote(
						expr.cdr().car(),
						depth + 1,
						env,
						fns,
						allocator,
					);
				}

			const left = try quasiquote(
				expr.car(),
				depth,
				env,
				fns,
				allocator,
			);

			const right = try quasiquote(
				expr.cdr(),
				depth,
				env,
				fns,
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