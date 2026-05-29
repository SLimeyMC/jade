const Parser = @This();
const std = @import("std");
const Scope = @import("../scope.zig");
const EvalError = @import("../eval.zig").EvalError;
const Lexer = @import("lexer.zig");
const Expr = @import("../expr.zig").Expr;
const Token = Lexer.Token;

const Error = error {
UnexpectedRParen,
UnexpectedDot,
UnexpectedEOF,
UnexpectedEndOfStream,
UnterminatedSymbol,
ExpectedSymbolAfterDollar,
ExpectedSymbolAfterDot,
TopLevelProducedValue,
} || std.mem.Allocator.Error;
const OOM = std.mem.Allocator.Error;

const Frame = struct {
	root: ?*Expr = null,
	tail: *Expr = undefined,
};
const Frames = std.ArrayList(Frame);

gpa: std.mem.Allocator,
exprs: std.ArrayList(*Expr),
frames: Frames,
tokens: []Token,
i: usize,

pub fn pushFrame(self: *Parser) OOM!void {
	try self.frames.append(self.gpa, .{});
}

pub fn popFrame(self: *Parser) Error!void {
	if (self.frames.items.len == 0) return error.UnexpectedRParen;

	const done = self.frames.pop().?;
	const expr = done.root orelse try Expr.nil(self.gpa);
	try self.emit(expr);
}

pub fn emit(self: *Parser, expr: *Expr) OOM!void {
	if (self.frames.items.len == 0) {
		try self.exprs.append(self.gpa, expr);
		return;
	}

	const next = try Expr.pair(self.gpa, expr, try .nil(self.gpa));
	var current = &self.frames.items[self.frames.items.len - 1];
	if (current.root == null) {
		current.root = next;
		current.tail = next.cdr();
	} else {
		current.tail.* = next.*;
		current.tail = current.tail.cdr();
        self.gpa.destroy(next);
	}
}

pub fn parse(gpa: std.mem.Allocator, tokens: []Token) Error![]*Expr {
	var parser = Parser{
		.gpa = gpa,
		.exprs = std.ArrayList(*Expr).empty,
		.frames = Frames.empty,
		.tokens = tokens,
		.i = 0,
	};
	defer parser.frames.deinit(gpa);

	while (parser.i < tokens.len) {
		const token = tokens[parser.i];
		parser.i += 1;

		switch (token) {
			.Symbol => |s| try parser.emit(try Expr.symbol(gpa, s.slice)),
			.Newline => try parser.emit(try Expr.symbol(gpa, "newline")),
			.LParen => try parser.pushFrame(),
			.RParen => try parser.popFrame(),
			.Quote => try parser.makeUnary("quote"),
			.Backtick => try parser.makeUnary("quasiquote"),
			.Comma => try parser.makeUnary("unquote"),
			.DoubleQuote => try parser.makeUnary("doublequote"),
			.CommaAt => try parser.makeUnary("unquote-splice"),
			.Dollar => try parser.parseDollar(),
			.PipeSymbol => {},
			.Dot => return error.UnexpectedDot,
		}
	}

	if (parser.frames.items.len != 0) return error.UnexpectedEOF;

	if (parser.exprs.items.len != 0) {
		return try parser.exprs.toOwnedSlice(gpa);
	} else {
		var slice = try gpa.alloc(*Expr, 1);
		slice[0] = try Expr.nil(gpa);
		return slice;
	}
}

fn makeUnary(self: *Parser, name: []const u8) OOM!void {
	const arg = try Expr.pair(self.gpa, try Expr.nil(self.gpa), try Expr.nil(self.gpa));
	const root = try Expr.pair(
		self.gpa,
		try Expr.symbol(self.gpa, name),
		arg,
	);

	try self.frames.append(self.gpa, .{
		.root = root,
		.tail = arg.car(),
	});
}

fn parseDollar(self: *Parser) Error!void {
	if (self.i >= self.tokens.len) return error.UnexpectedEOF;

	if (self.tokens[self.i] == .LParen) {
		try self.makeUnary("ref");
		return;
	}

	const root = try Expr.pair(
		self.gpa,
		try Expr.symbol(self.gpa, "ref"),
		try Expr.nil(self.gpa),
	);

	var tail = root.cdr();

    while (self.i < self.tokens.len) {
	    switch (self.tokens[self.i]) {
		    .Symbol => |s| {
			    tail.* = (try Expr.pair(
				    self.gpa,
				    try Expr.symbol(self.gpa, s.slice),
				    try Expr.nil(self.gpa),
			    )).*;
			    tail = tail.cdr();
			    self.i += 1;
		    },
		    else => return error.ExpectedSymbolAfterDollar,
	    }
		if (self.tokens[self.i] != .Dot) break;
		self.i += 1;
	    if (self.i >= self.tokens.len) return error.UnexpectedEOF;
	}

	try self.emit(root);
}