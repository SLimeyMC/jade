const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const Expr = @import("expr.zig").Expr;
const util_test = @import("util_test.zig");
const parseOwned = util_test.parseOwned;
const freeOwnedExprs = util_test.freeOwnedExprs;
const exprSliceEql = util_test.exprSliceEql;

test "empty input equal nil" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "empty pair equal nil" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "()");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .nil(a)};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "single symbol" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "a");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "multiple top level symbols" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "a b c");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .symbol(a, "a"),
		try .symbol(a, "b"),
		try .symbol(a, "c"),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "single element list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "(a)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .nil(a),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "two element list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "(a b)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .pair(a,
				try .symbol(a, "b"),
				try .nil(a),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "three element list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "(a b c)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .pair(a,
				try .symbol(a, "b"),
				try .pair(a,
					try .symbol(a, "c"),
					try .nil(a),
				),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "nested list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "(a (b c))");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .pair(a,
				try .pair(a,
					try .symbol(a, "b"),
					try .pair(a,
						try .symbol(a, "c"),
						try .nil(a),
					),
				),
				try .nil(a),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "deep nesting" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "((((a))))");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .pair(a,
				try .pair(a,
					try .pair(a,
						try .symbol(a, "a"),
						try .nil(a),
					),
					try .nil(a),
				),
				try .nil(a),
			),
			try .nil(a),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with single char" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|a|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with single char and space" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|a |");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a ")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with unknown jumble" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|Ç»jý†*ù;å§g¿bþäLV½²O|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "Ç»jý†*ù;å§g¿bþäLV½²O")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with description" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|a simple description!|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a simple description!")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with pipe escape" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|a\\||");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a|")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with pipe escape surrouned by space" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|A \\| B|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "A | B")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with slash escape" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|1\\\\2|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "1\\2")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "piped symbol with parentheses pair" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "|()|");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "()")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "quote symbol" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "'a");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "quote"),
			try .pair(a,
				try .symbol(a, "a"),
				try .nil(a)
			)
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "double quote symbol" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "''a");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "quote"),
			try .pair(a,
				try .pair(a,
					try .symbol(a, "quote"),
					try .pair(a,
						try .symbol(a, "a"),
						try .nil(a)
					)
				),
				try .nil(a)
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "quote empty list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "'()");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "quote"),
			try .pair(a,
				try .nil(a),
				try .nil(a)
			)
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "quote list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "'(a b)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "quote"),
			try .pair(a,
				try .pair(a,
					try .symbol(a, "a"),
					try .pair(a,
						try .symbol(a, "b"),
						try .nil(a)
					)
				),
				try .nil(a)
			)
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "quasiquote with unquote" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "`(a ,b)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "quasiquote"),
			try .pair(a,
				try .pair(a,
					try .symbol(a, "a"),
					try .pair(a,
						try .pair(a,
							try .symbol(a, "unquote"),
							try .pair(a,
								try .symbol(a, "b"),
								try .nil(a)
							)
						),
						try .nil(a)
					)
				),
				try .nil(a)
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "line comment before expression" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a,
		\\; hello
		\\a
	);
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "line comment after expression" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a,
		\\a ; comment
	);
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "a")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "datum comment skips symbol" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "#;a b");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "b")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "datum comment skips list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "#;(a b) c");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "c")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "nested datum comment" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "#;#;a b c");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{try .symbol(a, "b"), try .symbol(a, "c")};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "datum comment inside list" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "(a #;b c)");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .pair(a,
				try .symbol(a, "c"),
				try .nil(a),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "whitespace variations" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a,
		\\(
		\\    a
		\\    b
		\\)
	);
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "a"),
			try .pair(a,
				try .symbol(a, "b"),
				try .nil(a),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "dollar shape" {
	const a = std.testing.allocator;
	const exprs = try parseOwned(a, "$a.b.c");
	defer freeOwnedExprs(a, exprs);
	const expected = [_]*Expr{
		try .pair(a,
			try .symbol(a, "ref"),
			try .pair(a,
				try .symbol(a, "a"),
				try .pair(a,
					try .symbol(a, "b"),
					try .pair(a,
						try .symbol(a, "c"),
						try .nil(a),
					),
				),
			),
		),
	};
	defer for (expected) |expecting| expecting.free(a);
	try expect(try exprSliceEql(exprs, &expected));
}

test "unexpected close paren" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedRParen,
		parseOwned(a, ")"),
	);
}

test "missing close paren" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, "(a b"),
	);
}

test "expected escape char sequence after slash but found char instead" {
	const a = std.testing.allocator;
	try expectError(
		error.ExpectedEscapeSequence,
		parseOwned(a, "|\\a|"),
	);
}

test "pipe symbol iis terminated early" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, "|a"),
	);
}

test "expected escape char sequence after slash but terminated early" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, "|a\\|"),
	);
}

test "quote without datum" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, "'"),
	);
}

test "quasiquote without datum" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, "`"),
	);
}

test "unquote without datum" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedEOF,
		parseOwned(a, ","),
	);
}

test "unexpected dot on dollar" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedDotOnDollar,
		parseOwned(a, "$.a.b.c"),
	);
}

test "unexpected double dot on dollar" {
	const a = std.testing.allocator;
	try expectError(
		error.UnexpectedDotOnDollar,
		parseOwned(a, "$a..b.c"),
	);
}

test "datum comment without datum" {
	const a = std.testing.allocator;
	const expr = try parseOwned(a, "#;");
	freeOwnedExprs(a, expr);
}