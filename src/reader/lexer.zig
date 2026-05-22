const Lexer = @This();
const std = @import("std");
const ReaderOptions = @import("../reader.zig").ReaderOptions;

const Error = error {
UnexpectedPop,
UnexpectedRParen,
UnexpectedEOF,
UnterminatedSymbol,
UnexpectedDotOnDollar,
} || std.mem.Allocator.Error || std.Io.Reader.Error;

pub const Token = union(enum) {
	LParen,
	RParen,
	Quote,
	Backtick,
	Comma,
	CommaAt,
	DoubleQuote,
	Newline,
	Dollar,
	Dot,
	Symbol: []const u8,
	PipeSymbol: []const u8,
};

const Consumer = struct {
	ptr: *anyopaque,
	consume: *const fn (
		*anyopaque,
		*Lexer,
		u8,
	) Error!void,
	deinit: *const fn (
		*anyopaque,
		std.mem.Allocator,
	) void,
};

gpa: std.mem.Allocator,
source: []const u8,
owns_source: bool,
pos: usize,
options: ReaderOptions,
tokens: std.ArrayList(Token),
consumers: std.ArrayList(Consumer),

paren_depth: usize = 0,

pub fn initFromSlice(
	allocator: std.mem.Allocator,
	source: []const u8,
	options: ReaderOptions,
) Error!Lexer {
	var lexer = Lexer{
		.gpa = allocator,
		.source = source,
		.owns_source = false,
		.pos = 0,
		.options = options,
		.tokens = try std.ArrayList(Token).initCapacity(allocator, 64),
		.consumers = std.ArrayList(Consumer).empty,
		.paren_depth = 0,
	};
	try lexer.pushConsumer(NormalConsumer, .{});
	return lexer;
}

pub fn initFromReader(
	allocator: std.mem.Allocator,
	reader: *std.Io.Reader,
	options: ReaderOptions,
) Error!Lexer {
	const source = reader.readAlloc(allocator, std.math.maxInt(usize)) catch
		return error.ReadFailed;
	var lexer = try initFromSlice(allocator, source, options);
	lexer.owns_source = true;
	return lexer;
}

pub fn deinit(self: *Lexer) void {
	self.tokens.deinit(self.gpa);
	for (self.consumers.items) |consumer|
		consumer.deinit(consumer.ptr, self.gpa);
	self.consumers.deinit(self.gpa);
	if (self.owns_source) self.gpa.free(self.source);
}

fn peek(self: *Lexer) ?u8 {
	const nextt = self.pos + 1;
	if (nextt >= self.source.len) return null;
	return self.source[nextt];
}

fn omit(self: *Lexer) void {
	self.pos += 1;
}

fn push(self: *Lexer, token: Token) !void {
	try self.tokens.append(self.gpa, token);
}

fn omitPush(self: *Lexer, token: Token) !void {
	try self.push(token);
	self.pos += 1;
}

fn pushConsumer(
	self: *Lexer,
	comptime T: type,
	value: T,
) !void {
	const ptr = try self.gpa.create(T);
	ptr.* = value;

	try self.consumers.append(self.gpa, .{
		.ptr = ptr,
		.consume = @ptrCast(&T.consume),
		.deinit = struct {
			fn d(ptrr: *anyopaque, gpa: std.mem.Allocator) void {
				const selff: *T = @ptrCast(@alignCast(ptrr));
				if (@hasDecl(T, "deinit")) selff.deinit(gpa);
				gpa.destroy(selff);
			}
		}.d,
	});
}

fn popConsumer(self: *Lexer) Error!void {
	const pop = self.consumers.pop() orelse return error.UnexpectedPop;
	pop.deinit(pop.ptr, self.gpa);
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

pub fn next(self: *Lexer) Error!void {
	while (self.pos < self.source.len) {
		const char = self.source[self.pos];
		const top = self.consumers.getLast();
		try top.consume(top.ptr, self, char);
	}
}

pub fn nextLine(self: *Lexer) Error!bool {
	while (self.pos < self.source.len) {
		const char = self.source[self.pos];
		const top = self.consumers.getLast();
		try top.consume(top.ptr, self, char);
		if (char == '\n') return true;
	}
	return false;
}


const NormalConsumer = struct {
	fn consume(_: *NormalConsumer, lexer: *Lexer, char: u8) Error!void {
		switch (char) {
			' ', '\t', '\r' => lexer.omit(),
			'\n' => {
				lexer.omit();
				if (lexer.options.preserve_newlines) {
					try lexer.push(.Newline);
				}
				return;
			},
			'(' => {
				lexer.paren_depth += 1;
				try lexer.omitPush(.LParen);
			},
			')' =>
			if (lexer.paren_depth > 0) {
				lexer.paren_depth -= 1; try lexer.omitPush(.RParen);
			} else return error.UnexpectedRParen,
			'\'' => try lexer.omitPush(.Quote),
			'`' => try lexer.omitPush(.Backtick),
			',' => if (lexer.peek() == '@'){
				lexer.omit();
				try lexer.omitPush(.CommaAt);
			} else try lexer.omitPush(.Comma),
			'|' => {
				lexer.omit();
				try lexer.pushConsumer(PipeConsumer, .{ .start = lexer.pos });
			},
			'$' => {
				if (!lexer.options.dollar_reference) {
					try lexer.pushConsumer(SymbolConsumer, .{ .start = lexer.pos });
					return;
				}
				lexer.omit();
				try lexer.pushConsumer(DollarConsumer, .{ .start = lexer.pos });
			},
			else =>
				try lexer.pushConsumer(SymbolConsumer, .{ .start = lexer.pos }),
		}
	}
};

const SymbolConsumer = struct {
	start: usize,

	fn consume(self: *SymbolConsumer, lexer: *Lexer, char: u8) Error!void {
		if (isDelimiter(char)) {
			try lexer.push(.{ .Symbol = lexer.source[self.start..lexer.pos] });
			try lexer.popConsumer();
			return;
		}
		lexer.omit();
	}
};

const PipeConsumer = struct {
	escaping: bool = false,
	start: usize,

	fn consume(self: *PipeConsumer, lexer: *Lexer, char: u8) Error!void {
		switch (char) {
			'\\' => self.escaping = !self.escaping,
			'|' => if (!self.escaping) {
				try lexer.push(.{ .PipeSymbol = lexer.source[self.start..lexer.pos] });
				try lexer.popConsumer();
			},
			else => {},
		}
		lexer.omit();
	}
};

const DollarConsumer = struct {
	started: bool = false,
	start: usize,

	fn consume(self: *DollarConsumer, lexer: *Lexer, char: u8) Error!void {
		if (!self.started) {
			if (char == '(') {
				try lexer.push(.Dollar);
				try lexer.popConsumer();
				return;
			}

			if (isDelimiter(char)) {
				try lexer.push(.{ .Symbol = lexer.source[self.start - 1..lexer.pos] });
				try lexer.popConsumer();
				return;
			}

			try lexer.push(.Dollar);
			self.started = true;
		}

		if (char == '.') {
			if (lexer.pos == self.start) return error.UnexpectedDotOnDollar;
			try lexer.push(.{ .Symbol = lexer.source[self.start..lexer.pos] });

			self.start = lexer.pos;
			try lexer.push(.Dot);
			lexer.omit();
			return;
		}

		if (isDelimiter(char)) {
			if (lexer.pos > self.start) try lexer.push(.{ .Symbol = lexer.source[self.start..lexer.pos] });
			try lexer.popConsumer();
			return;
		}

		self.started = true;
		lexer.omit();
	}
};