// BMFont_structs.h

/// BMFont binary file format support structs

#pragma pack(push, 1) // Structs are tightly packed on byte bounds

struct BMF_blockInfo
{
    short        fontSize     : 16; ///< using int here results in incorrect alignment
    unsigned int bitField     :  8;
    unsigned int charSet      :  8;
    unsigned int stretchH     : 16;
    unsigned int aa           :  8;
    unsigned int paddingUp    :  8;
    unsigned int paddingRight :  8;
    unsigned int paddingDown  :  8;
    unsigned int paddingLeft  :  8;
    unsigned int spacingHoriz :  8;
    unsigned int spacingVert  :  8;
    unsigned int outline      :  8;
};

struct BMF_blockCommon
{
    unsigned int lineHeight : 16;
    unsigned int base       : 16;
    unsigned int scaleW     : 16;
    unsigned int scaleH     : 16;
    unsigned int pages      : 16;
    unsigned int bitField   : 8;
    unsigned int alphaChnl  : 8;
    unsigned int redChnl    : 8;
    unsigned int greenChnl  : 8;
    unsigned int blueCHnl   : 8;
};

struct BMF_char
{
    unsigned int id   : 32;
    unsigned int x    : 16;
    unsigned int y    : 16;
    unsigned int w    : 16;
    unsigned int h    : 16;
    unsigned int xoff : 16;
    unsigned int yoff : 16;
    unsigned int xadv : 16;
    unsigned int page :  8;
    unsigned int chnl :  8;
};

struct BMF_kern
{
    unsigned int first  :32;
    unsigned int second :32;
    short        amount :16;

    BMF_kern() {}
    BMF_kern(int f, int s, short a) : first(f), second(s), amount(a) {}
};
#pragma pack(pop)
