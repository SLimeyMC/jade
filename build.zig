const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

	const log = b.addModule("log", .{
		.target = target,
		.optimize = optimize,
		.root_source_file = b.path("log/log.zig"),
	});

	const jade_lang = b.addModule("lang", .{
		.target = target,
		.optimize = optimize,
		.root_source_file = b.path("lang/lang.zig"),
		.imports = &.{
			.{ .name = "log", .module = log },
		}
	});

    const repl_exe = b.addExecutable(.{
		.name = "repl",
		.root_module = b.createModule(.{
            .root_source_file = b.path("lang/repl.zig"),
            .target = target,
			.optimize = optimize,
			.imports = &.{
				.{ .name = "lang", .module = jade_lang },
				.{ .name = "log", .module = log },
			}
		}),
	});

    b.installArtifact(repl_exe);

    const run_step = b.step("run", "Run the repl example");

    const run_cmd = b.addRunArtifact(repl_exe);
	run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
		run_cmd.addArgs(args);
	}
}
