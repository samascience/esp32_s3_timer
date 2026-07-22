// ====================================================================
// ESP32-C3 0.42" OLED Ultra-Simple Support-Free Desktop Stand
// Designed for 100% Support-Free Printing & Fast 15-Min Print Time
// ====================================================================

/* [Render Selection] */
// Select part to render: "stand" (Single-piece stand), "bezel" (Front cover)
render_part = "stand";

/* [Dimensions] */
pcb_w = 18.4;       // ESP32 PCB width (mm) + clearance
pcb_l = 24.0;      // ESP32 PCB length (mm) + clearance
pcb_t = 1.6;       // PCB thickness (mm)
wall  = 2.0;       // Wall thickness (mm)
slant = 60;        // Display viewing angle (degrees)

// Viewport cutout dimensions for 0.42" OLED
view_w = 15.0;
view_h = 9.0;

$fn = 30; // Smoothness

// ====================================================================
// 1-PIECE SUPPORT-FREE SLANTED DESKTOP STAND
// ====================================================================
module simple_stand() {
    outer_w = pcb_w + (wall * 2);
    outer_d = 28.0;
    height  = 26.0;
    
    difference() {
        // Main Wedge Body (Flat bottom, angled front face)
        hull() {
            // Flat Bottom Base
            cube([outer_w, outer_d, 2]);
            
            // Top Rear Ridge
            translate([0, outer_d - wall, height - wall])
                cube([outer_w, wall, wall]);
        }
        
        // Slanted Front Pocket for ESP32 + Screen
        translate([wall, wall, wall])
            rotate([90 - slant, 0, 0])
                cube([pcb_w, 40, pcb_t + 5]);
                
        // Screen Viewport Window Cutout (Front)
        translate([(outer_w - view_w)/2, 0, 10])
            rotate([90 - slant, 0, 0])
                translate([0, 0, -5])
                    cube([view_w, view_h, 15]);
                    
        // Rear USB-C Cable Access Port
        translate([(outer_w - 10)/2, outer_d - 5, -1])
            cube([10, 10, 8]);
            
        // Finger Push Hole at bottom to easily remove board
        translate([outer_w/2, 10, -1])
            cylinder(r=4, h=10);
    }
}

// ====================================================================
// FRONT CLIP BEZEL (OPTIONAL SNAP FRAME)
// ====================================================================
module front_bezel() {
    outer_w = pcb_w + (wall * 2);
    height = 20.0;
    
    difference() {
        cube([outer_w, height, 1.6]);
        
        // Center Viewport Cutout
        translate([(outer_w - view_w)/2, (height - view_h)/2, -1])
            cube([view_w, view_h, 4]);
    }
}

// ====================================================================
// RENDER SELECTION
// ====================================================================
if (render_part == "stand") {
    simple_stand();
} else if (render_part == "bezel") {
    front_bezel();
}
