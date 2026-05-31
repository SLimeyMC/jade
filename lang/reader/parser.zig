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
	const Kind = enum {
		Normal,
		Unary,
	};
	root: ?*Expr = null,
	tail: *Expr = undefined,
	kind: Kind = .Normal,
};

gpa: std.mem.Allocator,
exprs: std.ArrayList(*Expr),
frames: std.ArrayList(Frame),
tokens: []Token,
pos: usize,

pub fn init(gpa: std.mem.Allocator, tokens: []Token) Parser {
	return Parser{
		.gpa = gpa,
		.exprs = .empty,
		.frames = .empty,
		.tokens = tokens,
		.pos = 0,
	};
}

/// Freed expression it still has inside the `exprs`.
pub fn deinit(parser: *Parser) void {
	for (parser.exprs.items) |expr| expr.free(parser.gpa);
	parser.exprs.deinit(parser.gpa);
	for (parser.frames.items) |frame| if (frame.root != null) frame.root.?.free(parser.gpa);
	parser.frames.deinit(parser.gpa);
}

pub fn parseAll(gpa: std.mem.Allocator, tokens: []Token) Error![]*Expr {
	var parser = Parser.init(gpa, tokens);
	defer parser.deinit();

	try parser.next();

	return parser.exprs.toOwnedSlice(gpa);
}

/// Parse until no token is exhausted, throw `UnexpectedEOF` if expression is incomplete.
pub fn next(self: *Parser) Error!void {
	while (self.pos < self.tokens.len) {
		const token = self.tokens[self.pos];
		self.pos += 1;

		try self.consume(token);
	}

	if (self.frames.items.len != 0) {
		return error.UnexpectedEOF;
	}
}

pub fn consume(parser: *Parser, token: Token) Error!void {
	switch (token) {
		.Symbol => |s| try parser.emit(try .symbol(parser.gpa, s.slice)),
		.PipeSymbol => |s| {
			const name = try dupeUnescapePipeSymbol(parser.gpa, s.slice);
			defer parser.gpa.free(name);
			try parser.emit(try .symbol(parser.gpa, name));
		},
		.Newline => try parser.emit(try .symbol(parser.gpa, "newline")),
		.LParen => try parser.pushFrame(),
		.RParen => try parser.popFrame(),
		.Quote => try parser.makeUnary("quote"),
		.Backtick => try parser.makeUnary("quasiquote"),
		.Comma => try parser.makeUnary("unquote"),
		.DoubleQuote => try parser.makeUnary("doublequote"),
		.CommaAt => try parser.makeUnary("unquote-splice"),
		.Dollar => try parser.parseDollar(),
		.Dot => return error.UnexpectedDot,
	}
}

pub fn pushFrame(self: *Parser) OOM!void {
	try self.frames.append(self.gpa, .{});
}

pub fn popFrame(self: *Parser) Error!void {
	if (self.frames.items.len == 0) return error.UnexpectedRParen;

	const done = self.frames.pop().?;
	const expr = done.root orelse try Expr.nil(self.gpa);
	try self.emit(expr);
}

pub fn emit(self: *Parser, expr: *Expr) Error!void {
	if (self.frames.items.len == 0) {
		try self.exprs.append(self.gpa, expr);
		return;
	}

	var current = &self.frames.items[self.frames.items.len - 1];
	if (current.kind == .Unary) {
		current.tail.* = expr.*;
		self.gpa.destroy(expr);
		try self.popFrame();
		return;
	}

	const nextt = try Expr.pair(self.gpa, expr, try .nil(self.gpa));
	if (current.root == null) {
		current.root = nextt;
		current.tail = nextt.cdr();
	} else {
		current.tail.* = nextt.*;
		current.tail = current.tail.cdr();
		self.gpa.destroy(nextt);
	}
}

fn makeUnary(self: *Parser, name: []const u8) OOM!void {
	const arg = try Expr.pair(self.gpa, try .nil(self.gpa), try .nil(self.gpa));
	const root = try Expr.pair(
		self.gpa,
		try .symbol(self.gpa, name),
		arg,
	);

	try self.frames.append(self.gpa, .{
		.root = root,
		.tail = arg.car(),
		.kind = .Unary,
	});
}

fn parseDollar(self: *Parser) Error!void {
	if (self.tokens[self.pos] == .LParen) {
		try self.makeUnary("ref");
		return;
	}

	const root = try Expr.pair(
		self.gpa,
		try .symbol(self.gpa, "ref"),
		try .nil(self.gpa),
	);
	errdefer root.free(self.gpa);

	var tail = root.cdr();

	switch (self.tokens[self.pos]) {
		.Symbol => |s| {
			const nextt = try Expr.pair(
				self.gpa,
				try .symbol(self.gpa, s.slice),
				try .nil(self.gpa),
			);
			tail.* = nextt.*;
			tail = tail.cdr();
			self.gpa.destroy(nextt);
			self.pos += 1;
		},
		else => return error.ExpectedSymbolAfterDollar,
	}

	while (self.pos < self.tokens.len and
		self.tokens[self.pos] == .Dot)
	{
		self.pos += 1;
		switch (self.tokens[self.pos]) {
			.Symbol => |s| {
				const nextt = try Expr.pair(
					self.gpa,
					try .symbol(self.gpa, s.slice),
					try .nil(self.gpa),
				);
				tail.* = nextt.*;
				tail = tail.cdr();
				self.gpa.destroy(nextt);
				self.pos += 1;
			},
			else => return error.ExpectedSymbolAfterDollar,
		}
	}

	try self.emit(root);
}

fn dupeUnescapePipeSymbol(
	allocator: std.mem.Allocator,
	input: []const u8,
) Error![]u8 {
	var out = try allocator.alloc(u8, input.len);
	errdefer allocator.free(out);

	var src: usize = 0;
	var dst: usize = 0;

	while (src < input.len) {
		if (input[src] == '\\' and src + 1 < input.len) {
			switch (input[src + 1]) {
				'\\', '|' => {
					out[dst] = input[src + 1];
					src += 2;
					dst += 1;
					continue;
				},
				else => {},
			}
		}

		out[dst] = input[src];
		src += 1;
		dst += 1;
	}

	return allocator.realloc(out, dst);
}