/// Lexer use consumer stack as a mode and every char will be passed to the top consumer.
pub const Lexer = @import("reader/lexer.zig");
/// Recursive descent parser that uses an explicit frame stack to track rule expansion.
///
/// Expressions that have not been popped remain owned by the parser and are freed during `deinit`.
pub const Parser = @import("reader/parser.zig");

pub const ReaderOptions = struct {
	/// Preserve newlines as token. They can be used to reduce paren. (No indent and dedent token yet)
	preserve_newlines: bool = false,
	/// Parse dollar expression (i.e `$a.b.c`) according the spec (i.e `(ref a b c)`). On lexer it will emit `Dollar
	/// Symbol() *( Dot Symbol() )`
	dollar_reference: bool = true,
};