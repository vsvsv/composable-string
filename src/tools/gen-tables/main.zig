//! This helper program generates unicode LUTs to use in `Str` methods (i. e. `toLowerCase()`)
//! directly from official Unicode Character Database (http://www.unicode.org/ucd/).

const std = @import("std");
const file_utils = @import("file_utils.zig");
const Codepoint = @import("composable-string").Codepoint;
const isAscii = Codepoint.Ascii.isAscii;

const GENERATED_FILE_PATH = "src/tools/gen-tables/unicode-tables.generated.zig";
const DOWNLOAD_DIR_PATH = "src/tools/gen-tables/downloaded/";
const UCD_URL = "https://www.unicode.org/Public/UCD/latest/ucd/";

/// All needed files to generate tables
const UCD_FILES = [_][]const u8{
    "UnicodeData.txt",
    "SpecialCasing.txt",
};

/// This bit in mapping indicates that the character has complex multi-codepoint mapping,
/// and resulting value should be obtained from a multi-character LUT.
const MULTI_MAPPING_INDEX_MASK: u32 = 1 << 22;

const TRIM_CHARS = " \n\t";
pub inline fn trim(str: []const u8) @TypeOf(str) {
    return std.mem.trim(u8, str, TRIM_CHARS);
}

/// Parsed data from UnicodeData.txt
/// For more info, see https://www.unicode.org/L2/L1999/UnicodeData.html
const ParsedUnicodeDataTxt = struct {
    const Self = @This();

    /// Parsed unicode character data, corresponds to one line in UnicodeData.txt
    pub const Entry = struct {
        char_code: u21 = 0,
        // *some fields are omitted*
        upper_case_mapping: ?u32 = null,
        lower_case_mapping: ?u32 = null,
    };

    chars: std.ArrayList(Entry),

    pub fn createFromFile(
        allocator: std.mem.Allocator,
        unicode_data_txt_file: std.fs.File,
    ) !Self {
        const log = std.log.scoped(.createFromFile_unicodeData);

        var self = Self{ .chars = .init(allocator) };
        errdefer self.chars.deinit();

        var bufferedReader = std.io.bufferedReader(unicode_data_txt_file.reader());
        var reader = bufferedReader.reader();
        var buf: [1024 * 1024]u8 = undefined;
        var source_line_number: usize = 0;
        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var line_trim = trim(line);
            if (line_trim.len > 0) {
                const comment_start_idx = std.mem.indexOfScalar(u8, line_trim, '#');
                if (comment_start_idx != 0) {
                    if (comment_start_idx) |comment_char_idx| {
                        line_trim = trim(line_trim[0..comment_char_idx]);
                    }
                    if (line_trim.len > 0) {
                        var tokens = std.mem.splitScalar(u8, line_trim, ';');
                        var char_entry = Self.Entry{};
                        var tok_idx: usize = 0;
                        while (tokens.next()) |token| {
                            if (tok_idx == 0) {
                                char_entry.char_code = try std.fmt.parseInt(u21, token, 16);
                            }
                            if (tok_idx == 12 and token.len > 0) {
                                char_entry.upper_case_mapping = try std.fmt.parseInt(u32, token, 16);
                            }
                            if (tok_idx == 13 and token.len > 0) {
                                char_entry.lower_case_mapping = try std.fmt.parseInt(u32, token, 16);
                            }
                            tok_idx += 1;
                        }
                        const has_data =
                            char_entry.lower_case_mapping != null or char_entry.upper_case_mapping != null;

                        if (tok_idx != 15) {
                            log.err(
                                "Incorrect string detected at line {}: \"{s}\". " ++
                                    "Expected 15 comma-separated values, got {}",
                                .{ source_line_number, line_trim, tok_idx },
                            );
                        } else if (has_data) {
                            try self.chars.append(char_entry);
                        }
                    }
                }
            }
            source_line_number += 1;
        }
        return self;
    }

    pub fn deinit(self: Self) void {
        self.chars.deinit();
    }
};

/// Parsed data from SpecialCasing.txt
/// For more info about the format, see the header of the SpecialCasing.txt file
const ParsedSpecialCasingTxt = struct {
    const Self = @This();

    /// Parsed character mapping data, corresponds to one line in SpecialCasing.txt
    pub const Entry = struct {
        char_code: u21 = 0,
        lower_case_mapping: ?[3]u21 = null,
        // * title_case_mapping omitted *
        upper_case_mapping: ?[3]u21 = null,
        // * condition_list omitted *
    };

    mappings: std.ArrayList(Entry),

    pub fn createFromFile(
        allocator: std.mem.Allocator,
        special_casing_txt_file: std.fs.File,
    ) !Self {
        const log = std.log.scoped(.createFromFile_specialCasing);

        var self = Self{ .mappings = .init(allocator) };
        errdefer self.mappings.deinit();

        var bufferedReader = std.io.bufferedReader(special_casing_txt_file.reader());
        var reader = bufferedReader.reader();
        var buf: [1024 * 1024]u8 = undefined;
        var source_line_number: usize = 0;
        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var line_trim = trim(line);
            if (line_trim.len > 0) {
                const comment_start_idx = std.mem.indexOfScalar(u8, line_trim, '#');
                if (comment_start_idx != 0) {
                    if (comment_start_idx) |comment_char_idx| {
                        line_trim = trim(line_trim[0..comment_char_idx]);
                    }
                    if (line_trim.len > 0) {
                        var tokens = std.mem.splitScalar(u8, line_trim, ';');
                        var entry = Self.Entry{};
                        var tok_idx: usize = 0;
                        while (tokens.next()) |token_raw| {
                            const token = std.mem.trim(u8, token_raw, " \n\t");
                            if (tok_idx == 0) {
                                entry.char_code = try std.fmt.parseInt(u21, token, 16);
                            }
                            if (tok_idx == 1 and token.len > 0) {
                                var codepoints = std.mem.tokenizeScalar(u8, token, ' ');
                                var cp_idx: usize = 0;
                                while (codepoints.next()) |cp| {
                                    const cp_trim = trim(cp);
                                    if (cp_trim.len > 0) {
                                        if (entry.lower_case_mapping == null) {
                                            entry.lower_case_mapping = .{ 0, 0, 0 };
                                        }
                                        entry.lower_case_mapping.?[cp_idx] = try std.fmt.parseInt(u21, cp_trim, 16);
                                    }
                                    cp_idx += 1;
                                }
                            }
                            if (tok_idx == 3 and token.len > 0) {
                                var codepoints = std.mem.tokenizeScalar(u8, token, ' ');
                                var cp_idx: usize = 0;
                                while (codepoints.next()) |cp| {
                                    const cp_trim = trim(cp);
                                    if (cp_trim.len > 0) {
                                        if (entry.upper_case_mapping == null) {
                                            entry.upper_case_mapping = .{ 0, 0, 0 };
                                        }
                                        entry.upper_case_mapping.?[cp_idx] = try std.fmt.parseInt(u21, cp_trim, 16);
                                    }
                                    cp_idx += 1;
                                }
                            }
                            if (tok_idx == 4 and token.len > 0) {
                                // Skip conditional case mappings
                                entry = .{};
                            }
                            tok_idx += 1;
                        }
                        const has_data =
                            entry.lower_case_mapping != null or entry.upper_case_mapping != null;

                        if (tok_idx < 4) {
                            log.err(
                                "Incorrect string detected at line {}: \"{s}\". " ++
                                    "Expected 4 or 5 comma-separated values, got {}",
                                .{ source_line_number, line_trim, tok_idx },
                            );
                        } else if (has_data) {
                            try self.mappings.append(entry);
                        }
                    }
                }
            }
            source_line_number += 1;
        }
        return self;
    }

    pub fn deinit(self: Self) void {
        self.mappings.deinit();
    }
};

fn generateLutArraySource(allocator: std.mem.Allocator, lut: std.AutoArrayHashMap(u21, u32)) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    var writer = buf.writer();
    var iter = lut.iterator();
    var idx: usize = 0;
    while (iter.next()) |entry| {
        if (idx % 4 == 0) {
            if (idx != 0) {
                try writer.print("\n", .{});
            }
            try writer.print("            ", .{});
        } else if (idx > 0) {
            try writer.print(" ", .{});
        }
        const char_code: u21 = entry.key_ptr.*;
        const mapping_code: u32 = entry.value_ptr.*;
        try writer.print("m(0x{X}, 0x{X}),", .{ char_code, mapping_code });
        idx += 1;
    }
    return try buf.toOwnedSlice();
}

fn generateMultiMappingSource(allocator: std.mem.Allocator, mapping: std.ArrayList([3]u21)) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    var writer = buf.writer();
    for (mapping.items, 0..) |codes, idx| {
        if (idx % 4 == 0) {
            if (idx != 0) {
                try writer.print("\n", .{});
            }
            try writer.print("        ", .{});
        } else if (idx > 0) {
            try writer.print(" ", .{});
        }
        try writer.print(".{{ 0x{X}, 0x{X}, 0x{X} }},", .{ codes[0], codes[1], codes[2] });
    }
    return try buf.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    try file_utils.downloadAll(allocator, &UCD_FILES, UCD_URL, DOWNLOAD_DIR_PATH);

    const parsed_unicode_data_txt = blk: {
        const unicode_data_txt = try file_utils.openFile(DOWNLOAD_DIR_PATH ++ UCD_FILES[0]);
        defer unicode_data_txt.close();
        break :blk try ParsedUnicodeDataTxt.createFromFile(allocator, unicode_data_txt);
    };
    defer parsed_unicode_data_txt.deinit();

    const parsed_special_casing_txt = blk: {
        const special_casing_txt = try file_utils.openFile(DOWNLOAD_DIR_PATH ++ UCD_FILES[1]);
        defer special_casing_txt.close();
        break :blk try ParsedSpecialCasingTxt.createFromFile(allocator, special_casing_txt);
    };
    defer parsed_special_casing_txt.deinit();

    // simple 1-to-1 mapping
    // `u32` is used for value type to also represent multi-character mappings via `MULTI_MAPPING_INDEX_MASK`
    var to_upper_lut = std.AutoArrayHashMap(u21, u32).init(allocator);
    defer to_upper_lut.deinit();
    var to_upper_multi = std.ArrayList([3]u21).init(allocator); // multi-character mappings
    defer to_upper_multi.deinit();

    // simple 1-to-1 mapping
    // `u32` is used for value type to also represent multi-character mappings via `MULTI_MAPPING_INDEX_MASK`
    var to_lower_lut = std.AutoArrayHashMap(u21, u32).init(allocator);
    defer to_lower_lut.deinit();
    var to_lower_multi = std.ArrayList([3]u21).init(allocator); // multi-character mappings
    defer to_lower_multi.deinit();

    for (parsed_unicode_data_txt.chars.items) |cp| {
        if (!isAscii(cp.char_code)) {
            if (cp.upper_case_mapping != null and cp.upper_case_mapping != cp.char_code) {
                try to_upper_lut.put(cp.char_code, cp.upper_case_mapping.?);
            }
            if (cp.lower_case_mapping != null and cp.lower_case_mapping != cp.char_code) {
                try to_lower_lut.put(cp.char_code, cp.lower_case_mapping.?);
            }
        }
    }

    for (parsed_special_casing_txt.mappings.items) |cp| {
        if (!isAscii(cp.char_code)) {
            if (cp.lower_case_mapping) |lcm| {
                if (lcm[1] == 0 and lcm[2] == 0) {
                    if (cp.char_code != lcm[0]) {
                        try to_lower_lut.put(cp.char_code, lcm[0]);
                    }
                } else {
                    try to_lower_multi.append(lcm);
                    // store the index of complex mapping in 1-to-1 map by using special bit
                    try to_lower_lut.put(
                        cp.char_code,
                        MULTI_MAPPING_INDEX_MASK | @as(u32, @intCast(to_upper_multi.items.len - 1)),
                    );
                }
            }
            if (cp.upper_case_mapping) |ucm| {
                if (ucm[1] == 0 and ucm[2] == 0) {
                    if (cp.char_code != ucm[0]) {
                        try to_upper_lut.put(cp.char_code, ucm[0]);
                    }
                } else {
                    try to_upper_multi.append(ucm);
                    // store the index of complex mapping in 1-to-1 map by using special bit
                    try to_upper_lut.put(
                        cp.char_code,
                        MULTI_MAPPING_INDEX_MASK | @as(u32, @intCast(to_upper_multi.items.len - 1)),
                    );
                }
            }
        }
    }

    {
        const l_lut_size = @sizeOf(struct { k: u21, v: u32 }) * to_lower_lut.values().len;
        std.log.info("`toLowerCase` LUT size           : {} bytes", .{l_lut_size});
        const l_multi_size = @sizeOf([3]u21) * to_lower_multi.items.len;
        std.log.info("`toLowerCase` multi-mapping size : {} bytes", .{l_multi_size});
        const u_lut_size = @sizeOf(struct { k: u21, v: u32 }) * to_upper_lut.values().len;
        std.log.info("`toUpperCase` LUT size           : {} bytes", .{u_lut_size});
        const u_multi_size = @sizeOf([3]u21) * to_upper_multi.items.len;
        std.log.info("`toUpperCase` multi-mapping size : {} bytes", .{u_multi_size});
        const total_size = l_lut_size + l_multi_size + u_lut_size + u_multi_size;
        const total_size_kb = @as(f64, @floatFromInt(total_size)) / 1024;
        std.log.info(">>> Total tables size <<<        : {} bytes ({d:.2} kb)", .{ total_size, total_size_kb });
    }

    const lut_file_src_template = blk: {
        const template =
            \\// Autogenerated by `zig run gen-tables`. Do not edit!
            \\/// Lookup tables for Unicode codepoint conversions.
            \\const GeneratedTables = struct {
            \\    const Mapping = struct { k: u21, v: u32 };
            \\    fn m(k: u21, v: u32) Mapping { return .{ .k = k, .v = v}; }
            \\
            \\    pub const ToLowerCaseLut = blk: {
            \\        @setEvalBranchQuota(10000);
            \\        break :blk [_]Mapping{
            \\%lowercase_lut%
            \\        };
            \\    };
            \\
            \\    pub const ToLowerCaseMulti = [_][3]u21{
            \\%lowercase_multi%
            \\    };
            \\
            \\    pub const ToUpperCaseLut = blk: {
            \\        @setEvalBranchQuota(10000);
            \\        break :blk [_]Mapping{
            \\%uppercase_lut%
            \\        };
            \\    };
            \\
            \\    pub const ToUpperCaseMulti = [_][3]u21{
            \\%uppercase_multi%
            \\    };
            \\};
        ;
        const str = try allocator.alloc(u8, template.len);
        @memcpy(str, template);
        break :blk str;
    };
    defer allocator.free(lut_file_src_template);

    var source = lut_file_src_template;
    const to_lower_lut_src = try generateLutArraySource(allocator, to_lower_lut);
    source = try std.mem.replaceOwned(u8, allocator, source, "%lowercase_lut%", to_lower_lut_src);
    allocator.free(to_lower_lut_src);

    const to_lower_multi_src = try generateMultiMappingSource(allocator, to_lower_multi);
    source = try std.mem.replaceOwned(u8, allocator, source, "%lowercase_multi%", to_lower_multi_src);
    allocator.free(to_lower_multi_src);

    const to_upper_lut_src = try generateLutArraySource(allocator, to_upper_lut);
    source = try std.mem.replaceOwned(u8, allocator, source, "%uppercase_lut%", to_upper_lut_src);
    allocator.free(to_upper_lut_src);

    const to_upper_multi_src = try generateMultiMappingSource(allocator, to_upper_multi);
    source = try std.mem.replaceOwned(u8, allocator, source, "%uppercase_multi%", to_upper_multi_src);
    allocator.free(to_upper_multi_src);

    try file_utils.saveAsFile(GENERATED_FILE_PATH, source);

    var zig_fmt_command = std.process.Child.init(
        &[_][]const u8{ "zig", "fmt", GENERATED_FILE_PATH },
        allocator,
    );
    zig_fmt_command.stdout_behavior = .Ignore;
    zig_fmt_command.stderr_behavior = .Ignore;
    try zig_fmt_command.spawn();
    _ = try zig_fmt_command.wait();

    std.log.info("[SUCCESS] Written file {s}", .{GENERATED_FILE_PATH});
}
