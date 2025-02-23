const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;
const common = @import("./common.zig");

test "Str initializes correctly" {
    const a = testing.allocator;
    const hello_str = "Hello";

    var hello = try Str.init(a, hello_str);
    defer hello.deinit();

    try testing.expectEqualStrings(hello.asSlice(), hello_str);
    try testing.expectEqual(hello.byteCount(), hello_str.len);
}

test "Str.init correctly passes allocation error on init" {
    const a = testing.failing_allocator;
    const allocError = std.mem.Allocator.Error.OutOfMemory;
    try testing.expectError(allocError, Str.init(a, "Born 2 fail"));
}

test "Str.init correctly drops error when constructed from invalid UTF-8" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, test_slice);
        defer str.deinit();
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (common.invalid_utf8_strings) |test_slice| {
        try testing.expectError(Str.Error.InvalidUtf8, Str.init(a, test_slice));
    }
}

test "Str.initFmt correctly initializes formatted string" {
    const a = testing.allocator;

    var hello = try Str.initFmt(a, "Hello, {s}", .{"composable-string"});
    defer hello.deinit();

    try testing.expectEqualStrings(hello.asSlice(), "Hello, composable-string");
}

test "Str.initFmt correctly drops error when constructed from invalid UTF-8" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = try Str.initFmt(a, "some text {s} some text", .{test_slice});
        defer str.deinit();
        try testing.expectFmt(str.asSlice(), "some text {s} some text", .{test_slice});
    }
    for (common.invalid_utf8_strings) |test_slice| {
        const result = Str.initFmt(a, "some text {s} some text", .{test_slice});
        try testing.expectError(Str.Error.InvalidUtf8, result);
    }
}

test "Str.initEmpty correctly initializes empty string" {
    const a = testing.allocator;

    var empty = Str.initEmpty(a);
    try testing.expectEqualStrings(empty.asSlice(), "");
    empty.deinit();

    var empty2 = Str.initEmpty(a);
    defer empty2.deinit();
    try testing.expectEqualStrings(empty2.asSlice(), "");
    try empty2.concat("not so empty anymore");
    try testing.expectEqualStrings(empty2.asSlice(), "not so empty anymore");
}
