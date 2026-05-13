const std = @import("std");
const Env = @import("env.zig");
const EvalError = @import("eval.zig").EvalError;

pub const ReaderError = error {
UnexpectedRParen,
UnexpectedEOF,
UnexpectedEndOfStream,
UnterminatedSymbol,
OutOfMemory,
};


pub const Function = struct {
	params: []const []const u8,
	body: *Expr,
	env: *Env,
};

pub const Expr = union(enum) {
	const OOM = error {OutOfMemory};
	Nil,
	Symbol: []const u8,
	Pair: [2]*Expr,
	Integer: i32,
	Bool: bool,
	Function: Function,

	pub fn car(self: *Expr) *Expr { return self.Pair[0]; }
	pub fn cdr(self: *Expr) *Expr { return self.Pair[1]; }

	pub fn toInteger(self: *Expr) EvalError!i32 {
		return switch (self.*) {
			.Nil => return error.NilError,
			.Symbol => |s| std.fmt.parseInt(i32, s, 10) catch return error.TypeError,
			.Integer => |i| i,
			.Bool => |b| @intFromBool(b),
			else => return error.TypeError
		};
	}

	pub fn toIntegerOrZero(self: *Expr) EvalError!i32 {
		return switch (self.*) {
			.Nil => 0,
			.Symbol => |s| std.fmt.parseInt(i32, s, 10) catch return error.TypeError,
			.Integer => |i| i,
			.Bool => |b| @intFromBool(b),
			else => return error.TypeError
		};
	}

	pub fn toBool(self: *Expr) EvalError!bool {
		return switch (self.*) {
			.Nil => return false,
			.Symbol => |s| if (std.mem.eql(u8, s, "t")) true else return error.TypeError,
			.Integer => |i| i > 0,
			else => return error.TypeError
		};
	}

	pub fn isTruthy(self: *const Expr) bool {
		return switch (self.*) {
			.Nil => false,
			.Bool => |b| b,
			else => true,
		};
	}

	pub fn toSymbol(self: *Expr, allocator: std.mem.Allocator) EvalError![]const u8 {
		 switch (self.*) {
			.Nil => return error.NilError,
			.Symbol => |v| return v,
			.Integer => |i| {
				return std.fmt.allocPrint(allocator, "{d}", .{i}) catch return error.TypeError;
			},
			.Bool => |b| {
				return if (b)
					"t"
				else "nil";
			},
			else => return error.TypeError
		}
	}

	pub fn nil(allocator: std.mem.Allocator) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .Nil;
		return e;
	}

	pub fn symbol(allocator: std.mem.Allocator, name: []const u8) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Symbol = name };
		return e;
	}

	pub fn pair(allocator: std.mem.Allocator, a: *Expr, b: *Expr) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Pair = .{ a, b } };
		return e;
	}

	pub fn integer(allocator: std.mem.Allocator, int: i32) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Integer = int };
		return e;
	}

	pub fn boolean(allocator: std.mem.Allocator, b: bool) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Bool = b };
		return e;
	}

	pub fn function(
		allocator: std.mem.Allocator,
		f: Function,
	) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Function = f };
		return e;
	}

	pub fn clone(allocator: std.mem.Allocator, copy: *const Expr) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = copy.*;
		return e;
	}
};

pub const Token = union(enum) {
	LParen,
	RParen,
	Quote,
	Backtick,
	Comma,
	DoubleQuote,
	Newline,
	Symbol: []const u8,
};

pub const ReaderMode = struct {
	preserve_newlines: bool = false,
};

fn isDelimiter(c: u8) bool {
	return std.ascii.isWhitespace(c)
		or c == '(' or c == ')'
		or c == '\'' or c == '`'
		or c == ',' or c == '"'
		or c == '|';
}

pub fn tokenize(allocator: std.mem.Allocator, src: []const u8) ReaderError![]Token {
	var tokens = try std.ArrayList(Token).initCapacity(allocator, 512) ;
	var i: usize = 0;

	while (i < src.len) {
		switch (src[i]) {
			' ', '\t', '\r' => i += 1,
			'\n' => { try tokens.append(allocator, .Newline); i += 1; },
			'(' => { try tokens.append(allocator, .LParen); i += 1; },
			')' => { try tokens.append(allocator, .RParen); i += 1; },
			'\'' => { try tokens.append(allocator, .Quote); i += 1; },
			'`' => { try tokens.append(allocator, .Backtick); i += 1; },
			',' => { try tokens.append(allocator, .Comma); i += 1; },
			'"' => { try tokens.append(allocator, .DoubleQuote); i += 1; },
			'|' => try tokens.append(allocator, .{ .Symbol = try readPipeSymbol(allocator, src, &i) }),
			else => try tokens.append(allocator, .{ .Symbol = try readSymbol(allocator, src, &i) }),
		}
	}

	return tokens.toOwnedSlice(allocator);
}

fn readSymbol(allocator: std.mem.Allocator, src: []const u8, i: *usize) ReaderError![]const u8 {
	const start = i.*;
	while (i.* < src.len and !isDelimiter(src[i.*])) i.* += 1;
	return allocator.dupe(u8, src[start..i.*]);
}

fn readPipeSymbol(allocator: std.mem.Allocator, src: []const u8, i: *usize) ReaderError![]const u8 {
	i.* += 1;
	var buf = try std.ArrayList(u8).initCapacity(allocator, 512);

	while (i.* < src.len) : (i.* += 1) {
		switch (src[i.*]) {
			'|'  => { i.* += 1; return buf.toOwnedSlice(allocator); },
			'\\' => {
				i.* += 1;
				if (i.* >= src.len) return error.UnterminatedSymbol;
				try buf.append(allocator, src[i.*]);
			},
			else => try buf.append(allocator, src[i.*]),
		}
	}

	return error.UnterminatedSymbol;
}

pub fn parse(allocator: std.mem.Allocator, tokens: []Token, mode: ReaderMode) ReaderError!*Expr {
	var i: usize = 0;
	return parseExpr(allocator, tokens, &i, mode);
}

pub fn parseExpr(allocator: std.mem.Allocator, tokens: []Token, i: *usize, mode: ReaderMode) ReaderError!*Expr {
	while (i.* < tokens.len) {
		const tok = tokens[i.*];
		i.* += 1;

		return switch (tok) {
			.Newline => if (mode.preserve_newlines) Expr.symbol(allocator, "newline" ) else continue,
			.Symbol => |s| Expr.symbol(allocator, s ),
			.LParen => parseList(allocator, tokens, i, mode),
			.Quote => makeUnary(allocator, "quote", tokens, i, mode),
			.Backtick => makeUnary(allocator, "quasiquote", tokens, i, mode),
			.Comma => makeUnary(allocator, "unquote", tokens, i, mode),
			.DoubleQuote => makeUnary(allocator, "doublequote", tokens, i, mode),
			.RParen => error.UnexpectedRParen,
		};
	}

	return error.UnexpectedEOF;
}

fn parseList(allocator: std.mem.Allocator, tokens: []Token, i: *usize, mode: ReaderMode) ReaderError!*Expr {
	if (i.* >= tokens.len) return error.UnexpectedEOF;
	if (tokens[i.*] == .RParen) { i.* += 1; return Expr.nil(allocator); }

	const head = try parseExpr(allocator, tokens, i, mode);
	const tail = try parseList(allocator, tokens, i, mode);
	return try Expr.pair(allocator, head, tail);
}

fn makeUnary(allocator: std.mem.Allocator, name: []const u8, tokens: []Token, i: *usize, mode: ReaderMode) ReaderError!*Expr {
	const inner = try parseExpr(allocator, tokens, i, mode);
	return try Expr.pair(
		allocator,
		try Expr.symbol(allocator, name),
		try Expr.pair(allocator, inner, try Expr.nil(allocator))
	);
}