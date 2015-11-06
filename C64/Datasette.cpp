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

#include "C64.h"

Datasette::Datasette()
{
    name = "Datasette";
    debug(2, "Creating virtual datasette at address %p\n", this);
        
    // Register snapshot items
    SnapshotItem items[] = {
        
        // Tape properties (will survive reset)
        { &size,            sizeof(size),                   KEEP_ON_RESET },
        
        // Internal state (will be cleared on reset)
        { &playKey,         sizeof(playKey),                CLEAR_ON_RESET },
        { &motor,           sizeof(motor),                  CLEAR_ON_RESET },
        { &nextPulse,       sizeof(nextPulse),              CLEAR_ON_RESET },
        { &head,            sizeof(head),                   CLEAR_ON_RESET },
        { NULL,             0,                              0 }};
    
    registerSnapshotItems(items, sizeof(items));
    
    data = NULL;
    size = 0;
}

Datasette::~Datasette()
{
    debug(2, "Releasing Datasette...\n");

    if (data)
        delete data;
}

void
Datasette::reset()
{
    VirtualComponent::reset();
    data = NULL;
    head = -1;
}

void
Datasette::ping()
{
    debug(2, "Pinging Datasette...\n");
#if 0
    c64->putMessage(MSG_VC1541_LED, redLED ? 1 : 0);
    c64->putMessage(MSG_VC1541_MOTOR, rotating ? 1 : 0);
    c64->putMessage(MSG_VC1541_DISK, diskInserted ? 1 : 0);
#endif
}

uint32_t
Datasette::stateSize()
{
    return VirtualComponent::stateSize() + size;
}

void
Datasette::loadFromBuffer(uint8_t **buffer)
{
    uint8_t *old = *buffer;
    
    VirtualComponent::loadFromBuffer(buffer);
    if (size) {
        if (data == NULL)
            data = (uint8_t *)malloc(size);
        readBlock(buffer, (uint8_t *)data, size);
    }
    
    if (*buffer - old != stateSize())
        assert(0);
}

void
Datasette::saveToBuffer(uint8_t **buffer)
{
    uint8_t *old = *buffer;
    
    VirtualComponent::saveToBuffer(buffer);
    if (size) {
        assert(data != NULL);
        writeBlock(buffer, (uint8_t *)data, size);
    }
    
    if (*buffer - old != stateSize())
        assert(0);
}

void
Datasette::dumpState()
{
#if 0
    msg("Datasette\n");
    msg("---------\n\n");
    msg(" Bit ready timer : %d\n", bitReadyTimer);
    msg("   Head position : Track %d, Bit offset %d\n", halftrack, bitoffset);
    msg("            SYNC : %d\n", sync);
    msg("       Read mode : %s\n", readMode() ? "YES" : "NO");
    msg("\n");
#endif
}

void
Datasette::insertTape(TAPArchive *a)
{
    size = a->getSize();
    
    debug(2, "Inserting tape (size = %d)...\n", size);
    
    data = (uint8_t *)malloc(size);
    memcpy(data, a->getData(), size);
    rewind(); 
}

void
Datasette::ejectTape()
{
    debug(2, "Ejecting tape\n");

    if (!hasTape())
        return;

    assert(data != NULL);

    free(data);
    data = NULL;
    size = 0;
}

int
Datasette::getByte()
{
    int result;
    
    if (head < 0)
        return -1;
    
    // get byte
    result = (uint8_t)data[head];
    
    // check for end of file
    if (head == (size - 1)) {
        head = -1;
    } else {
        // advance head
        head++;
    }
    
    return result;
}

int
Datasette::nextPulseLength()
{
    int byte = getByte();
    
    if (byte == -1)
        return -1;
    
    if (byte == 0) {
        return 8 * 255;
    } else {
        return 8 * byte;
    }
}

void
Datasette::pressPlay()
{
    debug("Datasette::pressPlay\n");
    nextPulse = c64->getCycles() + 1;
    playKey = true;
}

void
Datasette::setMotor(bool value)
{
    if (motor == value)
        return;
    
    motor = value;
    debug(2, "Motor %s\n", motor ? "on" : "off");
}

void
Datasette::_execute()
{
    if (c64->getCycles() >= nextPulse) {

        // Trigger pulse
        // debug(2, "Pulse at %lld\n", c64->getCycles());
        
        // Schedule next pulse
        int length = nextPulseLength();
        if (length == -1) {
            debug(2, "End of tape reached.\n");
            playKey = false;
        }
        nextPulse += length;

        // debug(2, "Next pulse in %d cycles\n", length);
        // debug(2, "Cycle: %lld nextPulse at: %lld\n", c64->getCycles(), nextPulse);
    }
}

