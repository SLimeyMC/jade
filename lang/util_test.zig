const std = @import("std");
const Lexer = @import("reader/lexer.zig");
const Expr = @import("expr.zig").Expr;
const parseAll = @import("reader/parser.zig").parseAll;

pub fn parseOwned(a: std.mem.Allocator, source: []const u8) ![]*Expr {
	var lexer = try Lexer.initFromSlice(a, source, .{});
	defer lexer.deinit();

	try lexer.next();
	if (lexer.consumers.items.len > 0) {
		var last = lexer.consumers.items[lexer.consumers.items.len - 1];
		try last.flush(last.ptr, &lexer);
	}
	return try parseAll(a, lexer.tokens.items);
}

pub fn freeOwnedExprs(a: std.mem.Allocator, exprs: []*Expr) void {
	for (exprs) |expr| expr.free(a);
	a.free(exprs);
}

pub fn exprSliceEql(a: []const *Expr, b: []const *Expr) !bool {
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

pub fn exprEql(a: *const Expr, b: *const Expr) bool {
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