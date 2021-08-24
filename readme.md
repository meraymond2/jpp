# jpp

Fast, no-allocation, streaming, compact JSON pretty-printing CLI.

## Building
Clone the repo and run `zig build -Drelease-safe=true`.

The fast build isn’t much faster, to stream a 180 MB file into a new file takes 3.2 seconds in safe mode, and 2.75 in fast mode.


## Why?
I often use `jq` just for pretty-printing, but it prints too sparsely by default.

And it was a fun to do compact printing with the limitation of not holding the entire input in memory.
