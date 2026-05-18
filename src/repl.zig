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
	try stdout.writeAll("jade> ");

	try stdout.flush();

	var lexer = try Lexer.init(
		allocator,
		stdin,
		.{},
	);
	defer lexer.deinit();

	// TODO: simple highlighting
	// FIXME: many many memory leak
	while (true) {
		try lexer.next();

		if (lexer.paren_depth == 0) {
			const token = try lexer.tokens.toOwnedSlice(allocator);
			const exprs = try reader.parse(allocator, token);
			defer allocator.free(token);
			defer allocator.free(exprs);
			for (exprs) |expr| {
				const result = try jade.eval(expr, &env, &callables, allocator);
				try stdout.writeAll("   ~> ");
				try Expr.format(result, stdout);
				try stdout.writeByte('\n');
			}
			try stdout.writeAll("jade> ");
		} else {
			try stdout.writeAll("    > ");
			for (0..lexer.paren_depth) |_|
			try stdout.writeByte(' ');
		}
		try stdout.flush();
	}
}

fn flushLn(w: *std.Io.Writer) !void {
	try w.writeByte('\n');
	try w.flush();
}