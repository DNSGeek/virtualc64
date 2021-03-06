//
//  CrtFilter.m
//  V64
//
//  Created by Dirk Hoffmann on 18.10.15.
//
//

#import <CrtFilter.h>

@implementation CrtFilter

+ (instancetype)filterWithDevice:(id <MTLDevice>)dev library:(id <MTLLibrary>)lib
{
    return [[self alloc] initWithDevice:dev library:lib];
}

- (instancetype)initWithDevice:(id <MTLDevice>)dev library:(id <MTLLibrary>)lib
{
    if (!(self = [super initWithFunctionName:@"crt" device:dev library:lib]))
        return nil;
    
    return self;
}


@end
