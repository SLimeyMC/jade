const std = @import("std");
const jade = @import("jade");
const reader = jade.reader;
const Scope = jade.Scope;
const Expr = jade.Expr;
const Callables = jade.Callables;
const directive = jade.directive;
const Lexer = jade.Lexer;

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const a = arena.allocator();

	var env = Scope.init(a, null);
	var callables = Callables.init(a);

	try directive.init(&callables);

	var stdin_buffer: [4096]u8 = undefined;
	var stdout_buffer: [4096]u8 = undefined;

    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buffer);
	const stdin= &stdin_reader.interface;

	var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
	const stdout = &stdout_writer.interface;

	try stdout.writeAll("Running Jade Lisp 1.0.0\n");

	var lexer = try Lexer.initFromSlice(a, "", .{});
	defer lexer.deinit();

	try stdout.writeAll("jade> ");
	try stdout.flush();

	while (true) {
		const line = stdin.takeDelimiter('\n') catch |err| switch (err) {
			error.ReadFailed => break,
			else => return err,
		} orelse return;

		const source = try std.mem.concat(a, u8, &.{ lexer.source, line, "\n" });
		lexer.source = source;

		_ = try lexer.nextLine();

		if (lexer.paren_depth == 0) {
			const tokens = lexer.tokens.items;
			const exprs = try reader.parse(a, tokens);

			var iter = env.map.valueIterator();
			while (iter.next()) |binding| {
				try Expr.format(binding.value, stdout);
			} else { try stdout.flush(); }

			for (exprs) |expr| {
				try stdout.flush();
				const result = try jade.eval(expr, &env, &callables, a);
				try stdout.writeAll("   ~> ");
				try Expr.format(result, stdout);
				try stdout.writeByte('\n');
			}

			lexer.tokens.clearRetainingCapacity();
			lexer.source = "";
			lexer.pos = 0;

			try stdout.writeAll("jade> ");
		} else {
			try stdout.writeAll("    > ");
			for (0..lexer.paren_depth) |_| try stdout.writeByte(' ');
		}
		try stdout.flush();
		_ = arena.reset(.{ .retain_with_limit = 4096 });
	}
}

fn flushLn(w: *std.Io.Writer) !void {
	try w.writeByte('\n');
	try w.flush();
}