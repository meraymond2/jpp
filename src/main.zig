const std = @import("std");
const Printer = @import("./printer.zig").Printer;
const TokenIter = @import("./token-iter.zig").TokenIter;

pub fn main() anyerror!void {
    const stdin = std.io.getStdIn();
    var ts = TokenIter.init(stdin);

    var stdout = std.io.getStdOut();
    var buffered_writer = std.io.bufferedWriter(stdout.writer());
    var writer = buffered_writer.writer();

    var printer = Printer.init(&ts, &stdout);
    try printer.print();
}
