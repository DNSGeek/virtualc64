/*
 * Written 2015 by Dirk W. Hoffmann
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef _DISK525_INC
#define _DISK525_INC

#include "VirtualComponent.h"
#include "D64Archive.h"

class C64;

// -----------------------------------------------------------------------------------------------
//                                      Types and constants
// -----------------------------------------------------------------------------------------------

// The VC1541 drive head can move between position 1 and 85.
// The odd numbers between 1 and 70 mark the 35 tracks that are used by VC1541 DOS. This means
// that DOS moves the drive head always two positions up or down. If programmed manually, the
// can also be position on half tracks and on tracks beyond 35. This leads to the following layout:
//
//                      -----------------------------------------------------------------------------
// Track layout:        |  1  | 1.5 |  2  | 2.5 |  3  | 3.5 | ... |  35  | 35.5 | ... |  42  | 42.5 |
//                      -----------------------------------------------------------------------------
// Halftrack addressing:   1  |  2  |  3  |  4  |  5  |  6  |     |  69  |  70  |     |  83  |  84
// Track addressing:       1  |     |  2  |     |  3  |     |     |  35  |      |     |  42  |

/*! @brief Track number in halftrack adressing (1 - 84) */
typedef unsigned Halftrack;

/*! @brief Checks if a given number is a valid halftrack number */
static bool isHalftrackNumber(unsigned nr) { return 1 <= nr && nr <= 84; }

/*! @brief Track number in track adressing (1 - 42) */
typedef unsigned Track;

/*! @brief Checks if a given number is a valid track number */
static bool isTrackNumber(unsigned nr) { return 1 <= nr && nr <= 42; }

/*! @brief      Maximum number of files that can be stored on a single disk
 @discussion VC1541 DOS stores the directors on track 18 which contains 19 sectors. Sector 0 is
 reserved for the BAM. Each of the remaining sectors can hold up to 8 directory entries,
 summing um to a total of 144 items.  */
const static unsigned MAX_FILES_ON_DISK = 144;


// -----------------------------------------------------------------------------------------------
//                                               Disk525
// -----------------------------------------------------------------------------------------------


class Disk525 : VirtualComponent {
    
public:
    
    //! Constructor
    Disk525();

    //! Destructor
    ~Disk525();

    //! Reset
    void reset(C64 *c64);

    //! Size of internal state
    uint32_t stateSize();
    
    //! Load state
    void loadFromBuffer(uint8_t **buffer);
    
    //! Save state
    void saveToBuffer(uint8_t **buffer);
    
    //! Dump current state into logfile
    void dumpState();
    
    
private:
    
    /*! @brief    GCR encoding table
        @abstract Maps 4 data bits to 5 GCR bits */
    const uint16_t gcr[16] = {
        0x0a, 0x0b, 0x12, 0x13,
        0x0e, 0x0f, 0x16, 0x17,
        0x09, 0x19, 0x1a, 0x1b,
        0x0d, 0x1d, 0x1e, 0x15
    };
    
    /*! @brief    Inverse GCR encoding table
        @abstract Maps 5 data bits to 4 GCR bits. Initialized in constructor */
    uint8_t invgcr[32];

    
    // -----------------------------------------------------------------------------------------------
    //                                      Disk data
    // -----------------------------------------------------------------------------------------------

public:
    
    //! Disk data
    /*! Each tracks can store a maximum of 7928 bytes. The number varies depends on the track number
        (inner tracks contain fewer bytes) and the actual write speed of a drive.
        The first valid track and halftrack number is 1. Hence, the entries [0][x] are unused. 
        data.halftack[i] : pointer to the first byte of halftrack i
        data.track[i]    : pointer to the first byte of track i */
    union {
        struct {
            uint8_t _pad[7928];
            uint8_t halftrack[85][7928];
        };
        uint8_t track[43][2 * 7928];
    } data;

    //! Length of each halftrack in bytes
    /*! length.halftack[i] : length of halftrack i
        length.track[i][0] : length of track i
        length.track[i][1] : length of halftrack above track i */
    union {
        struct {
            uint16_t _pad;
            uint16_t halftrack[85];
        };
        uint16_t track[43][2];
    } length;

    /*! 
     @brief    Length of each halftrack in bits
     @abstract length.halftack[i] = length of halftrack i
               length.track[i][0] = length of track i
               length.track[i][1] = length of halftrack above track i 
     */
    union {
        struct {
            uint16_t _pad;
            uint16_t halftrack[85];
        };
        uint16_t track[43][2];
    } bitlength;

    //! Total number of tracks on this disk
    // DEPRECATED (ADD METHOD emptyTrack(Track nr);) (Scans track for data, returns true/false numTracks())
    uint8_t numTracks;

    //! Returns true if track/offset indicates a valid disk position on disk
    bool isValidDiskPositon(Halftrack ht, uint16_t offset) {
        return isHalftrackNumber(ht) && offset < length.halftrack[ht]; }
    
    
public:
    
    // Low-level disk reading
    
    /*!
     @abstract  Reads a single bit from disk
     @param     data    Pointer to the first data byte of a track
     @param     offset  Number of bit to read (first bit has offset 0)
     @result	returns 0 or 1
     */
    inline uint8_t readBit(uint8_t *data, unsigned offset) {
        return (data[offset / 8] & (0x80 >> (offset % 8))) ? 1 : 0; }

    /*!
     @abstract  Reads a single bit from disk
     @param     ht      Number of halftrack to read from
     @param     offset  Number of bit to read (first bit has offset 0)
     @result	returns 0 or 1
     */
    inline uint8_t readBitFromHalftrack(Halftrack ht, unsigned offset) {
        assert(isHalftrackNumber(ht)); return readBit(data.halftrack[ht], offset); }

    /*!
     @abstract  Reads a single byte from disk
     @param     data    Pointer to the first data byte of a track
     @param     offset  Position of first bit to read (first bit has offset 0)
     @result	returns Byte on disk
     */
    inline uint8_t readByte(uint8_t *data, unsigned offset) {
        uint8_t result = 0;
        for (uint8_t i = 0, mask = 0x80; i < 8; i++, mask >>= 1)
            if (readBit(data, offset + i)) result |= mask;
        return result;
    }

    /*!
     @abstract  Reads a single byte from disk
     @param     ht      Number of halftrack to read from
     @param     offset  Position of first bit to read (first bit has offset 0)
     @result	returns 0 or 1
     */
    inline uint8_t readByteFromHalftrack(Halftrack ht, unsigned offset) {
        assert(isHalftrackNumber(ht)); return readByte(data.halftrack[ht], offset); }

    
    // Low-level disk writing
    
    /*!
     @abstract  Sets a single bit on disk to 1
     @param     data   Pointer to the first data byte of a track
     @param     offset Number of bit to set to 1 (first bit has offset 0)
     */
    inline void setBit(uint8_t *data, unsigned offset) {
        data[offset / 8] |= (0x80 >> (offset % 8)); }
    
    /*!
     @abstract  Clears a single bit on disk
     @param     data   Pointer to the first data byte of a track
     @param     offset Number of bit to clear (first bit has offset 0)
     */
    inline void clearBit(uint8_t *data, unsigned offset) {
        data[offset / 8] &= ~(0x80 >> (offset % 8)); }

    /*!
     @abstract  Writes a single bit to disk
     @param     data   Pointer to the first data byte of a track
     @param     offset Number of bit to write (first bit has offset 0)
     @param     bit    0 for a '0' bit, every other value for a '1' bit
     */
    inline void writeBit(uint8_t *data, unsigned offset, uint8_t bit) {
        if (bit) setBit(data, offset); else clearBit(data, offset); }
    
    /*!
     @abstract  Writes a single bit to disk
     @param     ht     Number of halftrack to write to
     @param     offset Number of bit to write (first bit has offset 0)
     @param     bit    0 for a '0' bit, every other value for a '1' bit
     */
    inline void writeBitToHalftrack(Halftrack ht, unsigned offset, uint8_t bit) {
        assert(isHalftrackNumber(ht)); writeBit(data.halftrack[ht], offset, bit); }
 
    /*!
     @abstract  Writes a single byte to disk
     @param     data   Pointer to the first data byte of a track
     @param     offset Number of fist bit to write
     @param     byte   Byte to write
     */
    inline void writeByte(uint8_t *data, unsigned offset, uint8_t byte) {
        for (uint8_t i = 0, mask = 0x80; i < 8; i++, mask >>= 1)
            writeBit(data, offset + i, byte & mask);
    }

    /*!
     @abstract  Writes a single byte to disk
     @param     ht     Number of halftrack to write to
     @param     offset Number of fist bit to write
     @param     byte   Byte to write
     */
    inline void writeByteToHalftrack(Halftrack ht, unsigned offset, uint8_t byte) {
        assert(isHalftrackNumber(ht)); writeByte(data.halftrack[ht], offset, byte); }
    
    
    // Initialization and debugging
    
    //! Zero out whole disk
    void clearDisk();

    //! Zero out a single halftrack
    void clearHalftrack(Halftrack ht);
    
    //! Print some track data (for debugging)
    void dumpHalftrack(Halftrack ht, unsigned min = 0, unsigned max = UINT_MAX, unsigned highlight = UINT_MAX);


    // ---------------------------------------------------------------------------------------------
    //                                         Data encoding
    // ---------------------------------------------------------------------------------------------
    
public:
    
    //! Converts a D64 archive into a virtual floppy disk
    /*! The methods creates sync marks, GRC encoded header and data blocks, checksums and gaps */
    void encodeArchive(D64Archive *a);
    
private:
    
    //! Encode a single track
    /*! This function translates the logical byte sequence of a single track into the native VC1541
     byte representation. The native representation includes sync marks, GCR data etc.
     tailGapEven is the number of tail bytes follwowing sectors with even sector numbers.
     tailGapOdd is the number of tail bytes follwowing sectors with odd sector numbers.
     Returns the number of bytes written */
    unsigned encodeTrack(D64Archive *a, Track t, int *sectorList, uint8_t tailGapEven, uint8_t tailGapOdd);
    
    //! Encode a single sector
    /*! This function translates the logical byte sequence of a single sector into the native VC1541
     byte representation. The sector is closed by 'gap' tail gap bytes.
     Returns the number of bytes written. */
    unsigned encodeSector(D64Archive *a, Track t, uint8_t sector, uint8_t *dest, int gap);
    
    //! Write five SYNC bytes
    void encodeSync(uint8_t *dest) { for (unsigned i = 0; i < 5; i++) dest[i] = 0xFF; }
    
    //! Write interblock gap
    void encodeGap(uint8_t *dest, unsigned size) { for (unsigned i = 0; i < size; i++) dest[i] = 0x55; }
    
    //! Translate 4 data bytes into 5 GCR encodes bytes
    void encodeGcr(uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4, uint8_t *dest);
    
    // ---------------------------------------------------------------------------------------------
    //                                         Data decoding
    // ---------------------------------------------------------------------------------------------

public:
    
    //! Converts a virtual floppy disk to a byte stream compatible with the D64 format
    /*! Returns the number of bytes written.
     If dest is NULL, a test run is performed (used to determine how many bytes will be written).
     If something went wrong, an error code is written to 'error' (0 = no error = success) */
    unsigned decodeDisk(uint8_t *dest, int *error = NULL);
    
private:
    
    //! Decodes all sectors of a single GCR encoded track
    unsigned decodeTrack(uint8_t *source, uint8_t *dest, int *error = NULL);
    
    //! Decodes a single GCR encoded sector and write out its 256 data bytes
    void decodeSector(uint8_t *source, uint8_t *dest);
    
    //! Decodes 5 GCR bytes into its 4 corrrsponding data bytes
    void decodeGcr(uint8_t b1, uint8_t b2, uint8_t b3, uint8_t b4, uint8_t b5, uint8_t *dest);
    
};
    
#endif
