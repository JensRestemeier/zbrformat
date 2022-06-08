# zbrformat
These are my investigations into the file format used for ZBrush. Unfortunatly it is far from complete, and it can just about extract a thumbnail from existing files.

## zbrformat.py
This is a tool to extract the document structure of ZBrush documents. It does some brute-force searching, as I don't think the file contains all information to parse it, and the data layout depends on the internal data structures of the program.

As far as I can tell a file is made of a list of blocks, each block can contain a number of children. Data is stored little endian.
A block starts with 0x00018003, followed by a 16 bit number, followed by a 32 bit block size, and ends with 0x00008803.
My first thought was that the 16 bit number is an identifier, but they seem to be re-used for completely different structures. It is quite possible that this is a version number instead, and the data type is known by the loader.

## zbropen.py
A start of file loader - I am a bit stuck on decompressing the main image, though.
