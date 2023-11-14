#pragma description Quick test decoding the zbrush document structure with https://docs.werwolv.net/imhex/
#pragma authon jens.restemeier@gmail.com
#pragma endian little

// ZBrush files seem to be a serialisation format, requiring knowledge of the data structures to properly decode.
#include <std/mem.pat>
#include <std/sys.pat>
#include <std/io.pat>

enum ChunkTag : u32 {
    start = 0x18003,
    end = 0x8803
};

struct ChunkStart {
    u32 base_ofs = $;
    ChunkTag tag [[color("0000FF")]];
    u16 version_or_type;
    u32 length;
    u32 end_ofs = base_ofs + length - 4;
    
    std::assert_warn(tag == ChunkTag::start, "Chunk start mismatch");
};

struct ChunkEnd {
    ChunkTag tag [[color("0080FF")]];
    std::assert_warn(tag == ChunkTag::end, "Chunk end mismatch");
};

using SubChunk;

struct Chunk {
    ChunkStart start;
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && $ < start.end_ofs)];

    SubChunk subChunks[while($ < start.end_ofs)];
            
    $ = start.end_ofs;
    ChunkEnd end;
};

struct SubChunk {
    Chunk chunk;
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && std::mem::read_unsigned($,4) != ChunkTag::end)];
};

struct String {
    ChunkStart start;

    match (start.version_or_type) {
    (0x0C): {
        u16 unknown;
        char string[];

        std::assert_warn(unknown == 0, "unknown is not 0");
    }
    (_): 
        std::warning("Unknown string type");
    }
    $ = start.end_ofs;
    ChunkEnd end [[hidden]];
};

struct Rect {
    float x1;
    float y1;
    float x2;
    float y2;
};

struct ThumbnailHeader01 {
    Rect rect1;
    Rect rect2;
    u16 u9;
};

struct ThumbnailHeader {
    ChunkStart start;
    match (start.version_or_type) {
    (0x01):
        ThumbnailHeader01 h;
    (_): 
        std::warning("Unknown header type");
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ThumbnailRleCompressedData06 {
    u32 uncompressed_size;
    u32 I2;
    u32 I3;
    u32 I4;
    u32 I5;
    u32 compressed_size;
    u32 I7;
    u32 I8;
    
    u8 compressedData[compressed_size - 4];

    // Not sure how to decompress this? I mean, I have the algorithm, but not sure what the expected behaviour is?   
    // std::mem::Section uncompressedDataSectopm = std::mem::create_section("uncompressedData");
    // u8 uncompressedData[uncompressed_size] @ 0x00 in uncompressedDataSectopm;
};

struct ThumbnailRleCompressedData {
    ChunkStart start;
    match (start.version_or_type) {
    (0x06):
        ThumbnailRleCompressedData06 d;
    (_): 
        std::warning("Unknown data type");
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ThumbnailData0A {
    u32 I1;
    u32 I2;
    u8 B1;
    u8 B2;
    u8 B3;
    u8 B4;
    u8 B5;
    u8 B6;
    u8 B7;
    u8 B8;
    u8 B9;
    u8 B10;
    u8 B11;
    u8 B12;
    u8 B13;
    u8 B14;
    u8 B15;
    u8 B16;
    float f1;
    float f2;
    u32 I3;
    u16 H1;
    
    ThumbnailRleCompressedData rleCompressedData;

    u8 B17;
};

struct ThumbnailData {
    ChunkStart start;
    match (start.version_or_type) {
    (0x0A):
        ThumbnailData0A d;
    (_): 
        std::warning("Unknown string type");
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct UnknownA {
    ChunkStart start;
    match (start.version_or_type) {
    (0x0D): {
        u16 U1;
    }
    (_): 
        std::warning("Unknown string type");
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct UnknownB {
    ChunkStart start;
    match (start.version_or_type) {
    (0x01): {
        u16 U1[17];
    }
    (_): 
        std::warning("Unknown string type");
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ImageHeader {
    ChunkStart start;
    float f[8];
    u16 u;
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ImageData1C {
    char copyright[0x30];
    char version[0x20];
    u16 u1;
    u32 u2;
    u16 u3;
    u8 u4[3];
    u16 u5[9];

    SubChunk c1;
    ImageHeader header;
};


struct ImageData {
    ChunkStart start;
    match (start.version_or_type) {
    (0x1C): {
        ImageData1C d;
    }
    (_): 
        std::warning("Unknown string type");
    }
    SubChunk subChunks[while($ < start.end_ofs)];
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ZbrData {
    String name;
    ThumbnailHeader thumbnailHeader;
    ThumbnailData thumbnailData;
    UnknownA unknownA;
    UnknownB unknownB;
    ImageData imageData;
};

struct Document {
    char copyright[] @ 0x00;
    char filetype[] @ 0x4C;
    char version[] @ 0x54;

    $ = 0x5C;
    match (filetype) {
        ("RBZ\x00"): ZbrData zbrData;
    }
    Chunk chunks[while($ < sizeof($))];
};

Document document @ 0;