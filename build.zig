const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_version = getLibraryBuildVersion(b) catch unreachable;
    const build_options = b.addOptions();
    build_options.addOption(std.SemanticVersion, "lib_version", lib_version);

    //--- Static library

    const lib = b.addStaticLibrary(.{
        .name = "composable-string",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/composable-string.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/composable-string.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    //--- Executable from src/main.zig

    const mainExe = b.addExecutable(.{
        .name = "composable-string",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    mainExe.root_module.addOptions("build_options", build_options);

    b.installArtifact(mainExe);

    const run_main_exe_cmd = b.addRunArtifact(mainExe);
    run_main_exe_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_main_exe_cmd.addArgs(args);
    }

    const run_main_exe_step = b.step("run", "Run the app");
    run_main_exe_step.dependOn(&run_main_exe_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    //--- Executable from src/tools/gen-tables/main.zig

    const gen_unicode_tables_exe = b.addExecutable(.{
        .name = "gen-tables",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tools/gen-tables/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    gen_unicode_tables_exe.root_module.addOptions("build_options", build_options);
    gen_unicode_tables_exe.root_module.addImport("composable-string", lib.root_module);

    b.installArtifact(gen_unicode_tables_exe);

    const run_gen_tables_cmd = b.addRunArtifact(gen_unicode_tables_exe);
    run_gen_tables_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_gen_tables_cmd.addArgs(args);
    }

    const run_gen_tables_step = b.step("gen-tables", "Generate unicode tables from UCD database");
    run_gen_tables_step.dependOn(&run_gen_tables_cmd.step);

    //--- Run tests step

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);

    //--- Setup documentation generation

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

        var cmd_stdout: std.ArrayListUnmanaged(u8) = .empty;
        var cmd_stderr: std.ArrayListUnmanaged(u8) = .empty;
        try git_hash_command.collectOutput(b.allocator, &cmd_stdout, &cmd_stderr, 1024);

        _ = try git_hash_command.wait();

        const stdout_str = try std.fmt.bufPrint(&git_hash_str_buf, "{s}", .{cmd_stdout.items});
        const git_hash_str = std.mem.trim(u8, stdout_str, " \n");

        cmd_stderr.deinit(b.allocator);
        cmd_stdout.deinit(b.allocator);

        break :blk git_hash_str;
    };

    const full_version_str = try std.fmt.allocPrint(b.allocator, "{s}+{s}", .{ version_str, git_hash_str });
    const version = try std.SemanticVersion.parse(full_version_str);

    return version;
}
