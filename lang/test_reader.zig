const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const Lexer = @import("reader/lexer.zig");
const Expr = @import("expr.zig").Expr;
const parseAll = @import("reader/parser.zig").parseAll;

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

test "datum comment without datum" {
	const a = std.testing.allocator;
	const expr = try parseOwned(a, "#;");
	freeOwnedExprs(a, expr);
	try expect(true);
}

fn parseOwned(a: std.mem.Allocator, source: []const u8) ![]*Expr {
	var lexer = try Lexer.initFromSlice(a, source, .{});
	defer lexer.deinit();

	try lexer.next();
	if (lexer.consumers.items.len > 0) {
		var last = lexer.consumers.items[lexer.consumers.items.len - 1];
		try last.flush(last.ptr, &lexer);
	}
	return try parseAll(a, lexer.tokens.items);
}

fn freeOwnedExprs(a: std.mem.Allocator, exprs: []*Expr) void {
	for (exprs) |expr| expr.free(a);
	a.free(exprs);
}

fn exprEql(a: *const Expr, b: *const Expr) bool {
	if (@intFromEnum(a.*) != @intFromEnum(b.*))
		return false;

	return switch (a.*) {
		.Nil => true,
		.Symbol => |sa| std.mem.eql(u8, sa, b.Symbol),
		.Integer => |ia| ia == b.Integer,
		.Bool => |ba| ba == b.Bool,
		.Pair => |pa| {
			const pb = b.Pair;

			return exprEql(pa[0], pb[0]) and
				exprEql(pa[1], pb[1]);
		},
		.Closure => {
			// const cb = b.Closure;
            return true;
		},
	};
}

fn exprSliceEql(a: []const *Expr, b: []const *Expr) !bool {
	var buf: [4096]u8 = undefined;
	var file: std.Io.File.Writer = .init(.stdout(), std.testing.io, &buf);
	const w = &file.interface;
	var i: usize = 0;
	while (i < a.len or i < b.len) : (i += 1) {
		//try w.print("n {}:\n", .{i});
		//try if (i < a.len) a[i].format(w) else w.writeAll("<missing>");
		//try w.writeByte('\n');
		//try if (i < b.len) b[i].format(w) else w.writeAll("<missing>");
		//try w.writeByte('\n');
	}
	try w.flush();
	if (a.len != b.len)
		return false;

	for (a, b) |ea, eb| {
		if (!exprEql(ea, eb))
			return false;
	}

	return true;
}