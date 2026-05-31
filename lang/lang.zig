const eval_mod = @import("eval.zig");
const expr = @import("expr.zig");

/// Dumb lexer and parser that construct and expand macro syntax into list of s-expression.
pub const reader = @import("reader.zig");
pub const eval = eval_mod.eval;
pub const EvalError = eval_mod.EvalError;
pub const Callables = eval_mod.Callables;
/// A scope that bind the evaluator runtime. It aliases and expand symbol (that hasn't been converted into other
/// internal representation). Using StringHashMap to a Binding struct. Which contain *Expr `value` and bool `mutable`.
///
/// Scopes form a parent chain. If a symbol is not found in the current scope, lookup continues recursively through
/// parent scopes. `pop` and `push` are the mechanism to create new scope and replace with the old one respectively.
pub const Scope = @import("scope.zig");
/// Contain common directive that is included as part of the `Jade` base library.
pub const directive = @import("directive.zig");
pub const Expr = expr.Expr;
pub const Closure = expr.Closure;
