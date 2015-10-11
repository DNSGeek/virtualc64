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


// Number of buffers (do we need more than one?)
const NSUInteger noOfBuffers = 3;

@implementation MyMetalView {

    // Currently used buffer
    uint8_t _bufferIndex;
    
    // Renderer
    CAMetalLayer *_metalLayer;
    id <MTLDevice> _device;
    id <MTLLibrary> _library;
    id <MTLRenderPipelineState> _pipeline;
    id <MTLDepthStencilState> _depthState;
    id <MTLCommandQueue> _commandQueue;
    id <MTLCommandBuffer> _commandBuffer;
    id <MTLRenderCommandEncoder> _commandEncoder;
    id <MTLBuffer> _positionBuffer;
    id <MTLBuffer> _colorBuffer;

    // Textures
    id <CAMetalDrawable> _drawable;
    id <MTLTexture> _framebufferTexture;

    id <MTLTexture> _texture;
    id <MTLTexture> _depthTexture;
    id <MTLSamplerState> _sampler;

    // Uniforms
    id <MTLBuffer> _uniformBuffers[noOfBuffers];
    matrix_float4x4 _projectionMatrix;
    matrix_float4x4 _viewMatrix;
    float _angle; // Rotation angle
    
    // Display link
    CVDisplayLinkRef displayLink;
    
    //
    BOOL _pipelineIsDirty;
}

#if 0
- (id)initWithFrame:(NSRect)frameRect pixelFormat:(NSOpenGLPixelFormat *)pixFmt
{
    NSLog(@"MyMetalView::initWithFrame");
    
    if ((self = [super initWithFrame:frameRect pixelFormat:pixFmt]) == nil) {
        NSLog(@"ERROR: Can't initiaize MetalView");
    }
    return self;
}
#endif

- (id)initWithCoder:(NSCoder *)c
{
    NSLog(@"MyMetalView::initWithCoder");
    
    if ((self = [super initWithCoder:c]) == nil) {
        NSLog(@"ERROR: Can't initiaize MetalView");
    }
    return self;
}

-(void)awakeFromNib
{
    NSLog(@"MyMetalView::awakeFromNib");
    
    c64 = [c64proxy c64]; // DEPRECATED
    
    _bufferIndex = 0;
    _angle = 0;
    _pipelineIsDirty = YES;
    
    // To setup metal, there are seven things to do:
    // 1. Create a MTLDevice
    // 2. Create a CAMetalLayer
    // 3. Create a Vertex Buffer
    // 4. Create a Vertex Shader
    // 5. Create a Fragment Shader
    // 6. Create a Render Pipeline
    // 7. Create a Command Queue
    
    [self buildMetal];
    [self buildAssets];

    // The render method is invoked synchronously by a displayLink
    [self setupDisplayLink];
    
    [self reshape];
}

- (void) dealloc
{
    [self cleanup];
}

-(void)cleanup
{
    NSLog(@"MyMetalView::cleanup");
    
    // Release display link
    if (displayLink) {
        CVDisplayLinkStop(displayLink);
        CVDisplayLinkRelease(displayLink);
        displayLink = NULL;
    }
}



- (void)buildMetal
{
    NSLog(@"MyMetalView::buildDevice");
    
    // Create device
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        NSLog(@"Error: Unable to create metal default device");
        return;
    }
    
    // Create command queue
    _commandQueue = [_device newCommandQueue];

    // Load all shader files shipped with this project
    _library = [_device newDefaultLibrary];
 
    // Configure layer
    _metalLayer = (CAMetalLayer *)self.layer;
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;

    // View
    self.sampleCount = 1; // 4;
    // self.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
}

- (void)buildAssets
{
    // Vertex buffers
    _positionBuffer = [self buildVertexBuffer:_device];
    
    // Textures
    MTLTextureDescriptor *mtlTextDesc =
    [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                       width:512
                                                      height:512
                                                   mipmapped:NO];
    
    _texture = [_device newTextureWithDescriptor:mtlTextDesc];
    
    // Sampler
    MTLSamplerDescriptor *samplerDescriptor = [MTLSamplerDescriptor new];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
    
    samplerDescriptor.mipFilter = MTLSamplerMipFilterNotMipmapped;
    _sampler = [_device newSamplerStateWithDescriptor:samplerDescriptor];
    
    
    // Uniform buffers
    for (unsigned i = 0; i < noOfBuffers; i++) {
        _uniformBuffers[i] = [_device newBufferWithLength:sizeof(Uniforms) options:0];
    }
    
}

- (void)buildPipeline
{
    NSLog(@"MyMetalView::buildPipeline");

    id<MTLFunction> vertexFunc = [_library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [_library newFunctionWithName:@"fragment_main"];
    
    // Build vertex descriptor
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor new];
    // Positions
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    // Texture coordinates
    vertexDescriptor.attributes[1].format = MTLVertexFormatHalf2;
    vertexDescriptor.attributes[1].offset = 16;
    vertexDescriptor.attributes[1].bufferIndex = 1;
    // Single interleaved buffer
    vertexDescriptor.layouts[0].stride = 24;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    // Build render pipeline descriptor
    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.label = @"C64 metal pipeline";
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    
    // pipelineDescriptor.sampleCount = self.sampleCount;
    pipelineDescriptor.vertexFunction = vertexFunc;
    pipelineDescriptor.fragmentFunction = fragmentFunc;
    // pipelineDescriptor.vertexDescriptor = vertexDescriptor;
#if 0
    pipelineDescriptor.depthAttachmentPixelFormat = self.depthStencilPixelFormat;
    pipelineDescriptor.stencilAttachmentPixelFormat = self.depthStencilPixelFormat;
#endif
    
    
    MTLDepthStencilDescriptor *depthDescriptor = [MTLDepthStencilDescriptor new];
    depthDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthDescriptor.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthDescriptor];
    NSLog(@"_depthState = %@", _depthState);

    
    
    
    NSError *error = nil;
    _pipeline = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                        error:&error];
    
    if (!_pipeline)
    {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    
    // "A command queue is an object that keeps a list of render command buffers to be executed."
    _commandQueue = [_device newCommandQueue];
}

- (void)buildDepthBuffer
{
    CGSize drawableSize = self.drawableSize;
    MTLTextureDescriptor *depthTexDesc =
    [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                       width:drawableSize.width
                                                      height:drawableSize.height
                                                   mipmapped:NO];
    depthTexDesc.resourceOptions = MTLResourceStorageModePrivate;
    depthTexDesc.usage = MTLTextureUsageRenderTarget; 
    _depthTexture = [_device newTextureWithDescriptor:depthTexDesc];
}

- (void)setupDisplayLink
{
    NSLog(@"MyMetalView::setupDisplayLink");
    
    CVReturn success;

    // Create display link for the main display
    CVDisplayLinkCreateWithCGDisplay(kCGDirectMainDisplay, &displayLink);
    // checkForOpenGLErrors();

    if (!displayLink) {
        NSLog(@"Error: Can't create display link");
        exit(0);
    }
    
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

    NSLog(@"Display link up and running");
}


- (void)startFrame
{
    CGSize drawableSize = _metalLayer.drawableSize;
    
    if (!_depthTexture || _depthTexture.width != drawableSize.width || _depthTexture.height != drawableSize.height)
    {
        [self buildDepthBuffer];
    }

    
    _drawable = [_metalLayer nextDrawable];
    _framebufferTexture = _drawable.texture;
    
    if (!_framebufferTexture)
    {
        NSLog(@"Unable to retrieve texture; drawable may be nil");
        return;
    }
    
    if (_pipelineIsDirty)
    {
        [self buildPipeline];
        _pipelineIsDirty = NO;
    }

    /* "A render pass descriptor tells Metal what actions to take while an image is being rendered. At the beginning of the render pass, the loadAction determines whether the previous contents of the texture are cleared or retained. The storeAction determines what effect the rendering has on the texture: the results may either be stored or discarded. Since we want our pixels to wind up on the screen, we select our store action to be MTLStoreActionStore.
     The pass descriptor is also where we choose which color the screen will be cleared to
     before we draw any geometry. "
     */
    MTLRenderPassDescriptor *renderPass = [MTLRenderPassDescriptor renderPassDescriptor];
    renderPass.colorAttachments[0].texture = _framebufferTexture;
    renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);
    renderPass.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPass.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    renderPass.depthAttachment.texture = _depthTexture;
    renderPass.depthAttachment.clearDepth = 1;
    renderPass.depthAttachment.loadAction = MTLLoadActionClear;
    renderPass.depthAttachment.storeAction = MTLStoreActionDontCare;

    
    // "A command buffer represents a collection of render commands to be executed as a unit."
    _commandBuffer = [_commandQueue commandBuffer];
    
    /* "A command encoder is an object that is used to tell Metal what drawing we actually want to do. It is responsible for translating these high-level commands (set these shader parameters, draw these triangles, etc.) into low-level instructions that are then written into its corresponding command buffer. Once we have issued all of our draw calls (which we aren’t doing in this post), we send the endEncoding message to the command encoder so it has the chance to finish its encoding.
     */
    _commandEncoder = [_commandBuffer renderCommandEncoderWithDescriptor:renderPass];
    [_commandEncoder setRenderPipelineState:_pipeline];
    [_commandEncoder setDepthStencilState:_depthState];

    [_commandEncoder setFragmentTexture:_texture atIndex:0];
    [_commandEncoder setFragmentSamplerState:_sampler atIndex:0];
    
    // [_commandEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
    // [_commandEncoder setCullMode:MTLCullModeBack];
}
    
- (void)render
{    
    [_commandEncoder setVertexBuffer:_positionBuffer offset:0 atIndex:0];
    [_commandEncoder setVertexBuffer:_uniformBuffers[_bufferIndex] offset:0 atIndex:1];
    
    [_commandEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:36 instanceCount:1];
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


- (void)updateScreenGeometry
{
    if (c64->isPAL()) {
        // PAL border will be 36 pixels wide and 34 pixels heigh
        textureXStart = (float)(PAL_LEFT_BORDER_WIDTH - 36.0) / (float)TEXTURE_WIDTH;
        textureXEnd = (float)(PAL_LEFT_BORDER_WIDTH + PAL_CANVAS_WIDTH + 36.0) / (float)TEXTURE_WIDTH;
        textureYStart = (float)(PAL_UPPER_BORDER_HEIGHT - 34.0) / (float)TEXTURE_HEIGHT;
        textureYEnd = (float)(PAL_UPPER_BORDER_HEIGHT + PAL_CANVAS_HEIGHT + 34.0) / (float)TEXTURE_HEIGHT;
    } else {
        // NTSC border will be 42 pixels wide and 9 pixels heigh
        textureXStart = (float)(NTSC_LEFT_BORDER_WIDTH - 42.0) / (float)TEXTURE_WIDTH;
        textureXEnd = (float)(NTSC_LEFT_BORDER_WIDTH + NTSC_CANVAS_WIDTH + 42.0) / (float)TEXTURE_WIDTH;
        textureYStart = (float)(NTSC_UPPER_BORDER_HEIGHT - 9) / (float)TEXTURE_HEIGHT;
        textureYEnd = (float)(NTSC_UPPER_BORDER_HEIGHT + NTSC_CANVAS_HEIGHT + 9) / (float)TEXTURE_HEIGHT;
    }
    
    // Enable this for debugging (will display the whole texture)
    /*
     textureXStart = 0.0;
     textureXEnd = 1.0;
     textureYStart = 0.0;
     textureYEnd = 1.0;
     */
    
    _positionBuffer = [self buildVertexBuffer:_device];
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
    
    [_texture replaceRegion:MTLRegionMake2D(0,0,width,height)
           mipmapLevel:0 slice:0 withBytes:buf
           bytesPerRow:rowBytes bytesPerImage:imageBytes];
}

- (void)reshape {
    /*
     When reshape is called, update the view and projection matricies since
     this means the view orientation or size changed.
     */
    float aspect = fabs(self.bounds.size.width / self.bounds.size.height);
    _projectionMatrix = vc64_matrix_from_perspective_fov_aspectLH(65.0f * (M_PI / 180.0f), aspect, 0.1f, 100.0f);
    
    _viewMatrix = matrix_identity_float4x4;
}

- (void)updateAngles {
    
    Uniforms *frameData = (Uniforms *)[_uniformBuffers[_bufferIndex] contents];
    
    frameData->model =
    vc64_matrix_from_translation(0.0f, 0.0f, 2.0f) *
    vc64_matrix_from_rotation(_angle, 1.0f, 1.0f, 0.0f);
    frameData->view = _viewMatrix;
    
    matrix_float4x4 modelViewMatrix = frameData->view * frameData->model;
    
    frameData->projectionView = _projectionMatrix * modelViewMatrix;
    
    _angle += 0.05f;
}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
#if 0
    [self reshape];
#endif
}

- (void)drawInMTKView:(nonnull MTKView *)view {
#if 0
    @autoreleasepool {
        [self render];
    }
#endif
}


- (CVReturn)getFrameForTime:(const CVTimeStamp*)timeStamp flagsOut:(CVOptionFlags*)flagsOut
{
    @autoreleasepool {
        
        // Update angles for screen animation
        [self updateAngles];
        
        // Update texture
        [self updateTexture:_commandBuffer];
        
        // Draw scene
        [self startFrame];
        [self render];
        [self endFrame];
        
        return kCVReturnSuccess;
    }
}



@end
