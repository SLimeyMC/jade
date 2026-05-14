const Lexer = @This();
const std = @import("std");
const ReaderOptions = @import("../reader.zig").ReaderOptions;

const Error = error {
UnexpectedRParen,
UnexpectedEOF,
UnexpectedEndOfStream,
UnterminatedSymbol,
OutOfMemory,
};

pub const Token = union(enum) {
	LParen,
	RParen,
	Quote,
	Backtick,
	Comma,
	DoubleQuote,
	Newline,
	// DollarSymbol: []const []const u8,
	// ColonSymbol: []const u8,
	// HashSymbol: []const u8,
	// AtSymbol: []const u8,
	Symbol: []const u8,
};

allocator: std.mem.Allocator,
reader: std.Io.Reader,
tokens: std.ArrayList(Token),

fn peek(self: *Lexer) !u8 {
	return try self.reader.peekByte();
}

fn take(self: *Lexer) !u8 {
	return try self.reader.takeByte();
}

fn push(self: *Lexer, token: Token) !void {
	try self.tokens.append(self.allocator, token);
}

fn takePush(self: *Lexer, token: Token) !void {
	_ = try self.take();
	try self.push(token);
}

inline fn scanPush(
	self: *Lexer,
	comptime f: fn (std.mem.Allocator, *std.Io.Reader) Error!Token,
) Error!void {
	try self.push(try f(
		self.allocator,
		&self.reader,
	));
}

pub fn tokenize(allocator: std.mem.Allocator, reader: std.Io.Reader, _: ReaderOptions) Error![]Token {
	var lex = Lexer{
		.allocator = allocator,
		.reader = reader,
		.tokens = try std.ArrayList(Token).initCapacity(allocator, 512),
	};

	while (try lex.peek()) |ch| {
		switch (ch) {
			' ', '\t', '\r' => _ = try lex.take(),
			'\n' => try lex.takePush(.Newline),
			'(' => try lex.takePush(.LParen),
			')' => try lex.takePush(.RParen),
			'\'' => try lex.takePush(.Quote),
			'`' => try lex.takePush(.Backtick),
			',' => try lex.takePush(.Comma),
			'"' => try lex.takePush(.DoubleQuote),
			'|' => try lex.scanPush(readPipeSymbol),
			else => try lex.scanPush(readSymbol),
		}
	}

	return lex.tokens.toOwnedSlice(allocator);
}

fn readSymbol(
	allocator: std.mem.Allocator,
	reader: *std.Io.Reader,
) Error!Token {
	var buf = std.ArrayList(u8){};

	while (try reader.peekByte()) |ch| {
		if (isDelimiter(ch)) break;
		try buf.append(
			allocator,
			(try reader.takeByte()).?,
		);
	}
	return .{ .Symbol = try buf.toOwnedSlice(allocator) };
}

fn readPipeSymbol(
	allocator: std.mem.Allocator,
	reader: *std.Io.Reader,
) Error!Token {
	_ = try reader.takeByte();
	var buf = std.ArrayList(u8){};
	while (try reader.takeByte()) |ch| {
		switch (ch) {
			'\\' => {
				const next = (try reader.takeByte()) orelse return error.UnterminatedSymbol;
				switch (next) {
					'|', '\\' => try buf.append(allocator, next),
					else => {
                        try buf.append(allocator, '\\');
						try buf.append(allocator, next);
					},
				}
			},
			'|' => return .{ .Symbol = try buf.toOwnedSlice(allocator) },
			else => try buf.append(allocator, ch),
		}
	}
	return error.UnterminatedPipeSymbol;
}

fn isDelimiter(ch: u8) bool {
	return switch (ch) {
		' ', '\t', '\r', '\n',
		'(', ')',
		'\'', '`', ',', '"',
		'|' => true,
		else => false,
	};
}