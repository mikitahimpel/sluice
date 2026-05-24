import os
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

def create_sluice_icon(output_path):
    # Canvas properties
    width, height = 4096, 4096
    
    # ----------------------------------------------------
    # 1. GENERATE THE MAC OS SQUIRCLE MASK
    # ----------------------------------------------------
    print("Generating squircle mask...")
    x = np.linspace(-2048, 2048, width)
    y = np.linspace(-2048, 2048, height)
    X, Y = np.meshgrid(x, y)
    
    # Size 3296x3296 (824x824 at 1x)
    R = 1648
    n = 4.2
    
    # Calculate superellipse equation
    squircle_val = (np.abs(X/R)**n + np.abs(Y/R)**n)
    mask_np = squircle_val <= 1.0
    
    # Create Pillow mask
    mask_img = Image.fromarray((mask_np * 255).astype(np.uint8))
    
    # ----------------------------------------------------
    # 2. GENERATE GRADIENT BACKGROUND
    # ----------------------------------------------------
    print("Generating background gradient...")
    # Vertical gradient from Cyan (#22D3EE) to Deep Blue (#1E3A8A)
    c_top = np.array([34, 211, 238])    # #22D3EE
    c_bottom = np.array([30, 58, 138])  # #1E3A8A
    
    gradient_y = np.linspace(0, 1, height).reshape(height, 1)
    gradient_rgb = (1 - gradient_y) * c_top + gradient_y * c_bottom
    gradient_rgb = np.clip(gradient_rgb, 0, 255).astype(np.uint8)
    gradient_data = np.tile(gradient_rgb.reshape(height, 1, 3), (1, width, 1))
    background_img = Image.fromarray(gradient_data)
    
    # ----------------------------------------------------
    # 3. ADD SUBTLE DEPTH (LIGHTING & SHADOWS) TO SQUIRCLE
    # ----------------------------------------------------
    print("Applying squircle lighting effects...")
    # Inner border / bevel effect
    # We erode the squircle slightly to get a border mask
    R_eroded = R - 16 # 4px border at 1024x1024
    mask_eroded = (np.abs(X/R_eroded)**n + np.abs(Y/R_eroded)**n) <= 1.0
    border_mask = mask_np & ~mask_eroded
    
    # Create white top highlight border (semi-transparent white at top fading to transparent)
    border_highlight_data = np.zeros((height, width, 4), dtype=np.uint8)
    border_highlight_data[:, :, 0] = 255
    border_highlight_data[:, :, 1] = 255
    border_highlight_data[:, :, 2] = 255
    
    # Opacity of highlight: starts at 50% at top, fades to 0% at bottom
    opacity_y = (1.0 - gradient_y) * 0.5 * border_mask
    border_highlight_data[:, :, 3] = (opacity_y * 255).astype(np.uint8)
    border_highlight_img = Image.fromarray(border_highlight_data)
    
    # Create dark bottom shadow border (semi-transparent black at bottom fading to transparent)
    border_shadow_data = np.zeros((height, width, 4), dtype=np.uint8)
    # Opacity of shadow: starts at 30% at bottom, fades to 0% at top
    shadow_y = gradient_y * 0.3 * border_mask
    border_shadow_data[:, :, 3] = (shadow_y * 255).astype(np.uint8)
    border_shadow_img = Image.fromarray(border_shadow_data)
    
    # ----------------------------------------------------
    # 4. GENERATE THE WHITE GEOMETRIC MARK
    # ----------------------------------------------------
    print("Designing geometric Sluice (Y) mark...")
    # Let's draw the mark on a high-res mask
    mark_mask = Image.new('L', (width, height), 0)
    mark_draw = ImageDraw.Draw(mark_mask)
    
    # Line width
    W = 320
    # Branch length (from center of split to end of branch)
    L = 1000
    
    # Coordinate calculations for perfect geometric Y
    # Center of split
    cx, cy = 2048, 2048
    
    # 1. Stem: Rectangular bar from y=2048 to y=2900
    # Left: cx - W/2, Right: cx + W/2
    stem_poly = [
        (cx - W/2, cy),
        (cx + W/2, cy),
        (cx + W/2, 2900),
        (cx - W/2, 2900)
    ]
    
    # 2. Left Branch: Rotated at 45 degrees (pointing up-left)
    # Direction vector: (-cos(45), -sin(45)) = (-0.7071, -0.7071)
    # Perpendicular vector: (-0.7071, 0.7071)
    # We want a sharp join.
    # Centerline end:
    lx_end = cx - L * 0.7071
    ly_end = cy - L * 0.7071
    
    # Corners of left branch end:
    # Outer (bottom-left):
    lx_out = lx_end - (W/2) * 0.7071
    ly_out = ly_end + (W/2) * 0.7071
    # Inner (top-right):
    lx_in = lx_end + (W/2) * 0.7071
    ly_in = ly_end - (W/2) * 0.7071
    
    # 3. Right Branch: Rotated at 45 degrees (pointing up-right)
    # Direction vector: (0.7071, -0.7071)
    # Perpendicular vector: (0.7071, 0.7071)
    # Centerline end:
    rx_end = cx + L * 0.7071
    ry_end = cy - L * 0.7071
    
    # Corners of right branch end:
    # Inner (top-left):
    rx_in = rx_end - (W/2) * 0.7071
    ry_in = ry_end - (W/2) * 0.7071
    # Outer (bottom-right):
    rx_out = rx_end + (W/2) * 0.7071
    ry_out = ry_end + (W/2) * 0.7071
    
    # Join points:
    # Outer left join (stem meets left branch outer edge):
    # x = cx - W/2
    # y = cy + W * (1/sqrt(2) - 0.5)
    join_l_x = cx - W/2
    join_l_y = cy + W * (0.7071 - 0.5)
    
    # Outer right join:
    join_r_x = cx + W/2
    join_r_y = cy + W * (0.7071 - 0.5)
    
    # Inner V-split join (intersection of inner branch edges):
    # x = cx
    # y = cy - W / sqrt(2)
    join_v_x = cx
    join_v_y = cy - W * 0.7071
    
    # Let's define the single closed polygon for the Sluice Y mark
    y_polygon = [
        (cx - W/2, 2900), # 1. Bottom-left of stem
        (join_l_x, join_l_y), # 2. Left outer join
        (lx_out, ly_out), # 3. Left branch outer end
        (lx_in, ly_in), # 4. Left branch inner end
        (join_v_x, join_v_y), # 5. Inner V-split join
        (rx_in, ry_in), # 6. Right branch inner end
        (rx_out, ry_out), # 7. Right branch outer end
        (join_r_x, join_r_y), # 8. Right outer join
        (cx + W/2, 2900)  # 9. Bottom-right of stem
    ]
    
    # Draw the main white shape
    mark_draw.polygon(y_polygon, fill=255)
    
    # Create the white mark image with a very subtle vertical gradient (premium feel)
    # White to very light silver/gray (#FFFFFF to #EBF8FF)
    mark_gradient = np.zeros((height, width, 4), dtype=np.uint8)
    mark_gradient[:, :, 0] = 255
    mark_gradient[:, :, 1] = 255
    mark_gradient[:, :, 2] = 255
    
    # Opacity is determined by the mark mask
    mark_mask_np = np.array(mark_mask) / 255.0
    
    # Apply a subtle shading on the Y-mark (slightly darker at bottom)
    mark_shading = 1.0 - (gradient_y * 0.08)  # down to 92% brightness at bottom
    mark_alpha = mark_mask_np * 1.0  # Full opacity where mask is active
    
    mark_gradient[:, :, 0] = (mark_gradient[:, :, 0] * mark_shading).astype(np.uint8)
    mark_gradient[:, :, 1] = (mark_gradient[:, :, 1] * mark_shading).astype(np.uint8)
    mark_gradient[:, :, 2] = (mark_gradient[:, :, 2] * mark_shading).astype(np.uint8)
    mark_gradient[:, :, 3] = (mark_alpha * 255).astype(np.uint8)
    
    mark_img = Image.fromarray(mark_gradient)
    
    # ----------------------------------------------------
    # 5. GENERATE SOFT DROP SHADOW FOR THE Y MARK
    # ----------------------------------------------------
    print("Generating drop shadow for the Sluice mark...")
    # Shadow layer: black shape of the mark, blurred, offset downwards
    shadow_mask = Image.new('L', (width, height), 0)
    shadow_draw = ImageDraw.Draw(shadow_mask)
    shadow_draw.polygon(y_polygon, fill=255)
    
    # Offset shadow downwards by 32px (8px at 1x)
    shadow_offset = Image.new('L', (width, height), 0)
    shadow_offset.paste(shadow_mask, (0, 32))
    
    # Blur heavily: 48px blur (12px at 1x)
    shadow_blur = shadow_offset.filter(ImageFilter.GaussianBlur(radius=48))
    
    # Set color to black, opacity to 25%
    mark_shadow_data = np.zeros((height, width, 4), dtype=np.uint8)
    mark_shadow_np = np.array(shadow_blur) / 255.0
    mark_shadow_data[:, :, 3] = (mark_shadow_np * 0.25 * 255).astype(np.uint8)
    mark_shadow_img = Image.fromarray(mark_shadow_data)
    
    # ----------------------------------------------------
    # 6. ASSEMBLE THE SQUIRCLE LAYER
    # ----------------------------------------------------
    print("Assembling squircle layer...")
    squircle_canvas = background_img.convert('RGBA')
    
    # Layer highlights and shadows
    squircle_canvas = Image.alpha_composite(squircle_canvas, border_shadow_img)
    squircle_canvas = Image.alpha_composite(squircle_canvas, border_highlight_img)
    
    # Layer the Sluice mark shadow and then the mark itself
    squircle_canvas = Image.alpha_composite(squircle_canvas, mark_shadow_img)
    squircle_canvas = Image.alpha_composite(squircle_canvas, mark_img)
    
    # Apply the squircle mask to the squircle canvas to make the corners transparent
    final_squircle = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    final_squircle.paste(squircle_canvas, (0, 0), mask=mask_img)
    
    # ----------------------------------------------------
    # 7. GENERATE MAC OS CANVAS & SQUIRCLE DROP SHADOWS
    # ----------------------------------------------------
    print("Generating drop shadows for the squircle...")
    # The macOS app icon needs drop shadows on the main transparent canvas
    # Ambient shadow: very soft, offset down 40px, opacity 12%
    ambient_shadow_mask = mask_img.filter(ImageFilter.GaussianBlur(radius=96))
    ambient_shadow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    ambient_data = np.zeros((height, width, 4), dtype=np.uint8)
    ambient_data[:, :, 3] = (np.array(ambient_shadow_mask) * 0.12).astype(np.uint8)
    ambient_img = Image.fromarray(ambient_data)
    
    # Key shadow: slightly sharper, offset down 80px, opacity 24%
    key_shadow_mask = mask_img.filter(ImageFilter.GaussianBlur(radius=48))
    key_shadow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    key_data = np.zeros((height, width, 4), dtype=np.uint8)
    key_data[:, :, 3] = (np.array(key_shadow_mask) * 0.24).astype(np.uint8)
    key_img = Image.fromarray(key_data)
    
    # Assemble the final composite
    print("Compositing all layers...")
    final_canvas = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    
    # Paste shadows with offsets
    final_canvas.paste(ambient_img, (0, 40), mask=ambient_img.split()[3])
    final_canvas.paste(key_img, (0, 80), mask=key_img.split()[3])
    
    # Paste squircle in the center
    final_canvas.paste(final_squircle, (0, 0), mask=final_squircle.split()[3])
    
    # ----------------------------------------------------
    # 8. DOWNSAMPLE TO 1024x1024
    # ----------------------------------------------------
    print("Resizing to 1024x1024 with LANCZOS downsampling...")
    try:
        resample_filter = Image.Resampling.LANCZOS
    except AttributeError:
        try:
            resample_filter = Image.LANCZOS
        except AttributeError:
            resample_filter = Image.ANTIALIAS
            
    final_1024 = final_canvas.resize((1024, 1024), resample=resample_filter)
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Save as PNG
    print(f"Saving final PNG to {output_path}...")
    final_1024.save(output_path, "PNG")
    print("Icon generated successfully!")

if __name__ == "__main__":
    create_sluice_icon("/tmp/agy-sluice-icon.png")
