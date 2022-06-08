import os, os.path, struct
from PIL import Image

def makeString(data) -> str:
    return data[:data.find(0)].decode("cp1252")

class ZbrLoader:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.data = f.read()
        self.filetype = makeString(self.data[0x4C:0x4C+4])[::-1]
        self.version = makeString(self.data[0x54:0x5B])
        self.type = struct.unpack_from("<I", self.data, 0x4C)
        self.pos = 0x5C

    def openstruct(self):
        tag, type, length = struct.unpack_from("<IHI", self.data, self.pos)
        if tag != 0x00018003:
            raise Exception("open tag expected, got %8.8x" % tag)
        self.pos += 10
        return type,self.pos,length

    def skipstruct(self, st):
        self.pos = st[1] - 10 + st[2] - 4

    def closestruct(self):
        tag, = struct.unpack_from("<I", self.data, self.pos)
        if tag != 0x00008803:
            raise Exception("close tag expected, got %8.8x" % tag)
        self.pos += 4

    def read(self, count : int):
        data = self.data[self.pos:self.pos+count]
        self.pos += count
        return data

    def read_rle(self, count : int):
        data = []
        end = self.pos + count
        while self.pos < end:
            cmd = self.data[self.pos]
            self.pos += 1
            if cmd >= 128:
                run_len = (255 - cmd) + 1
                for i in range(run_len):
                    val = self.data[self.pos+i]
                    data.append(val)
                self.pos += run_len
            else:
                run_len = cmd
                val = self.data[self.pos]
                self.pos += 1
                for i in range(run_len):
                    data.append(val)
        return data

    def getname(self) -> str:
        st = self.openstruct()
        if st[0] == 0x0c or st[0] == 0x0e:
            s = makeString(self.data[st[1]+2:st[1] - 10 +st[2] - 4])
        else:
            raise "unknown string type %4.4x" % st[0]
        self.skipstruct(st)
        self.closestruct()
        return s
    
    def getunknown(self) -> bytes:
        st = self.openstruct()
        data = self.data[st[1]:st[1] - 10 + st[2] - 4]
        self.pos = st[1] - 10 + st[2] - 4
        self.closestruct()
        return data

class ZbrThumbnail:
    def __init__(self):
        pass

    def getimage(self) -> Image:
        width,height = int(self.header[2]), int(self.header[3])
        im = Image.new("RGB", (width, height))

        data = self.data[1][1]
        size = width * height
        im.putdata(list(zip(data[size*2:size*3], data[0:size], data[size:size*2])))

        return im

    @staticmethod
    def getheader(loader: ZbrLoader):
        st = loader.openstruct()

        if st[0] == 0x01:
            data = struct.unpack("<ffffffffH", loader.read(34))
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return data

    @staticmethod
    def getcompresseddata(loader):
        st = loader.openstruct()
        if st[0] == 0x06:
            header = struct.unpack("<IIIIIIII", loader.read(32))
            uncompressed_size = header[0]
            compressed_size = header[5]
            data = loader.read_rle(compressed_size - 8)
            endmarker = struct.unpack("<I", loader.read(4))
            print ("compressed: ", header, "%x" % loader.pos, len(data), st[2])
            if len(data) != uncompressed_size:
                raise Exception("uncompressed size doesn't match %i != %i" % (len(data), uncompressed_size))
            data = (header, data, endmarker)
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return data

    @staticmethod
    def getdata(loader : ZbrLoader):
        st = loader.openstruct()
        
        if st[0] == 0x0A:
            header = struct.unpack("<IIBBBBBBBBBBBBBBBBffIH", loader.read(0x26))
            compressed = ZbrThumbnail.getcompresseddata(loader)
            unknown = loader.read(1)[0]

            data = (header, compressed, unknown)
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return (data)

    @staticmethod
    def create(loader : ZbrLoader):
        thumbnail = ZbrThumbnail()
        thumbnail.name = loader.getname()
        thumbnail.header = ZbrThumbnail.getheader(loader)
        thumbnail.data = ZbrThumbnail.getdata(loader)
        # print (thumbnail.header)

        return thumbnail

class ZbrCanvas:
    def __init__(self):
        pass

    @staticmethod
    def getheader(loader : ZbrLoader):
        st = loader.openstruct()

        if st[0] == 0x01:
            data = struct.unpack("<ffffffffH", loader.read(34))
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return data

    @staticmethod
    def getheader2(loader : ZbrLoader):
        st = loader.openstruct()

        if st[0] == 0x01:
            data = struct.unpack("<ffffffffH", loader.read(34))
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return data

    @staticmethod
    def getcompresseddata(loader):
        st = loader.openstruct()
        if st[0] == 0x06:
            header = struct.unpack("<IHHIIIIII", loader.read(32))
            print ("compressed: ", header, st[2])
            uncompressed_size = header[0]
            compressed_size = header[6]
            if False:
                data = loader.read_rle(compressed_size - 8) # this seems to be a 214 pixel wide image with 4 channels following each other
                data2 = loader.read_rle(header[6] - 4) # another 214 pixel
                data3 = loader.read_rle(header[7]) # another 214 pixel
                print (len(data), len(data2), len(data3))
    
                with open ("data.bin", "wb") as f:
                    f.write(bytes(data))
                with open ("data2.bin", "wb") as f:
                    f.write(bytes(data2))
                with open ("data3.bin", "wb") as f:
                    f.write(bytes(data3))
       
            else:
                compressed = st[2] - 32 - 8
                data = loader.read_rle(compressed) # 214*2383 pixel of graphics data (separate channels)
                print (len(data),  compressed) # closer to correct decompressed size, but still missing a bit...

                with open ("data.bin", "wb") as f:
                    f.write(bytes(data))
            endmarker = struct.unpack("<I", loader.read(4))
            # not sure about this one...
            if False and len(data) != uncompressed_size:
                raise Exception("uncompressed size doesn't match %i != %i" % (len(data), uncompressed_size))

            loader.skipstruct(st)
            data = (header, data, endmarker)
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return data

    @staticmethod
    def getdata2(loader : ZbrLoader):
        st = loader.openstruct()
        
        if st[0] == 0x0A:
            header = struct.unpack("<IIBBBBBBBBBBBBBBBBffIH", loader.read(0x26))
            print (header)
            compressed = ZbrCanvas.getcompresseddata(loader)
            unknown = loader.read(1)[0]

            data = (header, compressed, unknown)
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        loader.closestruct()
        return (data)


    @staticmethod
    def getdata(loader : ZbrLoader):
        st = loader.openstruct()

        if st[0] == 0x1C:
            unknown = loader.read(0x50) # some copyright string?
            header = struct.unpack("<fIBBBBIfffB", loader.read(29))
            print (header)
            name = loader.getname()
            header2 = ZbrCanvas.getheader2(loader)
            print (header2)
            data2 = ZbrCanvas.getdata2(loader)
            # image = ZbrThumbnail.create(loader)

            data = (header,)
        else:
            raise Exception("Unexpected header version %4.4x" % st[0])

        # loader.closestruct()
        return data

    @staticmethod
    def create(loader : ZbrLoader):
        canvas = ZbrCanvas()
        canvas.thumbnail = ZbrThumbnail.create(loader)
        print ("-" * 80)
        canvas.unknown1 = loader.getunknown()
        canvas.header = ZbrCanvas.getheader(loader)
        print (canvas.header)
        canvas.data = ZbrCanvas.getdata(loader)

        return canvas

def ZbrLoad(path : str):
    loader = ZbrLoader(path)
    if loader.filetype == "ZBR":
        return ZbrCanvas.create(loader)

def main():
    doc = ZbrLoad("data/ZBrush Document.ZBR")

    im = doc.thumbnail.getimage()
    im.save("data/ZBrush Document.thumbnail.png")

if __name__ == "__main__":
    main()

