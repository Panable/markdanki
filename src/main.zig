const parser = @import("test_parsing.zig");

pub fn main() !void {
   try parser.test_parse();
}
