import struct, os.path, os, glob
from PIL import Image

def makeString(data):
    return data[:data.find(0)].decode("cp1252")

def drawStructure(data, record_pos, indent=0):
    tag_start,t,l = struct.unpack_from("<IHI", data, record_pos)
    print ("%s%8.8x %4.4x %8.8x" % (" " * indent, tag_start,t,l))
    indent += 1
    if t == 0x0C or t == 0x0E:
        # string?
        print ("%sstr \"%s\"" % (" " * indent, makeString(data[record_pos+12:record_pos+12+l-4])))
    else:
        ofs = record_pos + 10
        end = record_pos + l - 4
        while ofs < end:
            c = 0
            while tuple(data[ofs+c:ofs+c+4]) != (0x03, 0x80, 0x01, 0x00) and c+ofs < end:
                c += 1
            if c > 0:
                if c < 64:
                    print("%s[%s]" % (" " * indent, " ".join("%2.2x" % x for x in data[ofs:ofs+c])))
                else:
                    print("%s[%s...]" % (" " * indent, " ".join("%2.2x" % x for x in data[ofs:ofs+64])))
            ofs += c
            if ofs < end and tuple(data[ofs:ofs+4]) == (0x03, 0x80, 0x01, 0x00):
                ofs = drawStructure(data, ofs, indent)

    indent -= 1
    tag_end, = struct.unpack_from("<I", data, record_pos+l-4)
    print("%s%8.8x" % (" " * indent, tag_end))
    return record_pos + l

def parseZbr(path : str):
    print ("path:%s" % path)
    dirname = os.path.dirname(path)
    name,_ = os.path.splitext(os.path.basename(path))
    with open(path, "rb") as f:
        data = f.read()
    copyright = makeString(data[0:0x2E])
    filetype = makeString(data[0x4C:0x4C+4])[::-1]
    version = makeString(data[0x54:0x5B])
    print ("header: %s %s %s" % (copyright, filetype, version))

    # thumbnail w/h stored as float?
    w1,h1 = struct.unpack_from("<ff", data, 0x84)
    w2,h2 = struct.unpack_from("<ff", data, 0x94)
    print (w1, h1, w2, h2)

    # guess the start of the rle compressed icon data
    _, id, _ = struct.unpack_from("<IHI", data, 0xA2)
    if id == 0x05:
        rleStart = 0xE8
    elif id == 0x08:
        rleStart = 0xF8
    elif id == 0x09:
        rleStart = 0xFC
    elif id == 0x0A:
        rleStart = 0xFC

    # RLE-compressed thumbnail
    icon = Image.new("RGB", (96,96))
    icon_data = []
    rlePos = rleStart
    while len(icon_data) < (icon.width * icon.height * 3):
        cmd = data[rlePos]
        rlePos += 1
        if cmd >= 128:
            run_len = (255 - cmd) + 1
            for i in range(run_len):
                val = data[rlePos+i]
                icon_data.append(val)
            rlePos += run_len
        else:
            run_len = cmd
            val = data[rlePos]
            rlePos += 1
            for i in range(run_len):
                icon_data.append(val)
    icon.putdata(list(zip(icon_data[0:96*96], icon_data[96*96:96*96*2], icon_data[96*96*2:96*96*3])))
    icon.save(os.path.join(dirname, "%s_icon.png" % name))

    # try to dump the file structures:
    print ("Structure:")
    record_pos = 0x5C
    while record_pos < len(data):
        record_pos = drawStructure(data, record_pos)
    print ("-" * 80)

def main():
    for f in glob.glob("data/*.ZBR"):
        parseZbr(f)
    if False:
        for f in glob.glob("data/*.ZMT"):
            parseZbr(f)
        for f in glob.glob("data/*.ZPR"):
            parseZbr(f)
        for f in glob.glob("data/*.ZMO"):
            parseZbr(f)
        for f in glob.glob("data/*.ZTL"):
            parseZbr(f)

if __name__ == "__main__":
    main()

