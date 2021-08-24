const std = @import("std");
const Token = @import("./tokens.zig").Token;

const State = enum {
    ready,
    eof,
    mid_number,
    mid_string,
};

pub const BUF_SIZE: usize = 4096;

pub const TokenIter = struct {
    source: std.fs.File,
    state: State,
    escapes: usize,
    buf_a: [BUF_SIZE]u8,
    buf_b: [BUF_SIZE]u8,
    buf: []u8,
    current_buf: u1,
    len: usize,
    pos: usize,

    const Self = @This();

    pub fn init(in: std.fs.File) Self {
        var ts = TokenIter{
            .source = in,
            .state = State.ready,
            .escapes = 0,
            .buf_a = [_]u8{0} ** BUF_SIZE,
            .buf_b = [_]u8{0} ** BUF_SIZE,
            .buf = undefined,
            .current_buf = 0,
            .len = 0,
            .pos = 0,
        };
        ts.buf = &ts.buf_a;
        return ts;
    }

    pub fn next(self: *Self) ?Token {
        if (self.pos == self.len) {
            self.read();
        }
        switch (self.state) {
            .ready => {
                return self.nextToken();
            },
            .mid_string => {
                return self.readString();
            },
            .mid_number => {
                return self.readNumber();
            },
            .eof => {
                return null;
            },
        }
    }

    // This could be peekToken, but I'm too lazy to do strings and numbers when
    // I really only care about opening braces. Meh.
    pub fn peekChar(self: *Self) ?u8 {
        if (self.state == State.eof or self.pos == self.len) {
            return null;
        } else {
            return self.buf[self.pos];
        }
    }

    fn nextToken(self: *Self) Token {
        const char = self.buf[self.pos];
        switch (char) {
            ':' => {
                self.pos += 1;
                return Token.Colon;
            },
            ',' => {
                self.pos += 1;
                return Token.Comma;
            },
            '{' => {
                self.pos += 1;
                return Token.LBrace;
            },
            '[' => {
                self.pos += 1;
                return Token.LSquare;
            },
            '}' => {
                self.pos += 1;
                return Token.RBrace;
            },
            ']' => {
                self.pos += 1;
                return Token.RSquare;
            },
            '"' => {
                return self.readString();
            },
            't' => {
                self.skip(4);
                return Token.True;
            },
            'f' => {
                self.skip(5);
                return Token.False;
            },
            'n' => {
                self.skip(4);
                return Token.Null;
            },
            else => {
                if (numericish(char)) {
                    return self.readNumber();
                }
                const start = self.pos;
                while (self.pos < self.len and is_ws(self.buf[self.pos])) {
                    self.pos += 1;
                }
                const end = self.pos;
                return Token{ .WhiteSpace = end - start };
            },
        }
    }

    fn readString(self: *Self) Token {
        const start = self.pos;
        if (self.state == State.ready) {
            self.pos += 1; // opening quote
        }
        while (self.pos < self.len) {
            switch (self.buf[self.pos]) {
                '\\' => {
                    self.escapes += 1;
                    self.pos += 1;
                },
                '"' => {
                    if (self.escapes % 2 == 0) {
                        self.escapes = 0;
                        self.pos += 1; // closing quote
                        const end = self.pos;
                        self.state = State.ready;
                        return Token{ .String = self.buf[start..end] };
                    } else {
                        self.escapes = 0;
                        self.pos += 1;
                    }
                },
                else => {
                    self.escapes = 0;
                    self.pos += 1;
                },
            }
        }
        const end = self.pos;
        self.state = State.mid_string;
        return Token{ .String = self.buf[start..end] };
    }

    fn readNumber(self: *Self) Token {
        const start = self.pos;
        while (self.pos < self.len) : (self.pos += 1) {
            if (!numericish(self.buf[self.pos])) {
                const end = self.pos;
                self.state = State.ready;
                return Token{ .Number = self.buf[start..end] };
            }
        }
        const end = self.pos;
        self.state = State.mid_number;
        return Token{ .Number = self.buf[start..end] };
    }

    fn skip(self: *Self, n: usize) void {
        var remaining = n;
        while (remaining > 0) {
            if (self.pos == self.len) {
                self.read();
            }
            self.pos += 1;
            remaining -= 1;
        }
    }

    fn read(self: *Self) void {
        self.pos = 0;
        if (self.current_buf == 0) {
            self.buf = &self.buf_b;
            self.current_buf = 1;
        } else {
            self.buf = &self.buf_a;
            self.current_buf = 0;
        }
        const bytes_read = self.source.read(self.buf) catch unreachable; // not unreachable, just bail early
        self.len = bytes_read;
        if (bytes_read == 0) {
            self.state = State.eof;
        }
    }
};

fn is_ws(char: u8) bool {
    return char == ' ' or char == '\n' or char == '\t' or char == '\r';
}

// Not verifying that the number is actually valid, just the right charset.
fn numericish(char: u8) bool {
    return (char >= 48 and char <= 57) or char == '.' or char == '-' or char == '+' or char == 'E' or char == 'e';
}
