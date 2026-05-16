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
reader: *std.Io.Reader,
options: ReaderOptions,
tokens: std.ArrayList(Token),
consumers: std.ArrayList(Consumer),

paren_depth: usize = 0,

pub fn init(
	allocator: std.mem.Allocator,
	reader: *std.Io.Reader,
	options: ReaderOptions,
) Error!Lexer {
	var lexer = Lexer{
		.gpa = allocator,
		.reader = reader,
		.options = options,
		.tokens = try std.ArrayList(Token).initCapacity(allocator, 64),
		.consumers = try std.ArrayList(Consumer).initCapacity(allocator, 64),
	};
	try lexer.pushConsumer(NormalConsumer, .{});
	return lexer;
}

pub fn deinit(self: *Lexer) void {
	for (self.tokens.items) |token| {
		switch (token) {
			.Symbol => |s| self.gpa.free(s),
			else => {},
		}
	}
	self.tokens.deinit(self.gpa);
	for (self.consumers.items) |consumer|
		consumer.deinit(consumer.ptr, self.gpa);
	self.consumers.deinit(self.gpa);
}

fn peek(self: *Lexer) !u8 {
	return try self.reader.peekByte();
}

fn omit(self: *Lexer) !void {
	_ = try self.reader.takeByte();
}

fn push(self: *Lexer, token: Token) !void {
	try self.tokens.append(self.gpa, token);
}

fn omitPush(self: *Lexer, token: Token) !void {
	try self.omit();
	try self.push(token);
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
		.consume = struct {
			fn call(
				p: *anyopaque,
				lexer: *Lexer,
				ch: u8,
			) Error!void {
				const self_consumer: *T =
					@ptrCast(@alignCast(p));

				try self_consumer.consume(
					lexer,
					ch,
				);
			}
		}.call,
		.deinit = struct {
			fn call(
				p: *anyopaque,
				allocator: std.mem.Allocator,
			) void {
				const self_consumer: *T =
					@ptrCast(@alignCast(p));

				allocator.destroy(self_consumer);
			}
		}.call,
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
	while (true) {
		const char = self.peek() catch |err| switch (err) {
			error.EndOfStream => break,
			else => return err,
		};

		const top = self.consumers.getLastOrNull() orelse return error.ReadFailed;
		try top.consume(top.ptr, self, char);
		if (char == '\n') return;
	}
}

const NormalConsumer = struct {
	fn consume(_: *NormalConsumer, lexer: *Lexer, char: u8) Error!void {
		switch (char) {
			' ', '\t', '\r' => try lexer.omit(),
			'\n' => {
				try lexer.omit();
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
			',' => if (try lexer.peek() == '@'){
				try lexer.omit();
				try lexer.omitPush(.CommaAt);
			} else try lexer.omitPush(.Comma),
			'|' => {
				try lexer.omit();
				try lexer.pushConsumer(PipeConsumer, .{
					.current = try std.ArrayList(u8).initCapacity(lexer.gpa, 128)
				});
			},
			'$' => {
				if (!lexer.options.dollar_reference) {
					try lexer.pushConsumer(SymbolConsumer, .{
						.current = try std.ArrayList(u8)
						.initCapacity(lexer.gpa, 32),
					});
					return;
				}
				try lexer.omit();
				try lexer.pushConsumer(DollarConsumer, .{
					.current = try std.ArrayList(u8).initCapacity(lexer.gpa, 32),
				});
			},
			else =>
				try lexer.pushConsumer(SymbolConsumer, .{
					.current = try std.ArrayList(u8).initCapacity(lexer.gpa, 128)
				}),
		}
	}
};

const SymbolConsumer = struct {
	current: std.ArrayList(u8),

	fn consume(self: *SymbolConsumer, lexer: *Lexer, char: u8) Error!void {
		if (isDelimiter(char)) {
			try lexer.push(.{ .Symbol = try self.current.toOwnedSlice(lexer.gpa) });
			try lexer.popConsumer();
			return;
		}
		try self.current.append(lexer.gpa, char);
		try lexer.omit();
	}

	fn deinit(self: *SymbolConsumer, gpa: std.mem.Allocator) void {
		self.current.deinit(gpa);
	}
};

const PipeConsumer = struct {
	current: std.ArrayList(u8),
	escaping: bool = false,

	fn consume(self: *PipeConsumer, lexer: *Lexer, char: u8) Error!void {
		switch (char) {
			'\\' => if (self.escaping)
				try self.current.appendSlice(lexer.gpa, "\\\\")
			else { self.escaping = true; },
			'|' => if (self.escaping) try self.current.append(lexer.gpa, '|') else {
				try lexer.push(.{ .Symbol = try self.current.toOwnedSlice(lexer.gpa) });
				try lexer.popConsumer();
			},
			else => if (self.escaping)
				try self.current.appendSlice(lexer.gpa, &[_]u8{'\\', char})
			else try self.current.append(lexer.gpa,char,),
		}
		try lexer.omit();
	}

	fn deinit(self: *PipeConsumer, gpa: std.mem.Allocator) void {
		self.current.deinit(gpa);
	}
};

const DollarConsumer = struct {
	current: std.ArrayList(u8),
	started: bool = false,

	fn consume(self: *DollarConsumer, lexer: *Lexer, char: u8) Error!void {
		if (!self.started) {
			if (char == '(') {
				try lexer.push(.Dollar);
				try lexer.popConsumer();
				return;
			}

			if (isDelimiter(char)) {
				try lexer.push(.{ .Symbol = try lexer.gpa.dupe(u8, "$") });
				try lexer.popConsumer();
				return;
			}

			try lexer.push(.Dollar);
		}

		if (char == '.') {
			if (self.current.items.len == 0) return error.UnexpectedDotOnDollar;
			try lexer.push(.{ .Symbol = try self.current.toOwnedSlice(lexer.gpa) });

			self.current = try std.ArrayList(u8).initCapacity(lexer.gpa, 32);
			try lexer.push(.Dot);
			try lexer.omit();
			return;
		}

		if (isDelimiter(char)) {
			if (self.current.items.len != 0)
				try lexer.push(.{
					.Symbol = try self.current.toOwnedSlice(lexer.gpa),
				});

			try lexer.popConsumer();
			return;
		}

		self.started = true;
		try self.current.append(lexer.gpa, char);
		try lexer.omit();
	}

	fn deinit(self: *DollarConsumer, gpa: std.mem.Allocator) void {
		self.current.deinit(gpa);
	}
};