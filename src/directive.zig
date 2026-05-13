const FnTable = @import("eval.zig").FnTable;
const arithmethic = @import("directive/arithmethic.zig");
pub const Arithmethic = opaque {
	pub const fnAdd = arithmethic.fnAdd;
	pub const fnSub = arithmethic.fnSub;
	pub const fnMul = arithmethic.fnMul;
	pub const fnDiv = arithmethic.fnDiv;

	pub fn init(fns: *FnTable) !void {
		try fns.put("+", .{ .eager = fnAdd });
		try fns.put("-", .{ .eager = fnSub });
		try fns.put("*", .{ .eager = fnMul });
		try fns.put("/", .{ .eager = fnDiv });
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

	pub fn init(fns: *FnTable) !void {
		try fns.put("int?", .{ .eager = fnInt });
		try fns.put("int", .{ .eager = fnIntOrZero });
		try fns.put("bool", .{ .eager = fnBool });
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

	pub fn init(fns: *FnTable) !void {
		try fns.put("=", .{ .eager = fnEql });
		try fns.put("=?", .{ .eager = fnStrictEql });
        try fns.put(">", .{ .eager = fnGt });
		try fns.put(">=", .{ .eager = fnGte });
		try fns.put("<", .{ .eager = fnLt });
		try fns.put("<=", .{ .eager = fnLte });
	}
};

const conditional = @import("directive/conditional.zig");
pub const Conditional = opaque {
	pub const fnWhen = conditional.fnWhen;

	pub fn init(fns: *FnTable) !void {
		try fns.put("cond", .{ .special = fnWhen });
	}
};

const logic = @import("directive/logic.zig");
pub const Logic = opaque {
	pub const fnOr = logic.fnOr;
	pub const fnNor = logic.fnNor;
	pub const fnAnd = logic.fnAnd;

	pub fn init(fns: *FnTable) !void {
		try fns.put("or", .{ .special = fnOr });
		try fns.put("nor", .{ .special = fnNor });
		try fns.put("and", .{ .special = fnAnd });
	}
};

const quote = @import("directive/quote.zig");
pub const Quote = opaque {
	pub const fnQuote = quote.fnQuote;
	pub const fnQuasiquote = quote.fnQuasiquote;

	pub fn init(fns: *FnTable) !void {
		try fns.put("quote", .{ .special = fnQuote });
		try fns.put("quasiquote", .{ .special = fnQuasiquote });
	}
};

const variables = @import("directive/variables.zig");
pub const Variables = opaque {
	pub const fnDo = variables.fnDo;
	pub const fnLet = variables.fnLet;
	pub const fnVar = variables.fnVar;
	pub const fnSet = variables.fnSet;

	pub fn init(fns: *FnTable) !void {
		try fns.put("do", .{ .special = fnDo });
		try fns.put("let", .{ .special = fnLet });
		try fns.put("var", .{ .special = fnVar });
		try fns.put("set", .{ .special = fnSet });
	}
};

pub fn init(fns: *FnTable) !void {
	try Arithmethic.init(fns);
	try Comparison.init(fns);
	try Logic.init(fns);
	try Variables.init(fns);
	try Quote.init(fns);
	try Conditional.init(fns);
}