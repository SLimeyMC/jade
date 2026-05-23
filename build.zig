const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

	const jade_lang = b.addModule("jade", .{
		.target = target,
		.optimize = optimize,
		.root_source_file = b.path("lang/jade-lang.zig"),
	});

    const lang_exe = b.addExecutable(.{
		.name = "jade",
		.root_module = b.createModule(.{
            .root_source_file = b.path("lang/repl.zig"),
            .target = target,
			.optimize = optimize,
			.imports = &.{
				.{ .name = "jade", .module = jade_lang }
			}
		}),
	});

    b.installArtifact(lang_exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(lang_exe);
	run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
		run_cmd.addArgs(args);
	}
}
