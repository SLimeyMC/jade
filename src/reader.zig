const std = @import("std");
const Scope = @import("scope.zig");
const Lexer = @import("reader/lexer.zig");
const Token = Lexer.Token;
pub const parse = @import("reader/parser.zig").parse;

pub const Internal = opaque {
	pub const Lexer = @import("reader/lexer.zig");
	pub const parse = @import("reader/parser.zig").parse;
};

pub const ReaderOptions = struct {
	preserve_newlines: bool = false,
	dollar_reference: bool = true,
};