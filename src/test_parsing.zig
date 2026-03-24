const std = @import("std");
const parser = @import("parser.zig");

pub fn test_parse() !void {
    // Initiate allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const filename = "test.md";
    const testDeck = parser.MDToDeck(&arena, filename) catch unreachable;

    for (testDeck.cards.items) |card| {
        std.debug.print("---------------------------\n", .{});
        if (card.id) |id|
            std.debug.print("ID: {s}\n", .{id});
        std.debug.print("Q: {s}\n", .{card.front.items});
        std.debug.print("A: {s}\n", .{card.back.items});
    }
}
