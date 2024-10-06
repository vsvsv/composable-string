# composable-string
A work-in-progress string library for the Zig programming language

[![LICENSE](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/cooper-org/cooper/tree/master/LICENSE)

> [!WARNING]
> This library is a work-in-progress! Future API changes might break backward compatibility. Please use it at your own risk.

## Goals (a. k. a. Why another one?)

This library was created as an attempt to write the missing UTF-8 string processing library for the Zig programming language.
The main priority is to design the simplest and hassle-free API possible, which closely resembles standard library APIs.
Because of manual memory management in Zig, many existing libraries tend to overcomplicate their interfaces
by making them overly explicit, which makes usage of such libraries very unfun.
For such an essential language feature as string processing, library users should be able to concentrate on the actual logic
of the application, rather than constantly performing a correct ritual for low-level APIs, e. g. preparing and passing
a correct allocator *every time* for trivial actions such as string concatination or trimming.

Main design goals:
* Full UTF-8 support by default
* Do not reinvent the wheel; use functions from ```std``` for an already implemented logic, otherwise, adapt already proven effecient UTF-8 algorithms
* API should as simple and minimalist as possible

## Usage

Library is implemented in a single file `src/composable-string.zig`.

```Str``` struct provides *mutable* string implementation with common methods:

```zig
const std = @import("std");
const Str = @import("composable-string.zig").Str;

pub fn main() !void {
    // Use your favorite allocator
    const a = std.heap.c_allocator;

    var str = try Str.init(a, "Hello");
    defer str.deinit();
    try str.concat(", composable-string!");

    var another = try Str.initFmt(a, " (this is {s} {s})", .{"concatinated", "Str"});
    defer another.deinit();
    try str.concat(another);
    std.debug.print("'str' is: \"{s}\"\n", .{str.u8});

    var str_with_spaces = try Str.initFmt(a, "        A string with {s} \t\n\t\n  ", .{"whitespaces, newlines and tabs"});
    defer str_with_spaces.deinit();
    str_with_spaces.trim();
    std.debug.print("'str_with_spaces' after trim(): \"{s}\"\n", .{str_with_spaces.u8});

    var non_ascii = try Str.init(a, "Один, 二, さん"); // character count: 11
    defer non_ascii.deinit();
    std.debug.print(
        "Non-ascii string: \"{s}\", length in bytes: {}, length in characters: {}\n",
        .{ non_ascii.u8, non_ascii.u8.len, non_ascii.charCount() },
    );
}
```

## Checklist of implemented functions

- [x] ```Str.init```
- [x] ```Str.initFmt```
- [x] ```Str.clone```
- [x] ```Str.concat```
- [x] ```Str.trim```
- [ ] ```Str.trimStart```
- [ ] ```Str.trimEnd```
- [x] ```Str.charCount```
- [x] ```Str.isValidUTF8```
- [x] ```Str.iterator```
- [ ] ```Str.toUpperCase```
- [ ] ```Str.toLowerCase```
- [ ] ```Str.capitalize```

## Supported Zig versions

The ```master``` branch tries to support the most recent [Zig](https://github.com/ziglang/zig) version from ```master``` branch.

## Alternatives

* [JakubSzark/zig-string](https://github.com/JakubSzark/zig-string)
* [dude_the_builder/zigstr](https://codeberg.org/dude_the_builder/zigstr)
