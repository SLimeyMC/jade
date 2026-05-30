pub const Lexer = @import("reader/lexer.zig");
pub const Parser = @import("reader/parser.zig");

pub const ReaderOptions = struct {
	preserve_newlines: bool = false,
	dollar_reference: bool = true,
};