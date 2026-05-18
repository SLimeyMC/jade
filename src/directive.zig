const Callables = @import("eval.zig").Callables;
const arithmethic = @import("directive/arithmethic.zig");
pub const Arithmethic = opaque {
	pub const fnAdd = arithmethic.fnAdd;
	pub const fnSub = arithmethic.fnSub;
	pub const fnMul = arithmethic.fnMul;
	pub const fnDiv = arithmethic.fnDiv;

	pub fn init(callables: *Callables) !void {
		try callables.put("+", .{ .eager = fnAdd });
		try callables.put("-", .{ .eager = fnSub });
		try callables.put("*", .{ .eager = fnMul });
		try callables.put("/", .{ .eager = fnDiv });
	}
};

// Cast here only work for literal, it won't cast expression that needed to be evaluated and error.
// The way to cast complex expression is don't. Implicit conversion happen automatically, casting only useful with
// structural equality.
const cast = @import("directive/cast.zig");
pub const Cast = opaque {
	pub const fnInt = cast.fnInt;
	pub const fnIntOrZero = cast.fnIntOrZero;
	pub const fnBool = cast.fnBool;

	pub fn init(callables: *Callables) !void {
		try callables.put("int?", .{ .eager = fnInt });
		try callables.put("int", .{ .eager = fnIntOrZero });
		try callables.put("bool", .{ .eager = fnBool });
	}
};

const comparison = @import("directive/comparison.zig");
pub const Comparison = opaque {
	pub const fnEql = comparison.fnEql;
	pub const fnStrictEql = comparison.fnStrictEql;
	pub const fnLt = comparison.fnLt;
	pub const fnLte = comparison.fnLte;
	pub const fnGt = comparison.fnGt;
	pub const fnGte = comparison.fnGte;

	pub fn init(callables: *Callables) !void {
		try callables.put("=", .{ .eager = fnEql });
		try callables.put("=?", .{ .eager = fnStrictEql });
        try callables.put(">", .{ .eager = fnGt });
		try callables.put(">=", .{ .eager = fnGte });
		try callables.put("<", .{ .eager = fnLt });
		try callables.put("<=", .{ .eager = fnLte });
	}
};

const conditional = @import("directive/conditional.zig");
pub const Conditional = opaque {
	pub const fnWhen = conditional.fnWhen;

	pub fn init(callables: *Callables) !void {
		try callables.put("cond", .{ .special = fnWhen });
	}
};

const logic = @import("directive/logic.zig");
pub const Logic = opaque {
	pub const fnOr = logic.fnOr;
	pub const fnNor = logic.fnNor;
	pub const fnAnd = logic.fnAnd;

	pub fn init(callables: *Callables) !void {
		try callables.put("or", .{ .special = fnOr });
		try callables.put("nor", .{ .special = fnNor });
		try callables.put("and", .{ .special = fnAnd });
	}
};

const quote = @import("directive/quote.zig");
pub const Quote = opaque {
	pub const fnQuote = quote.fnQuote;
	pub const fnQuasiquote = quote.fnQuasiquote;

	pub fn init(callables: *Callables) !void {
		try callables.put("quote", .{ .special = fnQuote });
		try callables.put("quasiquote", .{ .special = fnQuasiquote });
	}
};

const variables = @import("directive/variables.zig");
pub const Variables = opaque {
	pub const fnDo = variables.fnDo;
	pub const fnLet = variables.fnLet;
	pub const fnVar = variables.fnVar;
	pub const fnSet = variables.fnSet;

	pub fn init(callables: *Callables) !void {
		try callables.put("do", .{ .special = fnDo });
		try callables.put("let", .{ .special = fnLet });
		try callables.put("var", .{ .special = fnVar });
		try callables.put("set", .{ .special = fnSet });
	}
};

pub fn init(callables: *Callables) !void {
	try Arithmethic.init(callables);
	try Comparison.init(callables);
	try Logic.init(callables);
	try Variables.init(callables);
	try Quote.init(callables);
	try Conditional.init(callables);
}