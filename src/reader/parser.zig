const std = @import("std");
const Env = @import("../env.zig");
const EvalError = @import("../eval.zig").EvalError;
const Lexer = @import("lexer.zig");
const Expr = @import("../reader.zig").Expr;
const Token = Lexer.Token;

const Error = error {
UnexpectedRParen,
UnexpectedDot,
UnexpectedEOF,
UnexpectedEndOfStream,
UnterminatedSymbol,
ExpectedSymbolAfterDollar,
ExpectedSymbolAfterDot,
OutOfMemory,
};


pub fn parse(allocator: std.mem.Allocator, tokens: []Token) Error!*Expr {
	var i: usize = 0;
	return parseExpr(allocator, tokens, &i);
}

pub fn parseExpr(allocator: std.mem.Allocator, tokens: []Token, i: *usize) Error!*Expr {
	while (i.* < tokens.len) {
		const tok = tokens[i.*];
		i.* += 1;

		return switch (tok) {
			.Newline => Expr.symbol(allocator, "newline" ),
			.Symbol => |s| Expr.symbol(allocator, s ),
			.LParen => parseList(allocator, tokens, i),
			.Quote => makeUnary(allocator, "quote", tokens, i),
			.Backtick => makeUnary(allocator, "quasiquote", tokens, i),
			.Comma => makeUnary(allocator, "unquote", tokens, i),
			.DoubleQuote => makeUnary(allocator, "doublequote", tokens, i),
			.Dot => error.UnexpectedDot,
			.RParen => error.UnexpectedRParen,
		};
	}

	return error.UnexpectedEOF;
}

fn parseList(allocator: std.mem.Allocator, tokens: []Token, i: *usize) Error!*Expr {
	if (i.* >= tokens.len) return error.UnexpectedEOF;
	if (tokens[i.*] == .RParen) { i.* += 1; return Expr.nil(allocator); }

	const head = try parseExpr(allocator, tokens, i);
	const tail = try parseList(allocator, tokens, i);
	return try Expr.pair(allocator, head, tail);
}

fn makeUnary(allocator: std.mem.Allocator, name: []const u8, tokens: []Token, i: *usize) Error!*Expr {
	const inner = try parseExpr(allocator, tokens, i);
	return try Expr.pair(
		allocator,
		try Expr.symbol(allocator, name),
		try Expr.pair(allocator, inner, try Expr.nil(allocator))
	);
}