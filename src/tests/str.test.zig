const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;

const valid_utf8_strings = [_][]const u8{
    "All your base are belong to us",
    "\xc3\xb1",
    "\xe2\x82\xa1",
    "\xf0\x90\x8c\xbc",
};

const invalid_utf8_strings = [_][]const u8{
    "\xc3\x28",
    "\xa0\xa1",
    "\xe2\x28\xa1",
    "\xe2\x82\x28",
    "\xf0\x28\x8c\xbc",
    "\xf0\x90\x28\xbc",
    "\xf0\x28\x8c\x28",
    "\xf8\xa1\xa1\xa1\xa1",
    "\xfc\xa1\xa1\xa1\xa1\xa1",
};

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
    for (valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, test_slice);
        defer str.deinit();
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (invalid_utf8_strings) |test_slice| {
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
    for (valid_utf8_strings) |test_slice| {
        var str = try Str.initFmt(a, "some text {s} some text", .{test_slice});
        defer str.deinit();
        try testing.expectFmt(str.asSlice(), "some text {s} some text", .{test_slice});
    }
    for (invalid_utf8_strings) |test_slice| {
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
    for (valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        try str.set(test_slice);
        defer str.deinit();
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (invalid_utf8_strings) |test_slice| {
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
    for (valid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        try str.concat(test_slice);
        defer str.deinit();
        try testing.expectFmt(str.asSlice(), "content{s}", .{test_slice});
    }
    for (invalid_utf8_strings) |test_slice| {
        var str = try Str.init(a, "content");
        defer str.deinit();
        try testing.expectError(Str.Error.InvalidUtf8, str.concat(test_slice));
    }
}

test "Str.trimStart should remove all spaces, tabs and line separators from the start of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     spaces before");
    defer str.deinit();
    str.trimStart();
    try testing.expectEqualStrings("spaces before", str.asSlice());

    // Should do nothing:
    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trimStart();
    try testing.expectEqualStrings("spaces at the end    ", str_end.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimStart();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2");
    defer str2.deinit();
    str2.trimStart();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // no-break space; ogham space mark; three-per-em space; four-per-em space; figure space; line separator
    var str3 = try Str.init(a, "\u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028} unusual spaces");
    defer str3.deinit();
    str3.trimStart();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
}

test "Str.trimEnd should remove all spaces, tabs and line separators from the of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "simple spaces    ");
    defer str.deinit();
    str.trimEnd();
    try testing.expectEqualStrings("simple spaces", str.asSlice());

    // Should do nothing:
    var str_start = try Str.init(a, "    spaces before");
    defer str_start.deinit();
    str_start.trimEnd();
    try testing.expectEqualStrings("    spaces before", str_start.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimEnd();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, "example 2 \t \n \r ");
    defer str2.deinit();
    str2.trimEnd();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "unusual spaces \u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trimEnd();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
}

test "Str.trim should remove all spaces, tabs and line separators from both ends of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     simple spaces    ");
    defer str.deinit();
    str.trim();
    try testing.expectEqualStrings("simple spaces", str.asSlice());

    var str_start = try Str.init(a, "     spaces before");
    defer str_start.deinit();
    str_start.trim();
    try testing.expectEqualStrings("spaces before", str_start.asSlice());

    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trim();
    try testing.expectEqualStrings("spaces at the end", str_end.asSlice());

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trim();
    try testing.expectEqual(wo_str.byteCount(), 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2 \t \n \r ");
    defer str2.deinit();
    str2.trim();
    try testing.expectEqualStrings("example 2", str2.asSlice());

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "\u{a0} \u{1680} unusual spaces \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trim();
    try testing.expectEqualStrings("unusual spaces", str3.asSlice());
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
