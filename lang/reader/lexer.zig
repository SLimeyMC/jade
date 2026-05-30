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
	const Positioned = struct { start: usize };
	const Sliced = struct { start: usize, slice: []const u8 };

	LParen: Positioned,
	RParen: Positioned,
	Quote: Positioned,
	Backtick: Positioned,
	Comma: Positioned,
	CommaAt: Positioned,
	DoubleQuote: Positioned,
	Newline: Positioned,
	Dollar: Positioned,
	Dot: Positioned,
	Symbol: Sliced,
	PipeSymbol: Sliced,
};

const Consumer = struct {
	ptr: *anyopaque,
	consume: *const fn (*anyopaque, *Lexer,u8) Error!void,
	flush: *const fn (ptr: *anyopaque, lexer: *Lexer) Error!void,
	deinit: *const fn (*anyopaque, std.mem.Allocator) void,
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

fn push(self: *Lexer, comptime tag: std.meta.Tag(Token), start: usize) Error!void {
	try self.tokens.append(self.gpa, switch (tag) {
		.Symbol, .PipeSymbol => @compileError("use pushSlice for Symbol and PipeSymbol"),
		inline else => @unionInit(Token, @tagName(tag), .{ .start = start }),
	});
}

fn omitPush(self: *Lexer, comptime tag: std.meta.Tag(Token), start: usize) Error!void {
	try self.push(tag, start);
	self.pos += 1;
}

fn pushSlice(self: *Lexer, comptime tag: std.meta.Tag(Token), start: usize) Error!void {
	try self.tokens.append(self.gpa, switch (tag) {
		.Symbol, .PipeSymbol => @unionInit(Token, @tagName(tag), .{
			.start = start,
			.slice = self.source[start..self.pos],
		}),
		inline else => @compileError("use push for non-slice tokens"),
	});
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
		.flush = struct {
			fn f(ptrr: *anyopaque, lexer: *Lexer) Error!void {
				const selff: *T = @ptrCast(@alignCast(ptrr));
				if (@hasDecl(T, "flush")) try selff.flush(lexer);
			}
		}.f,
	});
	return ptr;
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
					try lexer.push(.Newline, lexer.pos);
				}
				return;
			},
			'(' => {
				lexer.paren_depth += 1;
				try lexer.omitPush(.LParen, lexer.pos);
			},
			')' =>
			if (lexer.paren_depth > 0) {
				lexer.paren_depth -= 1; try lexer.omitPush(.RParen, lexer.pos);
			} else return error.UnexpectedRParen,
			'\'' => try lexer.omitPush(.Quote, lexer.pos),
			'`' => try lexer.omitPush(.Backtick, lexer.pos),
			',' => if (lexer.peek() == '@'){
				lexer.omit();
				try lexer.omitPush(.CommaAt, lexer.pos);
			} else try lexer.omitPush(.Comma, lexer.pos),
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
			try self.flush(lexer);
			return;
		}
		lexer.omit();
	}

	fn flush(self: *SymbolConsumer, lexer: *Lexer) Error!void {
		try lexer.pushSlice(.Symbol, self.start);
		try lexer.popConsumer();
	}
};

const PipeConsumer = struct {
	escaping: bool = false,
	start: usize,

	fn consume(self: *PipeConsumer, lexer: *Lexer, char: u8) Error!void {
		switch (char) {
			'\\' => self.escaping = !self.escaping,
			'|' => if (!self.escaping) {
				try lexer.pushSlice(.PipeSymbol, self.start);
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
				try lexer.push(.Dollar, lexer.pos);
				try lexer.popConsumer();
				return;
			}

			if (isDelimiter(char)) {
				try lexer.pushSlice(.Symbol, self.start);
				try lexer.popConsumer();
				return;
			}

			try lexer.push(.Dollar, lexer.pos);
			self.started = true;
		}

		if (char == '.') {
			if (lexer.pos == self.start) return error.UnexpectedDotOnDollar;
			try lexer.pushSlice(.Symbol, self.start);

			try lexer.push(.Dot,  lexer.pos);
			lexer.omit();
			self.start = lexer.pos;
			return;
		}

		if (isDelimiter(char)) {
			if (lexer.pos > self.start) try lexer.pushSlice(.Symbol, self.start);
			try lexer.popConsumer();
			return;
		}

		self.started = true;
		lexer.omit();
	}

	fn flush(self: *DollarConsumer, lexer: *Lexer) Error!void {
		if (!self.started) {
			try lexer.push(.Dollar, self.start);
			return;
		}
		// Flushing does not throw error for incomplete symbol for the time being. I need different way of handling it
		// if (lexer.pos == self.start) return error.UnexpectedDotOnDollar;

		try lexer.pushSlice(.Symbol, self.start);
	}
};