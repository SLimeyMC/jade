const std = @import("std");
const reader = @import("reader.zig");
const eval = @import("eval.zig");
const Env = @import("env.zig");
const Expr = reader.Expr;
const FnTable = eval.FnTable;
const Fn = eval.Fn;
const arithmethic = @import("directive/arithmethic.zig");
const comparison = @import("directive/comparison.zig");
const conditional = @import("directive/conditional.zig");
const quote = @import("directive/quote.zig");

fn fnLet(
	args: []const *Expr,
	env: *Env,
	fns: *FnTable,
	allocator: std.mem.Allocator,
) eval.EvalError!*Expr {
	if (args.len != 2)return error.ArityError;
	const name = switch (args[0].*) {
		.Symbol => |s| s,
		else => return error.TypeError,
	};
	const value = try eval.eval(args[1], env, fns, allocator);
	try env.def(name, .{.value = value.*, .mutable = false});
	return Expr.nil(allocator);
}

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const a = arena.allocator();

	var env = Env.init(a, null);
	var fns = FnTable.init(a);

	try fns.put("+", .{ .eager = arithmethic.fnAdd });
	try fns.put("-", .{ .eager = arithmethic.fnSub });
	try fns.put("*", .{ .eager = arithmethic.fnMul });
	try fns.put("/", .{ .eager = arithmethic.fnDiv });
	try fns.put("=", .{ .eager = comparison.fnEql });
	try fns.put("=?", .{ .eager = comparison.fnStrictEql });
	try fns.put(">", .{ .eager = comparison.fnLt });
	try fns.put(">=", .{ .eager = comparison.fnLte });
	try fns.put("<", .{ .eager = comparison.fnGt });
	try fns.put("<=", .{ .eager = comparison.fnGte });
	try fns.put("cond", .{ .special = conditional.fnWhen });
	try fns.put("quote", .{ .special = quote.fnQuote });
	try fns.put("quasiquote", .{ .special = quote.fnQuasiquote });
	try fns.put("let", .{ .special = fnLet });


	var stdin_buffer: [4096]u8 = undefined;
	var stdout_buffer: [4096]u8 = undefined;

    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buffer);
	const stdin= &stdin_reader.interface;

	var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
	const stdout = &stdout_writer.interface;

	try stdout.writeAll("Running Jade Lisp 1.0.0\n");
	try stdout.writeAll("jade> ");

	try stdout.flush();

	// TODO: multi-line expr
	// TODO: simple highlighting
	while (stdin.takeDelimiter('\n')) |line| {
		const trimmed = std.mem.trim(u8, line.?, &std.ascii.whitespace);
		if (trimmed.len == 0) {
			try stdout.writeAll("jade> ");
			try stdout.flush();
			continue;
		}

		const tokens = reader.tokenize(a, trimmed) catch |err| {
			try stdout.print("tokenize error: {}\n", .{err});
			try stdout.writeAll("jade> ");
			try stdout.flush();
			continue;
		};

		var i: usize = 0;
		while (i < tokens.len) {
			const expr = reader.parseExpr(a, tokens, &i, .{}) catch |err| {
				try stdout.print("parse error: {}", .{err});
				try flushLn(stdout);
				break;
			};
			const result = eval.eval(expr, &env, &fns, a) catch |err| {
				try stdout.print("eval error: {}", .{err});
				try flushLn(stdout);
				break;
			};
			if (result.* != .Nil) {
				try stdout.writeAll("  ~~> ");
				try printExpr(result, stdout);
				try flushLn(stdout);
			}
		}

		try stdout.writeAll("jade> ");
		try stdout.flush();
	} else |err| switch (err) {
		error.StreamTooLong => {
			// the line was longer than the internal buffer
            return err;
		},
		error.ReadFailed => {
			// the read failed
            return err;
		},
	}
}

fn printExpr(expr: *Expr, writer: *std.Io.Writer) !void {
	switch (expr.*) {
		.Nil => try writer.writeAll("()"),
		.Symbol => |s| try writer.writeAll(s),
		.Pair => {
			try writer.writeByte('(');
			var node = expr.*;
			var first = true;
			while (node == .Pair) : (node = node.Pair[1].*) {
				if (!first) try writer.writeByte(' ');
				try printExpr(node.Pair[0], writer);
				first = false;
			}
			if (node != .Nil) {
				try writer.writeAll(" . ");
				try printExpr(&node, writer);
			}
			try writer.writeByte(')');
		},
		.Integer => |i| try writer.print("{d}", .{i}),
		.Bool => |b| try if (b) writer.writeAll("t") else writer.writeAll("nil"),
		.Function => |f| {
			try writer.print("(lambda ({any})\n", .{f.params});
			try writer.print("    {})\n", .{f.body});
		}
	}
}

fn flushLn(w: *std.Io.Writer) !void {
	try w.writeByte('\n');
	try w.flush();
}