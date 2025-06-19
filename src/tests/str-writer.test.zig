const std = @import("std");
const testing = std.testing;
const Str = @import("../composable-string.zig").Str;
const common = @import("./common.zig");

test "Str.format should correctly format string when Str used as argument for fmt-like functions" {
    const a = testing.allocator;

    var str = try Str.init(a, "Hello");
    defer str.deinit();

    const result = try std.fmt.allocPrint(a, "str = {s}", .{str});
    defer a.free(result);
    try testing.expectEqualStrings("str = Hello", result);

    const result2 = try std.fmt.allocPrint(a, "str = {}", .{str});
    defer a.free(result2);
    try testing.expectEqualStrings("str = Hello", result2);
}

test "Str implements writer" {
    const a = testing.allocator;

    {
        var str = try Str.init(a, "Hello");
        defer str.deinit();

        const num1: i32 = 69;
        const num2: i32 = 420;
        try str.writer().print(" {} and {}", .{ num1, num2 });

        try testing.expectEqualSlices(u8, "Hello 69 and 420", str.asSlice());
    }
    {
        var str = Str.initEmpty(a);
        defer str.deinit();

        const writer = str.writer();
        try writer.writeAll("this");
        try writer.writeAll(" is");
        try writer.writeAll(" a");
        try writer.writeAll(" test");

        try testing.expectEqualSlices(u8, str.asSlice(), "this is a test");
    }
    {
        var str = Str.initEmpty(a);
        defer str.deinit();

        {
            var part_1 = try Str.init(a, "this");
            defer part_1.deinit();

            var part_2 = try Str.init(a, "is");
            defer part_2.deinit();

            var part_3 = try Str.init(a, "a");
            defer part_3.deinit();

            var part_4 = try Str.init(a, "test");
            defer part_4.deinit();

            const writer = str.writer();
            try writer.print("{} {} {} {}", .{ part_1, part_2, part_3, part_4 });
        }

        try testing.expectEqualSlices(u8, str.asSlice(), "this is a test");
    }
}

test "Str.writer correctly handles UTF-8 errors" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = Str.initEmpty(a);
        defer str.deinit();

        try str.writer().writeAll(test_slice);

        try testing.expectEqualStrings(str.asSlice(), test_slice);

        str.clear();
        try str.writer().print("{s}", .{test_slice});
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (common.invalid_utf8_strings) |test_slice| {
        var str = Str.initEmpty(a);
        defer str.deinit();

        const writer = str.writer();

        try testing.expectError(Str.Error.InvalidUtf8, writer.writeAll(test_slice));
        try testing.expectError(Str.Error.InvalidUtf8, writer.print("text{s}text", .{test_slice}));
    }
}

test "Str implements FixedWriter" {
    const a = testing.allocator;

    {
        var str = Str.initEmpty(a);
        try testing.expectEqual(0, str.capacity());

        const REPEAT_TIMES = 1024;
        try str.ensureTotalCapacity(8 * REPEAT_TIMES);
        try testing.expect(str.capacity() >= 8 * REPEAT_TIMES);
        defer str.deinit();

        const string_8_bytes = "12345678";

        try str.fixedWriter().writeAll(string_8_bytes ** REPEAT_TIMES);
        try testing.expectEqualSlices(u8, str.asSlice(), string_8_bytes ** REPEAT_TIMES);
    }
    {
        const REPEAT_TIMES = 1024;
        var str = Str.initEmpty(a);
        try str.ensureTotalCapacity(14 * REPEAT_TIMES);
        defer str.deinit();

        for (0..REPEAT_TIMES) |_| {
            var part_1 = try Str.init(a, "this");
            defer part_1.deinit();

            var part_2 = try Str.init(a, "is");
            defer part_2.deinit();

            var part_3 = try Str.init(a, "a");
            defer part_3.deinit();

            var part_4 = try Str.init(a, "test");
            defer part_4.deinit();

            const fixedWriter = str.fixedWriter();
            try fixedWriter.print("{} {} {} {}", .{ part_1, part_2, part_3, part_4 });
        }

        try testing.expectEqualSlices(u8, str.asSlice(), "this is a test" ** REPEAT_TIMES);
    }
}

test "Str.fixedWriter correctly handles UTF-8 errors" {
    const a = testing.allocator;
    for (common.valid_utf8_strings) |test_slice| {
        var str = Str.initEmpty(a);
        try str.ensureTotalCapacity(test_slice.len);
        defer str.deinit();

        try str.fixedWriter().writeAll(test_slice);

        try testing.expectEqualStrings(str.asSlice(), test_slice);

        str.clearRetainingCapacity();

        try str.fixedWriter().print("{s}", .{test_slice});
        try testing.expectEqualStrings(str.asSlice(), test_slice);
    }
    for (common.invalid_utf8_strings) |test_slice| {
        var str = Str.initEmpty(a);
        try str.ensureTotalCapacity(test_slice.len);
        defer str.deinit();

        const fixedWriter = str.fixedWriter();

        try testing.expectError(Str.Error.InvalidUtf8, fixedWriter.writeAll(test_slice));
    }
}
