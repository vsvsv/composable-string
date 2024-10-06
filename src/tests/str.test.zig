const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;

test "Str initializes correctly" {
    const a = testing.allocator;
    const hello_str = "Hello";

    var hello = try Str.init(a, hello_str);
    defer hello.deinit();

    try testing.expectEqualStrings(hello.u8, hello_str);
    try testing.expectEqual(hello.u8.len, hello_str.len);
}

test "Str correctly passes allocation error on init" {
    const a = testing.failing_allocator;
    const allocError = std.mem.Allocator.Error.OutOfMemory;
    try testing.expectError(allocError, Str.init(a, "Born 2 fail"));
}

test "Str.initFmt correctly initializes formatted string" {
    const a = testing.allocator;

    var hello = try Str.initFmt(a, "Hello, {s}", .{"composable-string"});
    defer hello.deinit();

    try testing.expectEqualStrings(hello.u8, "Hello, composable-string");
}

test "Str.initEmpty correctly initializes empty string" {
    const a = testing.allocator;

    var empty = Str.initEmpty(a);
    try testing.expectEqualStrings(empty.u8, "");
    empty.deinit();

    var empty2 = Str.initEmpty(a);
    defer empty2.deinit();
    try testing.expectEqualStrings(empty2.u8, "");
    try empty2.concat("not so empty anymore");
    try testing.expectEqualStrings(empty2.u8, "not so empty anymore");
}

test "Str.clear correctly removes string content" {
    const a = testing.allocator;

    var str = try Str.init(a, "content");
    str.clear();
    try testing.expectEqualStrings(str.u8, "");
    str.deinit();

    var str2 = try Str.init(a, "finally");
    defer str2.deinit();
    try str2.concat(", more content");
    str2.clear();
    try testing.expectEqualStrings("", str2.u8);
    try testing.expectEqual(str2.u8.len, 0);
}

test "Str.set should correctly change the content of a string" {
    const a = testing.allocator;

    var str = try Str.init(a, "content 1");
    const new_content_literal = "new content";
    try str.set(new_content_literal);
    try testing.expectEqualStrings(str.u8, new_content_literal);
    try testing.expect(str.u8.ptr != new_content_literal.ptr);
    str.deinit();

    var str2 = try Str.init(a, "content 2");
    defer str2.deinit();
    try str2.set("");
    try testing.expectEqualStrings("", str2.u8);
    try testing.expectEqual(str2.u8.len, 0);
}

test "Str.clone using existing allocator" {
    const a = testing.allocator;

    var str = try Str.init(a, "Test");
    defer str.deinit();

    var str_copy = try str.clone();
    defer str_copy.deinit();

    try testing.expectEqualStrings(str.u8, str_copy.u8);
    try testing.expect(str.u8.ptr != str_copy.u8.ptr);
}

test "Str.concat() correctly concatinates strings" {
    const a = testing.allocator;
    const hello_str = "Hello";
    const world_str = ", World!";
    const hello_world_str = "Hello, World!";

    var hello_world = try Str.init(a, hello_str);
    try hello_world.concat(world_str);

    defer hello_world.deinit();

    try testing.expectEqualStrings(hello_world.u8, hello_world_str);

    // --------------------------------------------------------------------- //

    var another_hello = try Str.init(a, hello_str);
    var another_world = try Str.init(a, world_str);
    try another_hello.concat(another_world);
    defer another_hello.deinit();
    defer another_world.deinit();

    try testing.expectEqualStrings(another_hello.u8, hello_world_str);
}

test "Str.trimStart should remove all spaces, tabs and line separators from the start of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     spaces before");
    defer str.deinit();
    str.trimStart();
    try testing.expectEqualStrings("spaces before", str.u8);

    // Should do nothing:
    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trimStart();
    try testing.expectEqualStrings("spaces at the end    ", str_end.u8);

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimStart();
    try testing.expectEqual(wo_str.u8.len, 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2");
    defer str2.deinit();
    str2.trimStart();
    try testing.expectEqualStrings("example 2", str2.u8);

    // Uncommon UTF-8 space symbols:
    // no-break space; ogham space mark; three-per-em space; four-per-em space; figure space; line separator
    var str3 = try Str.init(a, "\u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028} unusual spaces");
    defer str3.deinit();
    str3.trimStart();
    try testing.expectEqualStrings("unusual spaces", str3.u8);
}

test "Str.trimEnd should remove all spaces, tabs and line separators from the of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "simple spaces    ");
    defer str.deinit();
    str.trimEnd();
    try testing.expectEqualStrings("simple spaces", str.u8);

    // Should do nothing:
    var str_start = try Str.init(a, "    spaces before");
    defer str_start.deinit();
    str_start.trimEnd();
    try testing.expectEqualStrings("    spaces before", str_start.u8);

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trimEnd();
    try testing.expectEqual(wo_str.u8.len, 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, "example 2 \t \n \r ");
    defer str2.deinit();
    str2.trimEnd();
    try testing.expectEqualStrings("example 2", str2.u8);

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "unusual spaces \u{a0} \u{1680} \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trimEnd();
    try testing.expectEqualStrings("unusual spaces", str3.u8);
}

test "Str.trim should remove all spaces, tabs and line separators from both ends of the string" {
    const a = testing.allocator;

    // Just spaces:
    var str = try Str.init(a, "     simple spaces    ");
    defer str.deinit();
    str.trim();
    try testing.expectEqualStrings("simple spaces", str.u8);

    var str_start = try Str.init(a, "     spaces before");
    defer str_start.deinit();
    str_start.trim();
    try testing.expectEqualStrings("spaces before", str_start.u8);

    var str_end = try Str.init(a, "spaces at the end    ");
    defer str_end.deinit();
    str_end.trim();
    try testing.expectEqualStrings("spaces at the end", str_end.u8);

    // Whitespace-only string:
    var wo_str = try Str.init(a, "         ");
    defer wo_str.deinit();
    wo_str.trim();
    try testing.expectEqual(wo_str.u8.len, 0);

    // Common space and separator symbols:
    var str2 = try Str.init(a, " \n \t \r example 2 \t \n \r ");
    defer str2.deinit();
    str2.trim();
    try testing.expectEqualStrings("example 2", str2.u8);

    // Uncommon UTF-8 space symbols:
    // [no-break space; ogham space mark] [three-per-em space; four-per-em space; figure space; line separator]
    var str3 = try Str.init(a, "\u{a0} \u{1680} unusual spaces \u{2004} \u{2005} \u{2007} \u{2028}");
    defer str3.deinit();
    str3.trim();
    try testing.expectEqualStrings("unusual spaces", str3.u8);
}

test "Str.charCount should return correct string length in unicode scalars" {
    const a = testing.allocator;

    var ja_str = try Str.init(a, "日本語の字は大抵１バイト以上かかる"); // 17 characters, 51 bytes
    defer ja_str.deinit();
    try testing.expectEqual(ja_str.charCount(), 17);
    try testing.expectEqual(ja_str.u8.len, 51);

    var ru_str = try Str.init(a, "Русские символы тоже занимают более 1 байта"); // 43 characters, 79 bytes
    defer ru_str.deinit();
    try testing.expectEqual(ru_str.charCount(), 43);
    try testing.expectEqual(ru_str.u8.len, 79);
}
