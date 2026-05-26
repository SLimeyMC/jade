const Node = @This();
const std = @import("std");
const Rect = @import("geometry.zig").Rect;

pub const MeasureScope = struct {
	rect: Rect,
};

const Measure = *const fn (scope: *MeasureScope) void;

pub const TagRegistry = struct {
	map: std.AutoHashMapUnmanaged(u16, []const u16),

	pub fn init() TagRegistry {
		return .{ .map = std.AutoHashMapUnmanaged(u16, []const u16).empty };
	}

	pub fn deinit(self: *TagRegistry, allocator: std.mem.Allocator) void {
		self.map.deinit(allocator);
	}

	pub fn put(self: *TagRegistry, allocator: std.mem.Allocator, tag: u16, backed: []const u16) !void {
		try self.map.put(allocator, tag, backed);
	}

	pub fn get(self: *const TagRegistry, tag: u16) ?[]const u16 {
		return self.map.get(tag);
	}
};

fn Edge(comptime T: type) type {
	return struct {
		child: *Node,
		tag: u16,
		data: T,
	};
}

pub fn ArrangeScope(comptime Arranger: type) type {
	return struct {
		const Self = @This();

		state: *Arranger,
		edges: []const *Edge(Arranger.Data),
		rect: Rect,

		pub fn arrange(self: *Self) void {
			Arranger.arrange(self);
		}
	};
}

pub const ArrangeBuffer = struct {
	type_id: usize,
	state: *anyopaque,
	buckets: std.array_hash_map.Auto(u16, std.ArrayList(*anyopaque)),
	rect: Rect,
	registry: *const TagRegistry,
	appendEdge: *const fn (buffer: *ArrangeBuffer, allocator: std.mem.Allocator, edge: *anyopaque) error{OutOfMemory}!void,
	arrange: *const fn (buffer: *ArrangeBuffer, tag: u16, allocator: std.mem.Allocator) error{OutOfMemory}!void,

	pub fn init(
		comptime Arranger: type,
		allocator: std.mem.Allocator,
		arranger: Arranger,
		registry: *const TagRegistry,
	) !ArrangeBuffer {
		const state = try allocator.create(Arranger);
		state.* = arranger;
		return .{
			.type_id = typeId(Arranger.Data),
			.state = state,
			.buckets = .empty,
			.rect = std.mem.zeroes(Rect),
			.registry = registry,
			.appendEdge = struct {
				fn f(buffer: *ArrangeBuffer, allocatorr: std.mem.Allocator, edge: *anyopaque) error{OutOfMemory}!void {
					const edgee: *Edge(Arranger.Data) = @ptrCast(@alignCast(edge));
					const entry = try buffer.buckets.getOrPut(allocatorr, edgee.tag);
					if (!entry.found_existing) entry.value_ptr.* = std.ArrayList(*anyopaque).empty;
					try entry.value_ptr.append(allocatorr, edge);
				}
			}.f,
			.arrange = struct {
				fn f(buffer: *ArrangeBuffer, tag: u16, allocatorr: std.mem.Allocator) error{OutOfMemory}!void {
					const statee: *Arranger = @ptrCast(@alignCast(buffer.state));
					const backed_tags = buffer.registry.get(tag) orelse &[_]u16{tag};

					var edges = std.ArrayList(*Edge(Arranger.Data)).empty;
					defer edges.deinit(allocatorr);
					for (backed_tags) |backed| {
						if (buffer.buckets.get(backed)) |bucket| {
							for (bucket.items) |item| {
								try edges.append(allocatorr, @as(*Edge(Arranger.Data), @ptrCast(@alignCast(item))));
							}
						}
					}

					var scope = ArrangeScope(Arranger){
						.state = statee,
						.edges = edges.items,
						.rect = buffer.rect,
					};
					scope.arrange();
				}
			}.f,
		};
	}

	pub fn setRect(self: *ArrangeBuffer, rect: Rect) void {
		self.rect = rect;
	}
};

parent: ?*Node = null,
rect: Rect,
measurer: Measure,
arranger: []ArrangeBuffer,
ptr: *anyopaque,

pub fn insertEdge(self: *Node, comptime Arranger: type, allocator: std.mem.Allocator, child: *Node, tag: u16, data: Arranger.Data) !void {
	const id = typeId(Arranger.Data);
	for (self.arranger) |*buffer| {
		if (buffer.type_id == id) {
			const edge = try allocator.create(Edge(Arranger.Data));
			edge.* = .{.child = child,.tag = tag,.data=data};
			try buffer.appendEdge(buffer, allocator, @ptrCast(edge));
			return;
		}
	}
}

pub fn run(self: *Node, tag: u16, allocator: std.mem.Allocator) !void {
	var scope = MeasureScope{ .rect = self.rect };
	self.measurer(&scope);
	for (self.arranger) |*buffer| {
		buffer.setRect(scope.rect);
		try buffer.arrange(buffer, tag, allocator);
	}
}

pub fn typeId(comptime T: type) u32 {
	return @intFromError(@field(anyerror, @typeName(T)));
}
