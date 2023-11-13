// Quick test decoding the zbrush document structure with https://docs.werwolv.net/imhex/
// ZBrush files seem to be a serialisation format, requiring knowledge of the data structures to properly decode.
#include <std/mem.pat>

enum ChunkTag : u32 {
    start = 0x18003,
    end = 0x8803
};

char copyright[0x2E] @ 0x00;
char filetype[0x04] @ 0x4C;
char version[0x08] @ 0x54;

struct ChunkStart {
    ChunkTag tag;
    u16 version_or_type;
    u32 length;
};

struct ChunkEnd {
    ChunkTag tag;
};

using SubChunk;

struct Chunk {
    u32 base_ofs = $;
    ChunkStart start;
    u32 end_ofs = base_ofs + start.length - 4;
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && $ < end_ofs)];

    SubChunk subChunks[while($ < end_ofs)];
            
    $ = end_ofs;
    ChunkEnd end;
};

struct SubChunk {
    Chunk chunk;
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && std::mem::read_unsigned($,4) != ChunkTag::end)];
};

Chunk chunks[while($ < sizeof($))] @ 0x5C;