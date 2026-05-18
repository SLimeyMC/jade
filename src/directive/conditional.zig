const std = @import("std");
const eval = @import("../eval.zig");
const Scope = @import("../scope.zig");
const Expr = @import("../expr.zig").Expr;
const Callable = eval.Callables;
const EvalError = eval.EvalError;

pub fn fnWhen(
	args: []const *Expr,
	scope: *Scope,
	callable: *Callable,
	allocator: std.mem.Allocator,
) EvalError!*Expr {
	for (args) |clause| {
		if (clause.* != .Pair) return error.TypeError;
		const condition = clause.car();
		const expr = clause.cdr().car();

		const result = try eval.eval(
			condition,
			scope,
			callable,
			allocator,
		);
		if (try result.toBool()) {
			return eval.eval(
				expr,
				scope,
				callable,
				allocator,
			);
		}
	}

	for (args) |arg| allocator.destroy(arg);
	return Expr.nil(allocator);
}

// TODO: more conditional like loop, such as init-next-until loop, iterator loop