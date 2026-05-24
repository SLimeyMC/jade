const std = @import("std");
const SourceLocation = std.builtin.SourceLocation;

pub const Level = enum(u8) {
	debug,
	info,
	warn,
	err,
};

pub const Config = struct {
	level: Level = .debug,
	show_time: bool = true,
	show_scope: bool = true,
	show_level: bool = true,
	show_source: bool = false,
};

pub fn Logger(comptime config: Config) type {
	return struct {
		const Self = @This();
		writer: *std.Io.Writer,
		io: std.Io,

		pub fn scoped(self: *Self, comptime scope: []const u8) ScopedLogger(scope) {
			return .{
				.parent = self,
			};
		}

		pub inline fn debug(
			self: *Self,
			src: SourceLocation,
			comptime fmt: []const u8,
			args: anytype,
		) void {
			self.log("", .debug, fmt, args, src);
		}

		pub inline fn info(
			self: *Self,
			src: SourceLocation,
			comptime fmt: []const u8,
			args: anytype,
		) void {
			self.log("", .info, fmt, args, src);
		}

		pub inline fn warn(
			self: *Self,
			src: SourceLocation,
			comptime fmt: []const u8,
			args: anytype,
		) void {
			self.log("", .warn, fmt, args, src);
		}

		pub inline fn err(
			self: *Self,
			src: SourceLocation,
			comptime fmt: []const u8,
			args: anytype,
		) void {
			self.log("", .err, fmt, args, src);
		}

		fn levelText(comptime level: Level) []const u8 {
			return switch (level) {
				.debug => "DEBUG",
				.info => "INFO",
				.warn => "WARN",
				.err => "ERROR",
			};
		}

		fn log(
			self: *Self,
			comptime scope: []const u8,
			comptime level: Level,
			comptime fmt: []const u8,
			args: anytype,
			src: std.builtin.SourceLocation,
		) void {
			comptime if (@intFromEnum(level) < @intFromEnum(config.level)) return;

			(blk: {
				if (config.show_time) {
					const ts = std.Io.Clock.now(.real, self.io);
					self.writer.print("[{}] ", .{ts.toMilliseconds()}) catch |e| break :blk e;
				}

				if (config.show_scope) {
					if (scope.len != 0) {
						self.writer.print("[{s}] ", .{scope}) catch |e| break :blk e;
					}
				}

				if (config.show_level) {
					self.writer.print("[{s}] ", .{levelText(level)}) catch |e| break :blk e;
				}

				if (config.show_source) {
					self.writer.print(
						"[{s}:{}] ",
						.{ src.file, src.line },
					) catch |e| break :blk e;
				}

				self.writer.print(fmt, args) catch |e| break :blk e;
				self.writer.writeByte('\n') catch |e| break :blk e;
			} catch |e| std.debug.print("{t}", .{e}));
		}
	};
}

fn ScopedLogger(comptime scope: []const u8) type {
	return struct {
		parent: *Logger,

		const Self = @This();

		pub inline fn debug(self: Self, src: SourceLocation, comptime fmt: []const u8, args: anytype) void {
			self.parent.log(scope, .debug, fmt, args, src);
		}

		pub inline fn info(self: Self, src: SourceLocation, comptime fmt: []const u8, args: anytype) void {
			self.parent.log(scope, .info, fmt, args, src);
		}

		pub inline fn warn(self: Self, src: SourceLocation, comptime fmt: []const u8, args: anytype) void {
			self.parent.log(scope, .warn, fmt, args, src);
		}

		pub inline fn err(self: Self, src: SourceLocation, comptime fmt: []const u8, args: anytype) void {
			self.parent.log(scope, .err, fmt, args, src);
		}
	};
}
