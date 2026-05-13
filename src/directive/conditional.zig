const std = @import("std");
const reader = @import("../reader.zig");
const eval = @import("../eval.zig");
const Env = @import("../env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const EvalError = eval.EvalError;

pub fn fnWhen(
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

		const result = try eval.eval(
			condition,
			env,
			fns,
			allocator,
		);
		if (try result.toBool()) {
			return eval.eval(
				expr,
				env,
				fns,
				allocator,
			);
		}
	}

	for (args) |arg| allocator.destroy(arg);
	return Expr.nil(allocator);
}

// TODO: more conditional like loop, such as init-next-until loop, iterator loop