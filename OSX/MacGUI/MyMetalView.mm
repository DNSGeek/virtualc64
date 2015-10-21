/*
 * Author: Dirk W. Hoffmann, 2016
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

#import "C64GUI.h"
#import "ShaderTypes.h"

static CVReturn MetalRendererCallback(CVDisplayLinkRef displayLink,
                                      const CVTimeStamp *inNow,
                                      const CVTimeStamp *inOutputTime,
                                      CVOptionFlags flagsIn,
                                      CVOptionFlags *flagsOut,
                                      void *displayLinkContext)
{
    @autoreleasepool {

        return [(__bridge MyMetalView *)displayLinkContext getFrameForTime:inOutputTime flagsOut:flagsOut];
        
    }
}

@implementation MyMetalView {
    
    // Local metal objects
    id <MTLCommandBuffer> _commandBuffer;
    id <MTLRenderCommandEncoder> _commandEncoder;
    id <CAMetalDrawable> _drawable;
    
    // Matrices
    matrix_float4x4 _modelMatrix;
    matrix_float4x4 _viewMatrix;
    matrix_float4x4 _projectionMatrix;
    matrix_float4x4 _modelViewProjectionMatrix;
    
    // Display link
    CVDisplayLinkRef displayLink;
}


// -----------------------------------------------------------------------------------------------
//                                           Properties
// -----------------------------------------------------------------------------------------------

@synthesize enableMetal;
@synthesize fullscreen;
@synthesize fullscreenKeepAspectRatio;
@synthesize drawC64texture;
@synthesize drawEntireCube;
@synthesize videoFilter;

- (bool)drawInEntireWindow { return drawInEntireWindow; }
- (void)setDrawInEntireWindow:(bool)b
{
    if (drawInEntireWindow == b)
        return;
    
    NSRect r = self.frame;
    float borderThickness;
    if (b) {
        NSLog(@"Expanding metal view");
        r.origin.y -= 24;
        r.size.height += 24;
        borderThickness = 0.0;
    } else {
        NSLog(@"Shrinking metal view");
        r.origin.y += 24;
        r.size.height -= 24;
        borderThickness = 24.0;
    }
    
    self.frame = r;
    [[self window] setContentBorderThickness:borderThickness forEdge: NSMinYEdge];

     drawInEntireWindow = b;
}


// -----------------------------------------------------------------------------------------------
//                                         Initialization
// -----------------------------------------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)c
{
    NSLog(@"MyMetalView::initWithCoder");
    
    if ((self = [super initWithCoder:c]) == nil) {
        NSLog(@"Error: Can't initiaize MetalView");
    }
    return self;
}

-(void)awakeFromNib
{
    NSLog(@"MyMetalView::awakeFromNib");
    
    c64 = [c64proxy c64]; // DEPRECATED
    
    // Create lock used by the draw method
    lock = [NSRecursiveLock new];

    // Set initial scene position and drawing properties
    currentEyeX = targetEyeX = deltaEyeX = 0.0;
    currentEyeY = targetEyeY = deltaEyeY = 0.0;
    currentEyeZ = targetEyeZ = deltaEyeZ = 0.0;
    currentXAngle = targetXAngle = deltaXAngle = 0.0;
    currentYAngle = targetYAngle = deltaYAngle = 0.0;
    currentZAngle = targetZAngle = deltaZAngle = 0.0;
    currentAlpha = targetAlpha = 0.0; deltaAlpha = 0.0;
    
    // Properties
    enableMetal = true; 
    drawInEntireWindow = false;
    fullscreen = false;
    fullscreenKeepAspectRatio = true;
    drawC64texture = false;
    drawBackground = true;
    drawEntireCube = false;
    
    // Metal
    [self setupMetal];
    [self reshape];
    
    // Keyboard initialization
    for (int i = 0; i < 256; i++) {
        pressedKeys[i] = 0;
    }
    
    // Register for drag and drop
    [self registerForDraggedTypes:
    [NSArray arrayWithObjects:NSFilenamesPboardType,NSFileContentsPboardType,nil]];
}

- (void) dealloc
{
    [self cleanup];
}

-(void)cleanup
{
    NSLog(@"MyMetalView::cleanup");
    
    if (displayLink) {
        CVDisplayLinkStop(displayLink);
        CVDisplayLinkRelease(displayLink);
        displayLink = NULL;
    }
    
    if (lock) {
        lock = nil;
    }
}


// -----------------------------------------------------------------------------------------------
//                                         Display link
// -----------------------------------------------------------------------------------------------


- (void)setupDisplayLink
{
    NSLog(@"MyMetalView::setupDisplayLink");
    
    CVReturn success;

    // Create display link for the main display
    CVDisplayLinkCreateWithCGDisplay(kCGDirectMainDisplay, &displayLink);
    NSAssert(displayLink != nil, @"Error: Can't create display link");

    // Set the current display of a display link
    if ((success = CVDisplayLinkSetCurrentCGDisplay(displayLink, kCGDirectMainDisplay)) != 0) {
        NSLog(@"CVDisplayLinkSetCurrentCGDisplay failed with return code %d", success);
        CVDisplayLinkRelease(displayLink);
        exit(0);
    }
    
    // Set the renderer output callback function
    if ((success = CVDisplayLinkSetOutputCallback(displayLink, &MetalRendererCallback, (__bridge void *)self)) != 0) {
        NSLog(@"CVDisplayLinkSetOutputCallback failed with return code %d", success);
        CVDisplayLinkRelease(displayLink);
        exit(0);
    }
    
    // Activates display link
    if ((success = CVDisplayLinkStart(displayLink)) != 0) {
        NSLog(@"CVDisplayLinkStart failed with return code %d", success);
        CVDisplayLinkRelease(displayLink);
        exit(0);
    }
}


// -----------------------------------------------------------------------------------------------
//                                           Drawing
// -----------------------------------------------------------------------------------------------

- (void)updateScreenGeometry
{
    if (c64->isPAL()) {
        
        // PAL border will be 36 pixels wide and 34 pixels heigh
        textureXStart = (float)(PAL_LEFT_BORDER_WIDTH - 36.0) / (float)C64_TEXTURE_WIDTH;
        textureXEnd = (float)(PAL_LEFT_BORDER_WIDTH + PAL_CANVAS_WIDTH + 36.0) / (float)C64_TEXTURE_WIDTH;
        textureYStart = (float)(PAL_UPPER_BORDER_HEIGHT - 34.0) / (float)C64_TEXTURE_HEIGHT;
        textureYEnd = (float)(PAL_UPPER_BORDER_HEIGHT + PAL_CANVAS_HEIGHT + 34.0) / (float)C64_TEXTURE_HEIGHT;
        
    } else {
        
        // NTSC border will be 42 pixels wide and 9 pixels heigh
        textureXStart = (float)(NTSC_LEFT_BORDER_WIDTH - 42.0) / (float)C64_TEXTURE_WIDTH;
        textureXEnd = (float)(NTSC_LEFT_BORDER_WIDTH + NTSC_CANVAS_WIDTH + 42.0) / (float)C64_TEXTURE_WIDTH;
        textureYStart = (float)(NTSC_UPPER_BORDER_HEIGHT - 9) / (float)C64_TEXTURE_HEIGHT;
        textureYEnd = (float)(NTSC_UPPER_BORDER_HEIGHT + NTSC_CANVAS_HEIGHT + 9) / (float)C64_TEXTURE_HEIGHT;
    }
    
    // Enable this for debugging (will display the whole texture)
    /*
     textureXStart = 0.0;
     textureXEnd = 1.0;
     textureYStart = 0.0;
     textureYEnd = 1.0;
     */
    
    [self buildVertexBuffer];
}

- (void)updateTexture:(id<MTLCommandBuffer>) cmdBuffer
{
    if (!c64) {
        NSLog(@"Can't access C64");
        return;
    }
    
    void *buf = c64->vic->screenBuffer();
    assert(buf != NULL);

    NSUInteger pixelSize = 4;
    NSUInteger width = NTSC_PIXELS;
    NSUInteger height = PAL_RASTERLINES;
    NSUInteger rowBytes = width * pixelSize;
    NSUInteger imageBytes = rowBytes * height;
    
    [textureFromEmulator replaceRegion:MTLRegionMake2D(0,0,width,height)
                           mipmapLevel:0 slice:0 withBytes:buf
                           bytesPerRow:rowBytes bytesPerImage:imageBytes];
}

- (void)setFrame:(CGRect)frame
{
    // NSLog(@"MyMetalView::setFrame");

    [super setFrame:frame];

    CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
    CGSize drawableSize = self.bounds.size;
    
    drawableSize.width *= scale;
    drawableSize.height *= scale;
    
    metalLayer.drawableSize = drawableSize;
}

- (void)reshape
{
    CGSize s = [metalLayer drawableSize];
    layerWidth = s.width;
    layerHeight = s.height;

    NSLog(@"CGLayer size %f %f", s.width, s.height);

    // Update projection matrix
    // float aspect = fabs(self.bounds.size.width / self.bounds.size.height);
    float aspect = fabs(layerWidth / layerHeight);
    _projectionMatrix = vc64_matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);    
    _viewMatrix = matrix_identity_float4x4;
    
    // Update matrices for background drawing
    _modelMatrix = matrix_identity_float4x4;
    _modelViewProjectionMatrix = _projectionMatrix * _viewMatrix * _modelMatrix;
    Uniforms *frameDataBg = (Uniforms *)[uniformBufferBg contents];
    frameDataBg->model = _modelMatrix;
    frameDataBg->view = _viewMatrix;
    frameDataBg->projectionView = _modelViewProjectionMatrix;
    frameDataBg->alpha = 1.0;

    // Rebuild depth buffer and tmp drawing buffer
    [self buildDepthBuffer];
}

- (void)buildMatrices2D
{
    _modelMatrix = vc64_matrix_from_translation(0, 0, 0);
    _viewMatrix = matrix_identity_float4x4;
    _projectionMatrix = matrix_identity_float4x4;
    _modelViewProjectionMatrix = _projectionMatrix * _viewMatrix * _modelMatrix;
    
    Uniforms *frameData = (Uniforms *)[uniformBuffer contents];
    frameData->model = _modelMatrix;
    frameData->view = _viewMatrix;
    frameData->projectionView = _modelViewProjectionMatrix;
    frameData->alpha = 1.0;
}

- (void)buildMatrices3D
{
    _modelMatrix = vc64_matrix_from_translation(-currentEyeX, -currentEyeY, currentEyeZ+1.39);
    
    if ([self animates]) {
        _modelMatrix = _modelMatrix *
        vc64_matrix_from_rotation(-(currentXAngle / 180.0)*M_PI, 0.5f, 0.0f, 0.0f) *
        vc64_matrix_from_rotation((currentYAngle / 180.0)*M_PI, 0.0f, 0.5f, 0.0f) *
        vc64_matrix_from_rotation((currentZAngle / 180.0)*M_PI, 0.0f, 0.0f, 0.5f);
    }
    
    _modelViewProjectionMatrix = _projectionMatrix * _viewMatrix * _modelMatrix;

    Uniforms *frameData = (Uniforms *)[uniformBuffer contents];
    frameData->model = _modelMatrix;
    frameData->view = _viewMatrix;
    frameData->projectionView = _modelViewProjectionMatrix;
    frameData->alpha = (c64->isHalted()) ? 0.5 : currentAlpha;
}

- (TextureFilter *)currentFilter
{
    switch (videoFilter) {
        case TEX_FILTER_NONE:
            return bypassFilter;
            
        case TEX_FILTER_SMOOTH:
            return smoothFilter;
            
        case TEX_FILTER_BLUR:
            return blurFilter;
            
        case TEX_FILTER_SATURATION:
            return saturationFilter;
            
        case TEX_FILTER_GRAYSCALE:
            return grayscaleFilter;
            
        case TEX_FILTER_SEPIA:
            return sepiaFilter;
            
        case TEX_FILTER_CRT:
            return crtFilter;
            
        default:
            return smoothFilter;
    }
}

- (BOOL)startFrame
{
    CGSize drawableSize = metalLayer.drawableSize;
    
    // if (!_depthTexture || _depthTexture.width != drawableSize.width || _depthTexture.height != drawableSize.height) {
    
    // Update all size dependent entities
    if (layerWidth != drawableSize.width || layerHeight != drawableSize.height) {
        [self reshape];
    }
    
    framebufferTexture = _drawable.texture;
    NSAssert(framebufferTexture != nil, @"Framebuffer texture must not be nil");
    
    _commandBuffer = [queue commandBuffer];
    NSAssert(_commandBuffer != nil, @"Metal command buffer must not be nil");

    // Apply filter
    TextureFilter *filter = [self currentFilter];
    [filter apply:_commandBuffer in:textureFromEmulator out:filteredTexture];
    
    // Create render pass
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    {
        renderPass.colorAttachments[0].texture = framebufferTexture;
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
        renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        renderPass.depthAttachment.texture = depthTexture;
        renderPass.depthAttachment.clearDepth = 1;
        renderPass.depthAttachment.loadAction = MTLLoadActionClear;
        renderPass.depthAttachment.storeAction = MTLStoreActionDontCare;
    }
    
    // Create command encoder
    _commandEncoder = [_commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    {
        [_commandEncoder setRenderPipelineState:pipeline];
        [_commandEncoder setDepthStencilState:depthState];
        [_commandEncoder setFragmentTexture:bgTexture atIndex:0];
        [_commandEncoder setFragmentSamplerState:[filter sampler] atIndex:0];
        [_commandEncoder setVertexBuffer:positionBuffer offset:0 atIndex:0];
        [_commandEncoder setVertexBuffer:uniformBuffer offset:0 atIndex:1];
    }
    
    return YES;
}

- (void)drawScene2D
{
    [self buildMatrices2D];
    
    if (![self startFrame])
        return;
    
    // Render quad
    [_commandEncoder setFragmentTexture:filteredTexture atIndex:0];
    [_commandEncoder setVertexBuffer:uniformBuffer offset:0 atIndex:1];
    [_commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:42 vertexCount:6 instanceCount:1];
    
    [self endFrame];
}

- (void)drawScene3D
{
    bool animates = [self animates];
    
    drawEntireCube = animates;
    drawBackground = !fullscreen; 
    
    if (animates) {
        [self updateAngles];
    }
    [self buildMatrices3D];
    
    if (![self startFrame])
        return;
    
    // Render background
    if (drawBackground) {
        [_commandEncoder setFragmentTexture:bgTexture atIndex:0];
        [_commandEncoder setVertexBuffer:uniformBufferBg offset:0 atIndex:1];
        [_commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6 instanceCount:1];
    }
    
    // Render cube
    if (drawC64texture) {
        [_commandEncoder setFragmentTexture:filteredTexture atIndex:0];
        [_commandEncoder setVertexBuffer:uniformBuffer offset:0 atIndex:1];
        [_commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:6 vertexCount:(drawEntireCube ? 24 : 6) instanceCount:1];
    }
    
    [self endFrame];
}

- (void)endFrame
{
    [_commandEncoder endEncoding];
    
    if (_drawable)
    {
        [_commandBuffer presentDrawable:_drawable];
        [_commandBuffer commit];
    }
}

- (CVReturn)getFrameForTime:(const CVTimeStamp*)timeStamp flagsOut:(CVOptionFlags*)flagsOut
{
    @autoreleasepool {
        
        if (!c64 || !enableMetal)
            return kCVReturnSuccess;
        
        if (![lock tryLock])
            return kCVReturnSuccess;
        
        // Get drawable from layer
        if (!(_drawable = [metalLayer nextDrawable])) {
            NSLog(@"Metal drawable must not be nil");
            [lock unlock];
            return NO;
        }

        // Get C64 texture from emulator
        [self updateTexture:_commandBuffer];

        // Draw scene
        if (fullscreen && !fullscreenKeepAspectRatio) {
            [self drawScene2D];
        } else {
            [self drawScene3D];
        }
        
        [lock unlock];
        return kCVReturnSuccess;
    }
}



@end
