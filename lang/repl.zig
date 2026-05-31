/// Example implementation of REPL which injected with as many directive as possible.
const std = @import("std");
const lang = @import("lang");
const reader = lang.reader;
const Scope = lang.Scope;
const Expr = lang.Expr;
const Callables = lang.Callables;
const directive = lang.directive;
const Lexer = lang.reader.Lexer;
const Parser = lang.reader.Parser;

pub fn main(init: std.process.Init) !void {
	const allocator = init.gpa;

	var arena = std.heap.ArenaAllocator.init(allocator);
	defer arena.deinit();
	const a = arena.allocator();

	var env = Scope.init(allocator, null);
	var callables = Callables.init(allocator);

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
		const line = stdin.takeDelimiterInclusive('\n') catch |err| switch (err) {
			error.ReadFailed => break,
			else => return err,
		};
		lexer.source = line;

		_ = try lexer.nextLine();

		if (lexer.paren_depth == 0) {
			const tokens = lexer.tokens.items;
			const exprs = try Parser.parseAll(a, tokens);

			for (exprs) |expr| {
				try stdout.flush();
				const result = try lang.eval(expr, &env, &callables, a);
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