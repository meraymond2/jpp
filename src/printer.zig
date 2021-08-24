const std = @import("std");
const TokenIter = @import("./token-iter.zig").TokenIter;
const INPUT_BUF_SIZE = @import("./token-iter.zig").BUF_SIZE;
const Token = @import("./tokens.zig").Token;

const INDENT: []const u8 = "  ";
const TOKEN_BUF_SIZE = 40;
const LINE_LEN = 80; // todo, would be nice if it were terminal size, or configurable, or took indent into account, or took key into account

pub const Printer = struct {
    ts: *TokenIter,
    out: *std.fs.File,
    indent: usize,
    token_buf: [TOKEN_BUF_SIZE]Token,
    token_len: usize,

    const Self = @This();

    const buffer_size = 4096; // default
    const BufferedWriter = std.io.BufferedWriter(buffer_size, std.fs.File.Writer);
    const Writer = std.io.Writer(*BufferedWriter, BufferedWriter.Error, BufferedWriter.write);

    pub fn init(ts: *TokenIter, out: *std.fs.File) Self {
        return Printer{ .ts = ts, .out = out, .indent = 0, .token_buf = [_]Token{undefined} ** TOKEN_BUF_SIZE, .token_len = 0 };
    }

    pub fn print(self: *Self) BufferedWriter.Error!void {
        var buffered_writer = std.io.bufferedWriter(self.out.writer());
        var writer = buffered_writer.writer();
        while (self.ts.next()) |token| {
            try self.printToken(&writer, token);
        }
        try writer.print("\n", .{});
        try buffered_writer.flush();
    }

    fn printToken(self: *Self, writer: *Writer, token: Token) BufferedWriter.Error!void {
        switch (token) {
            .LBrace, .LSquare => {
                self.push(token);
                const can_inline = self.bufferLine(token);
                if (can_inline) {
                    var n: usize = 0;
                    while (n < self.token_len) : (n += 1) {
                        const t = self.token_buf[n];
                        try self.printTokenInline(writer, t);
                    }
                    self.resetBuffer();
                } else {
                    var n: usize = 0;
                    while (n < self.token_len) : (n += 1) {
                        const t = self.token_buf[n];
                        try self.printTokenMultiline(writer, t);
                    }
                    self.resetBuffer();
                }
            },
            .Colon, .Comma, .False, .Null, .Number, .RBrace, .RSquare, .String, .True => try self.printTokenMultiline(writer, token),
            .WhiteSpace => {},
        }
    }

    // Start adding tokens to the buffer as long as we don't go over the line length
    // or the buffer size. When we're done, or know that it won't work inline, we
    // return, and letter the caller flush the buffer.
    fn bufferLine(self: *Self, token: Token) bool {
        var line_text_len: usize = 0; // the printable length
        var line_mem_len: usize = 0; // the length in memory of the tokens
        while (self.ts.next()) |next| {
            line_text_len += next.textLen();
            line_mem_len += next.memLen();
            self.push(next);
            if (line_text_len > LINE_LEN or line_mem_len > INPUT_BUF_SIZE or self.token_len == TOKEN_BUF_SIZE - 1) {
                return false;
            } else if (closes(token, next)) {
                return true;
            } else if (opens(self.ts.peekChar())) {
                // I need to peek here, because I want the new opener in
                // the _next_ buffer, so it triggers its own inline check.
                return false;
            }
        }
        return false; // unlikely to reach
    }

    // print a token, with an element per line
    fn printTokenMultiline(self: *Self, writer: *Writer, token: Token) BufferedWriter.Error!void {
        switch (token) {
            .Colon => try writer.print(": ", .{}),
            .Comma => {
                try writer.print(",\n", .{});
                try self.prindent(writer);
            },
            .False => try writer.print("false", .{}),
            .LBrace => {
                try writer.print("{{\n", .{});
                self.indent += 1;
                try self.prindent(writer);
            },
            .LSquare => {
                try writer.print("[\n", .{});
                self.indent += 1;
                try self.prindent(writer);
            },
            .Null => try writer.print("null", .{}),
            .Number => try writer.print("{s}", .{token.Number}),
            .RBrace => {
                try writer.print("\n", .{});
                self.indent -= 1;
                try self.prindent(writer);
                try writer.print("}}", .{});
            },
            .RSquare => {
                try writer.print("\n", .{});
                self.indent -= 1;
                try self.prindent(writer);
                try writer.print("]", .{});
            },
            .String => try writer.print("{s}", .{token.String}),
            .True => try writer.print("true", .{}),
            .WhiteSpace => {},
        }
    }

    // print a token inline
    fn printTokenInline(self: *Self, writer: *Writer, token: Token) BufferedWriter.Error!void {
        switch (token) {
            .Colon => try writer.print(": ", .{}),
            .Comma => try writer.print(", ", .{}),
            .False => try writer.print("false", .{}),
            .LBrace => try writer.print("{{", .{}),
            .LSquare => try writer.print("[", .{}),
            .Null => try writer.print("null", .{}),
            .Number => try writer.print("{s}", .{token.Number}),
            .RBrace => try writer.print("}}", .{}),
            .RSquare => try writer.print("]", .{}),
            .String => try writer.print("{s}", .{token.String}),
            .True => try writer.print("true", .{}),
            .WhiteSpace => {},
        }
    }

    // print the current indent
    fn prindent(self: *Self, writer: *Writer) BufferedWriter.Error!void {
        var n = self.indent;
        while (n > 0) : (n -= 1) {
            try writer.print("{s}", .{INDENT});
        }
    }

    // push Token onto internal buffer for later processing
    fn push(self: *Self, token: Token) void {
        self.token_buf[self.token_len] = token;
        self.token_len += 1;
    }

    // move buffer position back to start
    fn resetBuffer(self: *Self) void {
        self.token_len = 0;
    }

    fn closes(a: Token, b: Token) bool {
        return switch (a) {
            .LBrace => {
                return switch (b) {
                    .RBrace => true,
                    else => false,
                };
            },
            .LSquare => {
                return switch (b) {
                    .RSquare => true,
                    else => false,
                };
            },
            else => false,
        };
    }

    fn opens(next_char: ?u8) bool {
        if (next_char) |char| {
            return switch (char) {
                '{', '[' => true,
                else => false,
            };
        }
        // If there's not a next-char, we're either at the end of
        // the input, or at the end of the current input buffer, in
        // which case we don't know, so to be safe, return true so
        // that it prints multiline. Not very likely either way.
        return true;
    }
};
