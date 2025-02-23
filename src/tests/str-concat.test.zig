const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;
const common = @import("./common.zig");

test "Str.concat() correctly concatinates strings" {
    const a = testing.allocator;
    const hello_str = "Hello";
    const world_str = ", World!";
    const hello_world_str = "Hello, World!";

    var hello_world = try Str.init(a, hello_str);
    try hello_world.concat(world_str);

    defer hello_world.deinit();

    try testing.expectEqualStrings(hello_world.asSlice(), hello_world_str);

    // --------------------------------------------------------------------- //

    var another_hello = try Str.init(a, hello_str);
    var another_world = try Str.init(a, world_str);
    try another_hello.concat(another_world);
    defer another_hello.deinit();
    defer another_world.deinit();

    try testing.expectEqualStrings(another_hello.asSlice(), hello_world_str);
}

test "Str.concat correctly drops error when input parameter is invalid UTF-8" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        try str.concat(test_slice);
        defer str.deinit();
        try testing.expectFmt(str.asSlice(), "content{s}", .{test_slice});
    }
    for (common.invalid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        defer str.deinit();
        try testing.expectError(Str.Error.InvalidUtf8, str.concat(test_slice));
    }
}

test "Str.concatFmt() correctly concatinates strings" {
    const a = testing.allocator;
    const hello_str = "Hello";
    const world_str = "World!";
    const hello_world_str = "Hello, World!";

    var hello_world = try Str.init(a, hello_str);
    try hello_world.concatFmt(", {s}", .{world_str});

    defer hello_world.deinit();

    try testing.expectEqualStrings(hello_world.asSlice(), hello_world_str);

    // --------------------------------------------------------------------- //

    var another_str = Str.initEmpty(a);
    var another_world = try Str.init(a, world_str);
    try another_str.concatFmt("{s}, {s}", .{ hello_str, another_world });
    defer another_str.deinit();
    defer another_world.deinit();

    try testing.expectEqualStrings(another_str.asSlice(), hello_world_str);
}

test "Str.concatFmt correctly drops error when input parameter is invalid UTF-8" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        try str.concatFmt("{s}", .{test_slice});
        defer str.deinit();
        try testing.expectFmt(str.asSlice(), "content{s}", .{test_slice});
    }
    for (common.invalid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        const original_capacity = str.capacity();
        defer str.deinit();
        try testing.expectError(Str.Error.InvalidUtf8, str.concatFmt("{s}", .{test_slice}));
        try testing.expectEqualStrings(str.asSlice(), "content");
        try testing.expectEqual(str.capacity(), original_capacity);
    }
}
