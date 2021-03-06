/*!
 * @header      Container.h
 * @author      Dirk W. Hoffmann, www.dirkwhoffmann.de
 * @copyright   2006 - 2016 Dirk W. Hoffmann
 */
/*
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

#ifndef _CONTAINER_INC
#define _CONTAINER_INC

#include "VC64Object.h"

/*! @enum     ContainerType
 *  @brief    The type of a container
 *  @constant CRT_CONTAINER A cartridge that can be plugged into the expansion port.
 *  @constant V64_CONTAINER A snapshot file (contains a frozen C64 state).
 *  @constant D64_CONTAINER A floppy disk image with multiply files.
 *  @constant T64_CONTAINER A tape archive with multiple files.
 *  @constant PRG_CONTAINER A program archive containing a single file.
 *  @constant P00_CONTAINER A program archive containing a single file.
 *  @constant G64_CONTAINER A collection of bit-streams resembling a floppy disk.
 *  @constant NIB_CONTAINER A collection of bit-streams resembling a floppy disk.
 *  @constant TAP_CONTAINER A bit-stream resembling a datasette tape.
 *  @constant FILE_CONTAINER An arbitrary file that is interpreted as raw data.
 */
enum ContainerType {
    CRT_CONTAINER = 1,
    V64_CONTAINER,
    D64_CONTAINER,
    T64_CONTAINER,
    PRG_CONTAINER,
    P00_CONTAINER,
    G64_CONTAINER,
    NIB_CONTAINER,
    TAP_CONTAINER,
    FILE_CONTAINER
};


/*! @class    Container
 *  @brief    Base class for all loadable objects.
 *  @details  The class provides basic functionality for reading and writing files.
 */
class Container : public VC64Object {

private:
	 
    //! @brief    The physical name (full path name) of the archive.
    char *path;
	
protected:

    /*! @brief    The logical name of the archive.
     *  @details  Some archives store a logical name in their header section. If they don't store a special name,
     *            the logical name is the raw filename (path and extension stripped off). 
     */
	char name[256];
    
    
    //
    //! @functiongroup Creating and destructing containers
    //

public:

    //! @brief    Constructor
    Container();

    //! @brief    Destructor
    virtual ~Container();

    //! @brief    Convert file name extension into numerical identifier
    static ContainerType typeOf(const char *extension);
    
private:
    
    //! @brief Frees the memory allocated by this object.
    virtual void dealloc() = 0;

    //
    //! @functiongroup Accessing container attributes
    //

public:
    
	//! @brief    Returns the physical name.
    const char *getPath() { return path ? path : ""; }

    //! @brief    Sets the physical name.
    void setPath(const char *path);

    //! @brief    Returns the logical name.
    virtual const char *getName() { return name; }

    //! @brief    Sets the logical name.
    void setName(const char *name);

    //! @brief    Returns the type of this container.
    virtual ContainerType getType() = 0;

    /*! @brief      Returns the type of this container object as plain text, e.g., "T64" or "D64".
     *  @deprecated Use getType instead.
     */
	virtual const char *getTypeAsString() = 0;
	
    
    //
    //! @functiongroup Serializing a container
    //

    //! @brief    Returns true iff the specified file is a file of this container type.
    virtual bool fileIsValid(const char *filename) = 0;

    /*! @brief    Read container contents from a memory buffer.
     *  @param    buffer The address of a binary representation in memory.
     *  @param    length The size of the binary representation.
     */
	virtual bool readFromBuffer(const uint8_t *buffer, unsigned length) = 0;
	
    /*! @brief    Read container contents from a file.
     *  @details  This function requires no custom implementation. It first reads in the file contents 
     *            in memory and invokes readFromBuffer afterwards. 
     *  @param    filename The name of a file containing a binary representation.
     */
	bool readFromFile(const char *filename);

    /*! @brief    Write container contents into a memory buffer.
     *  @details  If a NULL pointer is passed in, a test run is performed. Test runs are performed to
     *            determine the size of the container on disk.
     *   @param   buffer The address of the buffer in memory.
     */
	virtual unsigned writeToBuffer(uint8_t *buffer);

    /*! @brief    Write container contents to a file.
     *  @details  This function requires no custom implementation. t first invokes writeToBuffer and 
     *            writes the data to disk afterwards.
     *  @param    filename The name of a file to be written.
     */
	bool writeToFile(const char *filename);
};

#endif
