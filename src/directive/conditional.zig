const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig").Env;
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const EvalError = eval.EvalError;

pub fn fnCond(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	for (args) |clause| {
		if (clause.* != .Pair)
			return error.TypeError;

		const condition = clause.car();
		const expr = clause.cdr().car();

		if (condition.* == .Symbol and
			std.mem.eql(u8, condition.Symbol, "else"))
			{
				return eval.eval(expr, env, fns, allocator);
			}

		const result = try eval.eval(
			condition,
			env,
			fns,
			allocator,
		);

		if (result.isTruthy()) {
			return eval.eval(
				expr,
				env,
				fns,
				allocator,
			);
		}
	}

	return Expr.nil(allocator);
}

// TODO: more conditional like loop, such as init-next-until loop, iterator loop