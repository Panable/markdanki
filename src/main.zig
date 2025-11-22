const std = @import("std");

const Card = struct {
    front: std.ArrayList(u8),
    back: std.ArrayList(u8),
    id: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Card {
        return .{
            .allocator = allocator,
            .front = .empty,
            .back = .empty,
        };
    }

    pub fn deinit(this: *Card) void {
        this.front.deinit(this.allocator);
        this.back.deinit(this.allocator);
    }

    pub fn appendFront(this: *Card, str: []const u8) !void {
        try this.front.appendSlice(this.allocator, str);
    }

    pub fn appendBack(this: *Card, str: []const u8) !void {
        try this.back.appendSlice(this.allocator, str);
    }

    pub fn frontIsEmpty(this: *Card) bool {
        return this.front.items.len == 0;
    }

    pub fn backIsEmpty(this: *Card) bool {
        return this.front.items.len == 0;
    }
};

const Deck = struct {
    cards: std.ArrayList(Card),
    name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Deck {
        const dst = try allocator.alloc(u8, name.len);
        @memcpy(dst, name);

        return .{
            .cards = .empty,
            .name = dst,
            .allocator = allocator,
        };
    }

    pub fn deinit(this: *Deck) void {
        for (this.cards.items) |*card| {
            card.deinit();
        }

        this.cards.deinit(this.allocator);
        this.allocator.free(this.name);
    }

    pub fn addCard(this: *Deck, card: Card) !void {
        try this.cards.append(this.allocator, card);
    }
};

const Cards = std.ArrayList(Card);
const State = enum { none, question, answer };
const ParseErrors = error{
    NonDigitInID,
    NoQuestionMarker,
    NoAnswerToQuestion,
    QuestionIsEmpty,
    AnswerIsEmpty,
};

pub fn main() !void {
    // Initiate allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const filename = "test.md";

    const cwd = std.fs.cwd();
    const fileContents: []u8 = try cwd.readFileAlloc(filename, alloc, std.Io.Limit.limited(4096));
    defer alloc.free(fileContents);

    var it = std.mem.splitSequence(u8, fileContents, "\n");

    var state: State = .none;

    var deck: Deck = try .init(alloc, filename);
    defer deck.deinit();

    var current: Card = .init(alloc);

    while (it.next()) |line| {
        switch (state) {
            .none => {
                if (std.mem.cutPrefix(u8, line, "<!-- ")) |noPrefix| {
                    if (std.mem.cutSuffix(u8, noPrefix, " -->")) |id| {
                        // id has been found. let's check that it's only numbers
                        for (id) |c| if (!std.ascii.isDigit(c)) return ParseErrors.NonDigitInID;
                        current.id = id;
                        continue;
                    }
                }

                if (std.mem.eql(u8, line, "### Q")) {
                    state = .question;
                    continue;
                }
            },
            .question => {
                // check if the question is over
                if (std.mem.eql(u8, line, "### A")) {
                    if (!current.frontIsEmpty()) {
                        if (std.mem.trim(u8, current.front.items, " \n\t").len == 0) return ParseErrors.QuestionIsEmpty;
                    } else return ParseErrors.QuestionIsEmpty; // front is empty
                    state = .answer;
                    continue;
                }

                // collect the line into front of card

                if (it.peek()) |next| {
                    if (!std.mem.eql(u8, next, "### A")) try current.appendFront("\n");
                }

                try current.appendFront(line);
            },
            .answer => {
                // check if the answer is over
                if (std.mem.eql(u8, line, "### Q")) {
                    if (!current.backIsEmpty()) {
                        if (std.mem.trim(u8, current.back.items, " \n\t").len == 0) return ParseErrors.AnswerIsEmpty;
                    } else return ParseErrors.AnswerIsEmpty; // back is empty
                    state = .question;
                    try deck.addCard(current);
                    current = .init(alloc);
                    continue;
                }

                // collect the line into front of card

                if (it.peek()) |next| {
                    if (std.mem.endsWith(u8, next, " -->")) {
                        state = .none;
                        try deck.addCard(current);
                        current = .init(alloc);
                        continue;
                    }
                    if (!std.mem.eql(u8, next, "### Q")) try current.appendBack("\n");
                } else { // EOF?
                    try current.appendBack(line);
                    try deck.addCard(current);
                    break;
                }
                try current.appendBack(line);
            },
        }
    }

    if (state == .question) return ParseErrors.NoAnswerToQuestion;
    if (state == .none) return ParseErrors.NoQuestionMarker;

    for (deck.cards.items) |card| {
        std.debug.print("---------------------------\n", .{});
        if (card.id) |id|
            std.debug.print("ID?: {s}\n", .{id});
        std.debug.print("Q: {s}\n", .{card.front.items});
        std.debug.print("A: {s}\n", .{card.back.items});
    }

    // std.debug.print("The front of the card is {s}\n", .{current.front.items});
    // std.debug.print("---------------------------\n", .{});
    // std.debug.print("The back of the card is {s}\n", .{current.back.items});

    // Print file contents
    // std.debug.print("{s}", .{fileContents});
}
