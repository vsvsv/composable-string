const std = @import("std");
const http = std.http;

pub fn downloadFile(
    allocator: std.mem.Allocator,
    filename: []const u8,
    at_url: []const u8,
    save_to_path: []const u8,
) !void {
    const log = std.log.scoped(.downloadFile);
    const cwd = std.fs.cwd();
    var download_dir = try cwd.makeOpenPath(save_to_path, .{ .access_sub_paths = true });
    defer download_dir.close();

    const file_exists = blk: {
        download_dir.access(filename, .{ .mode = .read_write }) catch break :blk false;
        break :blk true;
    };

    if (file_exists) {
        log.info("{s}{s} already exists, skipping download.", .{ save_to_path, filename });
        return;
    } else {
        var client = http.Client{ .allocator = allocator };
        defer client.deinit();

        const file_url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ at_url, filename });
        defer allocator.free(file_url);

        var response_buf = try std.ArrayList(u8).initCapacity(allocator, 1024 * 1024);
        defer response_buf.deinit();

        log.info("Downloading {s}...", .{file_url});
        const req = try client.fetch(.{
            .location = .{ .url = file_url },
            .response_storage = .{ .dynamic = &response_buf },
            .max_append_size = 16 * 1024 * 1024,
        });
        if (req.status != .ok) {
            return error.invalidServerResponse;
        }
        const target_file = try download_dir.createFile(filename, .{});
        defer target_file.close();

        try target_file.writeAll(response_buf.items);
        log.info(">>> Saved to {s}{s}", .{ save_to_path, filename });
    }
}

pub fn downloadAll(
    allocator: std.mem.Allocator,
    files: []const []const u8,
    at_url: []const u8,
    save_to_path: []const u8,
) !void {
    for (files) |filename| {
        try downloadFile(allocator, filename, at_url, save_to_path);
    }
}

pub fn openFile(file_path: []const u8) !std.fs.File {
    const log = std.log.scoped(.openFile);
    const cwd = std.fs.cwd();

    const file_exists = blk: {
        cwd.access(file_path, .{ .mode = .read_write }) catch break :blk false;
        break :blk true;
    };

    if (!file_exists) {
        log.err("{s} not found.", .{file_path});
        return error.noUcdFileFound;
    } else {
        const file = try cwd.openFile(file_path, .{ .mode = .read_write });
        return file;
    }
}

pub fn saveAsFile(file_path: []const u8, str: []const u8) !void {
    const cwd = std.fs.cwd();
    var file = try cwd.createFile(file_path, .{});
    defer file.close();

    try file.writeAll(str);
}
