const std = @import("std");
const Io = std.Io;

const Node = @import("node.zig");
const Rect = @import("geometry.zig").Rect;
const Pos = @import("geometry.zig").Pos;

const log_mod = @import("log");

pub var log: log_mod.Logger(.{.show_source = true}) = undefined;

const VerticalStackArranger = struct {
	pub const Data = struct {};

	pub fn arrange(scope: *Node.ArrangeScope(VerticalStackArranger)) void {
		const count = scope.edges.len;
		if (count == 0) return;

		const slot_height = @divTrunc(scope.rect.size.y, @as(i32, @intCast(count)));
		for (scope.edges, 0..) |edge, i| {
			edge.child.rect = .{
				.pos = .{
					.x = scope.rect.pos.x,
					.y = scope.rect.pos.y + @as(i32, @intCast(i)) * slot_height,
				},
				.size = .{
					.x = scope.rect.size.x,
					.y = slot_height,
				},
			};
		}
	}
};

fn margin(scope: *Node.MeasureScope, amount: i32) void {
	scope.rect.pos.x += amount;
	scope.rect.pos.y += amount;
	scope.rect.size.x -= amount * 2;
	scope.rect.size.y -= amount * 2;
}

pub fn main(init: std.process.Init) !void {
	var arena_state = std.heap.ArenaAllocator.init(init.gpa);
	defer arena_state.deinit();
	const arena = arena_state.allocator();

	const voidFn = &struct{fn f(_: *Node.MeasureScope) void {}}.f;

	var child_a = Node{
		.arranger = &.{},
		.measurer = voidFn,
		.ptr = &.{},
		.rect = std.mem.zeroInit(Rect, .{})
	};
	var child_b = Node{
		.arranger = &.{},
		.measurer = voidFn,
		.ptr = &.{},
		.rect = std.mem.zeroInit(Rect, .{})
	};
	var child_c = Node{
		.arranger = &.{},
		.measurer = voidFn,
		.ptr = &.{},
		.rect = std.mem.zeroInit(Rect, .{})
	};
	var registry = Node.TagRegistry.init();

	var root_arrangers = [_]Node.ArrangeBuffer{
		try .init(VerticalStackArranger, arena, .{}, &registry),
	};

	var root = Node{
		.arranger = &root_arrangers,
		.measurer = &struct {
			fn f(scope: *Node.MeasureScope) void {
				margin(scope, 16);
			}
		}.f,
		.ptr = &.{},
		.rect = .{
			.pos = Pos.Zero,
			.size = .{ .x = 800, .y = 600 },
		}
	};

	const backed = try arena.dupe(u16, &.{0, 1});
	try registry.put(arena, 0, backed);

	try root.insertEdge(VerticalStackArranger, arena, &child_a, 1, .{});
	try root.insertEdge(VerticalStackArranger, arena, &child_b, 2, .{});
	try root.insertEdge(VerticalStackArranger, arena, &child_c, 0, .{});

	try root.run(0, arena);

	std.debug.print("child_a: pos({}, {}) size({}, {})\n", .{
		child_a.rect.pos.x, child_a.rect.pos.y,
		child_a.rect.size.x, child_a.rect.size.y,
	});
	std.debug.print("child_b: pos({}, {}) size({}, {})\n", .{
		child_b.rect.pos.x, child_b.rect.pos.y,
		child_b.rect.size.x, child_b.rect.size.y,
	});
	std.debug.print("child_c: pos({}, {}) size({}, {})\n", .{
		child_c.rect.pos.x, child_c.rect.pos.y,
		child_c.rect.size.x, child_c.rect.size.y,
	});
}