const std = @import("std");
const Scope = @import("scope.zig");

const Error = @import("eval.zig").EvalError;

pub const Closure = struct {
	params: []const []const u8,
	body: *Expr,
	scope: *Scope,
};

pub const Expr = union(enum) {
	const OOM = std.mem.Allocator.Error;
	Nil,
	Symbol: []const u8,
	Pair: [2]*Expr,
	Integer: i32,
	Bool: bool,
	Closure: Closure,

	pub fn car(self: *Expr) *Expr { return self.Pair[0]; }
	pub fn cdr(self: *Expr) *Expr { return self.Pair[1]; }

	pub fn toInteger(self: *Expr) Error!i32 {
		return switch (self.*) {
			.Nil => return error.NilError,
			.Symbol => |s| std.fmt.parseInt(i32, s, 10) catch return error.TypeError,
			.Integer => |i| i,
			.Bool => |b| @intFromBool(b),
			else => return error.TypeError
		};
	}

	pub fn toIntegerOrZero(self: *Expr) Error!i32 {
		return switch (self.*) {
			.Nil => 0,
			.Symbol => |s| std.fmt.parseInt(i32, s, 10) catch return error.TypeError,
			.Integer => |i| i,
			.Bool => |b| @intFromBool(b),
			else => return error.TypeError
		};
	}

	pub fn toBool(self: *Expr) Error!bool {
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

	pub fn toSymbol(self: *Expr, allocator: std.mem.Allocator) Error![]const u8 {
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
		f: Closure,
	) OOM!*Expr {
		const e = try allocator.create(Expr);
		e.* = .{ .Closure = f };
		return e;
	}

	pub fn clone(allocator: std.mem.Allocator, copy: *const Expr) OOM!*Expr {
		const e = try allocator.create(Expr);
		switch (copy.*) {
			.Symbol => |s| e.* = .{.Symbol = try allocator.dupe(u8, s)},
			.Pair => |p| e.* = .{.Pair = .{try Expr.clone(allocator, p[0]), try Expr.clone(allocator, p[1])}},
			else => {
				e.* = copy.*;
			}
		}
		return e;
	}

	pub fn format(
		self: *Expr,
		writer: *std.Io.Writer,
	) !void {
		switch (self.*) {
			.Nil => try writer.writeAll("()"),
			.Symbol => |s| try writer.writeAll(s),
			.Pair => {
				try writer.writeByte('(');
				try format(self.car(), writer);
				var node = self.cdr();
				while (node.* == .Pair) : (node = node.cdr()) {
					try writer.writeByte(' ');
					try format(node.car(), writer);
				}
				if (node.* != .Nil) {
					try writer.writeAll(" . ");
					try format(node, writer);
				}
				try writer.writeByte(')');
			},
			.Integer => |i| try writer.print("{d}", .{i}),
			.Bool => |b| try if (b) writer.writeAll("t") else writer.writeAll("nil"),
			.Closure => |f| {
				try writer.print("(fn ({any})\n ", .{f.params});
				try format(f.body, writer);
				try writer.writeAll(")");
			}
		}
	}
};
