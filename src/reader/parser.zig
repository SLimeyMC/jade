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
		const token = tokens[i.*];
		i.* += 1;

		return switch (token) {
			.Newline => Expr.symbol(allocator, "newline" ),
			.Symbol => |s| Expr.symbol(allocator, s ),
			.LParen => parseList(allocator, tokens, i),
			.Quote => makeUnary(allocator, "quote", tokens, i),
			.Backtick => makeUnary(allocator, "quasiquote", tokens, i),
			.Comma => makeUnary(allocator, "unquote", tokens, i),
			.DoubleQuote => makeUnary(allocator, "doublequote", tokens, i),
			.Dollar => parseDollar(allocator, tokens, i),
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

fn parseDollar(
	allocator: std.mem.Allocator,
	tokens: []Token,
	i: *usize,
) Error!*Expr {
	const ref_sym = try Expr.symbol(allocator, "ref");
	var root = try Expr.pair(
		allocator,
		ref_sym,
		try Expr.nil(allocator),
	);
	var tail = root.cdr();
	if (i.* < tokens.len and tokens[i.*] == .LParen) {
		const expr = try parseExpr(
			allocator,
			tokens,
			i,
		);

		tail.* = (try Expr.pair(
			allocator,
			expr,
			try Expr.nil(allocator),
		)).*;

		return root;
	}

	if (i.* >= tokens.len)
		return error.UnexpectedEOF;

	switch (tokens[i.*]) {
		.Symbol => |s| {
			const sym = try Expr.symbol(
				allocator,
				s,
			);
			tail.* = (try Expr.pair(
				allocator,
				sym,
				try Expr.nil(allocator),
			)).*;
			tail = tail.cdr();
			i.* += 1;
		},
		else => return error.ExpectedSymbolAfterDollar,
	}

	while (i.* < tokens.len) {
		if (tokens[i.*] != .Dot)
			break;

		i.* += 1;

		if (i.* >= tokens.len) {
			return error.UnexpectedEOF;
		}

		switch (tokens[i.*]) {
			.Symbol => |s| {
				const sym = try Expr.symbol(
					allocator,
					s,
				);
				tail.* = (try Expr.pair(
					allocator,
					sym,
					try Expr.nil(allocator),
				)).*;
				tail = tail.cdr();
				i.* += 1;
			},
			else => return error.ExpectedSymbolAfterDot,
		}
	}

	return root;
}