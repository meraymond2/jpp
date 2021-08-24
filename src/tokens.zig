const std = @import("std");

const TokenTag = enum {
    Colon,
    Comma,
    False,
    LBrace,
    LSquare,
    Null,
    Number,
    RBrace,
    RSquare,
    String,
    True,
    WhiteSpace,
};

pub const Token = union(TokenTag) {
    Colon,
    Comma,
    False,
    LBrace,
    LSquare,
    Null,
    Number: []u8, // slice
    RBrace,
    RSquare,
    String: []u8, // slice
    True,
    WhiteSpace: usize, // just length

    // The length of the text contained in the token. To determine if it will
    // look nice inline, or is long enough that the lines are split.
    pub fn textLen(self: Token) usize {
        return switch (self) {
            .Colon => 1,
            .Comma => 1,
            .False => 5,
            .LBrace => 1,
            .LSquare => 1,
            .Null => 4,
            .Number => |num| num.len,
            .RBrace => 1,
            .RSquare => 1,
            .String => |str| str.len,
            .True => 4,
            .WhiteSpace => |length| length,
        };
    }

    // The length of the token in the input. I need to keep track of the whitespace
    // length, because I can only buffer as many tokens as I am holding in the
    // input buffers; I don't want tokens pointing to overwritten memory.
    pub fn memLen(self: Token) usize {
        return switch (self) {
            .Colon => 1,
            .Comma => 1,
            .False => 5,
            .LBrace => 1,
            .LSquare => 1,
            .Null => 4,
            .Number => |num| num.len,
            .RBrace => 1,
            .RSquare => 1,
            .String => |str| str.len,
            .True => 4,
            .WhiteSpace => |length| length,
        };
    }
};
