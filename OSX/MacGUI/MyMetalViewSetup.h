/*
 * (C) 2015 Dirk W. Hoffmann. All rights reserved.
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

#import "MyMetalView.h"

@interface MyMetalView(Setup)

- (void)setupMetal;
- (void)buildVertexBuffer;
- (void)buildDepthBuffer;

@end

// Matrix utilities
matrix_float4x4 vc64_matrix_identity();
matrix_float4x4 vc64_matrix_from_perspective_fov_aspectLH(const float fovY, const float aspect, const float nearZ, const float farZ);
matrix_float4x4 vc64_matrix_from_translation(float x, float y, float z);
matrix_float4x4 vc64_matrix_from_rotation(float radians, float x, float y, float z);

