const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;
const common = @import("./common.zig");

test "Str initialization tests" {
    _ = @import("./str-init.test.zig");
}

test "Str trimming tests" {
    _ = @import("./str-trim.test.zig");
}

test "Str writer tests" {
    _ = @import("./str-writer.test.zig");
}

test "Str concatination tests" {
    _ = @import("./str-concat.test.zig");
}

test "Str.clear correctly removes string content" {
    const a = testing.allocator;

    var str = try Str.init(a, "content");
    str.clear();
    try testing.expectEqualStrings(str.asSlice(), "");
    str.deinit();

    var str2 = try Str.init(a, "finally");
    defer str2.deinit();
    try str2.concat(", more content");
    str2.clear();
    try testing.expectEqualStrings("", str2.asSlice());
    try testing.expectEqual(str2.byteCount(), 0);
}

test "Str.set should correctly change the content of a string" {
    const a = testing.allocator;

    var str = try Str.init(a, "content 1");
    const new_content_literal = "new content";
    try str.set(new_content_literal);
    try testing.expectEqualStrings(str.asSlice(), new_content_literal);
    try testing.expect(str.asSlice().ptr != new_content_literal.ptr);
    str.deinit();

    var str2 = try Str.init(a, "content 2");
    defer str2.deinit();
    try str2.set("");
    try testing.expectEqualStrings("", str2.asSlice());
    try testing.expectEqual(str2.byteCount(), 0);
}

test "Str.set correctly drops error when input parameter is invalid UTF-8" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        try str.set(test_slice);
        defer str.deinit();
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (common.invalid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        defer str.deinit();
        try testing.expectError(Str.Error.InvalidUtf8, str.set(test_slice));
    }
}

test "Str.clone using existing allocator" {
    const a = testing.allocator;

    var str = try Str.init(a, "Test");
    defer str.deinit();

    var str_copy = try str.clone();
    defer str_copy.deinit();

    try testing.expectEqualStrings(str.asSlice(), str_copy.asSlice());
    try testing.expect(str.asSlice().ptr != str_copy.asSlice().ptr);
}

test "Str.charCount should return correct string length in unicode scalars" {
    const a = testing.allocator;

    var ja_str = try Str.init(a, "日本語の字は大抵１バイト以上かかる"); // 17 characters, 51 bytes
    defer ja_str.deinit();
    try testing.expectEqual(ja_str.charCount(), 17);
    try testing.expectEqual(ja_str.byteCount(), 51);

    var ru_str = try Str.init(a, "Русские символы тоже занимают более 1 байта"); // 43 characters, 79 bytes
    defer ru_str.deinit();
    try testing.expectEqual(ru_str.charCount(), 43);
    try testing.expectEqual(ru_str.byteCount(), 79);
}
