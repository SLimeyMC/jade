const std = @import("std");
const Env = @import("env.zig");
const EvalError = @import("eval.zig").EvalError;
const Lexer = @import("reader/lexer.zig");
const Token = Lexer.Token;
pub const parse = @import("reader/parser.zig").parse;

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

pub const ReaderOptions = struct {
	const ParseOptions = struct {
		dollar_symbol: bool = true,
		colon_symbol: bool = true,
		hash_symbol: bool = true,
		at_symbol: bool = true,
	};

	preserve_newlines: bool = false,
	parse: ParseOptions = .{}
};