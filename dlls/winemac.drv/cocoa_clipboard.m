/*
 * MACDRV Cocoa clipboard code
 *
 * Copyright 2012, 2013 Ken Thomases for CodeWeavers Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include "macdrv_cocoa.h"
#import "cocoa_app.h"
#import "cocoa_event.h"


static int owned_change_count = -1;


/***********************************************************************
 *              macdrv_is_pasteboard_owner
 */
int macdrv_is_pasteboard_owner(void)
{
    __block int ret;

    OnMainThread(^{
        NSPasteboard* pb = [NSPasteboard generalPasteboard];
        ret = ([pb changeCount] == owned_change_count);
    });

    return ret;
}


/***********************************************************************
 *              macdrv_copy_pasteboard_types
 *
 * Returns an array of UTI strings for the types of data available on
 * the pasteboard, or NULL on error.  The caller is responsible for
 * releasing the returned array with CFRelease().
 */
CFArrayRef macdrv_copy_pasteboard_types(void)
{
    __block CFArrayRef ret = NULL;
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    OnMainThread(^{
        @try
        {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            NSArray* types = [pb types];
            ret = (CFArrayRef)[types copy];
        }
        @catch (id e)
        {
            ERR(@"Exception discarded while copying pasteboard types: %@\n", e);
        }
    });

    [pool release];
    return ret;
}


/***********************************************************************
 *              macdrv_copy_pasteboard_data
 *
 * Returns the pasteboard data for a specified type, or NULL on error or
 * if there's no such type on the pasteboard.  The caller is responsible
 * for releasing the returned data object with CFRelease().
 */
CFDataRef macdrv_copy_pasteboard_data(CFStringRef type)
{
    __block NSData* ret = nil;

    OnMainThread(^{
        @try
        {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            if ([pb availableTypeFromArray:[NSArray arrayWithObject:(NSString*)type]])
                ret = [[pb dataForType:(NSString*)type] copy];
        }
        @catch (id e)
        {
            ERR(@"Exception discarded while copying pasteboard types: %@\n", e);
        }
    });

    return (CFDataRef)ret;
}


/***********************************************************************
 *              macdrv_clear_pasteboard
 *
 * Takes ownership of the Mac pasteboard and clears it of all data types.
 */
void macdrv_clear_pasteboard(void)
{
    OnMainThreadAsync(^{
        @try
        {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            owned_change_count = [pb declareTypes:[NSArray array] owner:nil];
        }
        @catch (id e)
        {
            ERR(@"Exception discarded while clearing pasteboard: %@\n", e);
        }
    });
}


/***********************************************************************
 *              macdrv_set_pasteboard_data
 *
 * Sets the pasteboard data for a specified type.  Replaces any data of
 * that type already on the pasteboard.  If data is NULL, promises the
 * type.
 *
 * Returns 0 on error, non-zero on success.
 */
int macdrv_set_pasteboard_data(CFStringRef type, CFDataRef data, macdrv_window w)
{
    __block int ret = 0;
    WineWindow* window = (WineWindow*)w;

    OnMainThread(^{
        @try
        {
            NSPasteboard* pb = [NSPasteboard generalPasteboard];
            NSInteger change_count = [pb addTypes:[NSArray arrayWithObject:(NSString*)type]
                                            owner:window];
            if (change_count)
            {
                owned_change_count = change_count;
                if (data)
                    ret = [pb setData:(NSData*)data forType:(NSString*)type];
                else
                    ret = 1;
            }
        }
        @catch (id e)
        {
            ERR(@"Exception discarded while copying pasteboard types: %@\n", e);
        }
    });

    return ret;
}