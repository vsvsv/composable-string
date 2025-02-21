const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_version = getLibraryBuildVersion(b) catch unreachable;
    const build_options = b.addOptions();
    build_options.addOption(std.SemanticVersion, "lib_version", lib_version);

    const lib = b.addStaticLibrary(.{
        .name = "composable-string",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/composable-string.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "composable-string",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addOptions("build_options", build_options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/composable-string.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    // Setup documentation generation
    const docs_step = b.step("docs", "Emit docs");

    const docs_install = b.addInstallDirectory(.{
        .install_dir = .prefix,
        .install_subdir = "docs",
        .source_dir = lib.getEmittedDocs(),
    });

    docs_step.dependOn(&docs_install.step);
    b.default_step.dependOn(docs_step);
}

/// Tries to collect current build version by reading
/// `build.zig.zon` and getting last commit hash.
fn getLibraryBuildVersion(b: *std.Build) !std.SemanticVersion {
    var version_str_buf: [1024]u8 = undefined;
    const version_str = blk: {
        var file = try std.fs.cwd().openFile("build.zig.zon", .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var version_str_src: ?[]u8 = null;
        while (try in_stream.readUntilDelimiterOrEof(&version_str_buf, '\n')) |line| {
            if (std.mem.indexOf(u8, line, ".version =") != null) {
                version_str_src = line;
                break;
            }
        }
        var version_str = version_str_src orelse {
            return error.VersionFieldNotFoundInBuildZon;
        };

        const v_start = std.mem.indexOf(u8, version_str, "\"").?;
        version_str = version_str[v_start + 1 ..];
        const v_end = std.mem.indexOf(u8, version_str, "\"").?;
        version_str = version_str[0..v_end];
        break :blk version_str;
    };

    var git_hash_str_buf: [1024]u8 = undefined;
    const git_hash_str = blk: {
        var git_hash_command = std.process.Child.init(
            &[_][]const u8{ "git", "describe", "--dirty=-custom", "--always" },
            b.allocator,
        );
        git_hash_command.stdout_behavior = .Pipe;
        git_hash_command.stderr_behavior = .Pipe;
        try git_hash_command.spawn();

        var cmd_stdout = std.ArrayList(u8).init(b.allocator);
        var cmd_stderr = std.ArrayList(u8).init(b.allocator);
        try git_hash_command.collectOutput(&cmd_stdout, &cmd_stderr, 1024);

        _ = try git_hash_command.wait();

        const stdout_str = try std.fmt.bufPrint(&git_hash_str_buf, "{s}", .{cmd_stdout.items});
        const git_hash_str = std.mem.trim(u8, stdout_str, " \n");

        cmd_stderr.deinit();
        cmd_stdout.deinit();

        break :blk git_hash_str;
    };

    const full_version_str = try std.fmt.allocPrint(b.allocator, "{s}+{s}", .{ version_str, git_hash_str });
    const version = try std.SemanticVersion.parse(full_version_str);

    return version;
}
