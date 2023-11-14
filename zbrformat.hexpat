#pragma description Quick test decoding the zbrush document structure with https://docs.werwolv.net/imhex/
#pragma author jens.restemeier@gmail.com
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
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && std::mem::read_unsigned($,4) != ChunkTag::end && $ < start.end_ofs && $ < sizeof($))];

    SubChunk subChunks[while($ < start.end_ofs)];
            
    $ = start.end_ofs;
    ChunkEnd end;
};

struct SubChunk {
    Chunk chunk;
    u8 data[while(std::mem::read_unsigned($,4) != ChunkTag::start && std::mem::read_unsigned($,4) != ChunkTag::end && $ < sizeof($))];
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
        std::warning(std::format("Unknown string type {}", start.version_or_type));
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

struct ThumbnailRleCompressedData05 {
    u32 uncompressed_size;
    u16 h[8];
    u32 compressed_size;
    u32 I[2];
    
    u8 compressedData[compressed_size - 4];

    // Not sure how to decompress this? I mean, I have the algorithm, but not sure what the expected behaviour is?   
    // std::mem::Section uncompressedDataSectopm = std::mem::create_section("uncompressedData");
    // u8 uncompressedData[uncompressed_size] @ 0x00 in uncompressedDataSectopm;
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
    (0x05):
        ThumbnailRleCompressedData05 d;
    (0x06):
        ThumbnailRleCompressedData06 d;
    (_): 
        std::warning(std::format("Unknown data type {}", start.version_or_type));
    }
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ThumbnailData05 {
    u32 I[2];
    u8 B[14];

    ThumbnailRleCompressedData rleCompressedData;
};

struct ThumbnailData08 {
    u32 I[2];
    u8 B[16];
    float f1;
    float f2;
    u16 H1;

    ThumbnailRleCompressedData rleCompressedData;
};

struct ThumbnailData0A {
    u32 I[2];
    u8 B[16];
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
    (0x05):
        ThumbnailData05 d;
    (0x08):
        ThumbnailData08 d;
    (0x0A):
        ThumbnailData0A d;
    (_): {
            std::warning(std::format("Unknown record type {}", start.version_or_type));
            //SubChunk subChunks[while($ < start.end_ofs)];
        }
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
        std::warning("Unknown record type");
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
        std::warning("Unknown record type");
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
        std::warning("Unknown record type");
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

struct MaterialData07 {
    u32 I1;
    u32 I2;
    float f1;
    u32 I3;
    u32 I4;
    float f2;
    float f3;
    float f4;
    float f5;
    float f6;
};

struct MaterialData {
    ChunkStart start;
    match (start.version_or_type) {
    (0x07): {
        MaterialData07 d;
    }
    (_): 
        std::warning("Unknown record type");
    }
    SubChunk subChunks[while($ < start.end_ofs)];
    $ = start.end_ofs;
    ChunkEnd end;
};

struct ZmtData {
    String name;
    ThumbnailHeader thumbnailHeader;
    ThumbnailData thumbnailData;
    //String materialName;
    //MaterialData materialData;
};

struct Document {
    char copyright[] @ 0x00;
    char filetype[] @ 0x4C;
    char version[] @ 0x54;

    $ = 0x5C;
    match (filetype) {
        ("RBZ\x00"): ZbrData zbrData;
        ("TMZ\x00"): ZmtData zmtData;
        (_): std::error(std::format("Unknown file type {}", filetype));
    }
    Chunk chunks[while($ < sizeof($))];
};

Document document @ 0;