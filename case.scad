// ====================================================================
// ESP32-C3 Supermini 0.42" OLED Laptop-Style Snap-Fit Case
// Parametric OpenSCAD Model for 3D Printing (No Extra Hardware Needed)
// ====================================================================

/* [Render Selection] */
// Part to render: "assembly", "base", "lid"
render_part = "assembly"; 

/* [Main Dimensions] */
pcb_width = 18.4;       // ESP32-C3 PCB width (mm) + 0.4mm clearance
pcb_length = 24.0;      // ESP32-C3 PCB length (mm) + 0.5mm clearance
pcb_thickness = 1.6;    // PCB thickness (mm)
wall_thick = 2.0;       // Enclosure wall thickness (mm)
base_height = 8.5;      // Base chassis height (mm)

/* [Display Dimensions] */
oled_width = 13.6;      // OLED glass outer width (mm)
oled_height = 13.6;     // OLED glass outer height (mm)
screen_view_w = 15.0;   // Visible screen width cutout (mm)
screen_view_h = 9.0;    // Visible screen height cutout (mm)
lid_thickness = 4.0;    // Display lid frame thickness (mm)
tilt_angle = 65;        // Laptop screen tilt angle (degrees)

/* [USB-C Cutout] */
usb_width = 9.5;        // USB-C connector cutout width (mm)
usb_height = 4.2;       // USB-C connector cutout height (mm)

$fn = 40; // Smooth curves

// Derived parameters
outer_w = pcb_width + (wall_thick * 2);
outer_l = pcb_length + (wall_thick * 2);

// ====================================================================
// MODULES
// ====================================================================

// 1. ESP32-C3 Base Chassis (Laptop Body with Snap Hinge Sockets)
module base_unit() {
    difference() {
        union() {
            // Main outer box with rounded corners
            hull() {
                translate([wall_thick, wall_thick, 0])
                    cylinder(r=wall_thick, h=base_height);
                translate([outer_w - wall_thick, wall_thick, 0])
                    cylinder(r=wall_thick, h=base_height);
                translate([wall_thick, outer_l - wall_thick, 0])
                    cylinder(r=wall_thick, h=base_height);
                translate([outer_w - wall_thick, outer_l - wall_thick, 0])
                    cylinder(r=wall_thick, h=base_height);
            }
            
            // Left Snap Hinge Post
            translate([0, outer_l - 3, base_height]) {
                hull() {
                    cube([ wall_thick + 1, 3, 0.1 ]);
                    translate([0, 1.5, 2.5])
                        rotate([0, 90, 0])
                            cylinder(r=2.5, h=wall_thick + 1);
                }
            }
            
            // Right Snap Hinge Post
            translate([outer_w - (wall_thick + 1), outer_l - 3, base_height]) {
                hull() {
                    cube([ wall_thick + 1, 3, 0.1 ]);
                    translate([0, 1.5, 2.5])
                        rotate([0, 90, 0])
                            cylinder(r=2.5, h=wall_thick + 1);
                }
            }
        }
        
        // Inner cavity for PCB
        translate([wall_thick, wall_thick, wall_thick])
            cube([pcb_width, pcb_length, base_height + 5]);
            
        // USB-C Cutout at back
        translate([(outer_w - usb_width)/2, -1, wall_thick])
            cube([usb_width, wall_thick + 2, usb_height]);
            
        // Side ventilation & reset pin access slot
        translate([-1, outer_l/2 - 3, wall_thick + 1])
            cube([wall_thick + 2, 6, 3]);
            
        // Snap Hinge Sockets (Internal Sockets on Hinge Posts)
        // Left Socket
        translate([wall_thick + 1.1, outer_l - 1.5, base_height + 2.5])
            rotate([0, -90, 0])
                cylinder(r=1.6, h=2.5);
                
        // Right Socket
        translate([outer_w - (wall_thick + 1.1), outer_l - 1.5, base_height + 2.5])
            rotate([0, 90, 0])
                cylinder(r=1.6, h=2.5);
                
        // 65° Mechanical Stopper Cutout at rear
        translate([wall_thick, outer_l - 2, base_height - 1])
            rotate([tilt_angle - 90, 0, 0])
                cube([pcb_width, 5, 10]);
    }
    
    // Internal PCB support ledge / corner guide pins
    translate([wall_thick, wall_thick, 0]) {
        cylinder(r=1.2, h=wall_thick + 1.2);
        translate([pcb_width, 0, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
        translate([0, pcb_length, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
        translate([pcb_width, pcb_length, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
    }
}

// 2. Laptop Display Lid (Screen Bezel Frame with Snap-Fit Nubs)
module display_lid() {
    lid_w = outer_w;
    lid_l = oled_height + (wall_thick * 2) + 2;
    hinge_hub_w = pcb_width - 1.0; // Clearance for snap-fit
    
    union() {
        difference() {
            // Outer Lid Shell with bevels
            hull() {
                translate([wall_thick, wall_thick, 0])
                    cylinder(r=wall_thick, h=lid_thickness);
                translate([lid_w - wall_thick, wall_thick, 0])
                    cylinder(r=wall_thick, h=lid_thickness);
                translate([wall_thick, lid_l - wall_thick, 0])
                    cylinder(r=wall_thick, h=lid_thickness);
                translate([lid_w - wall_thick, lid_l - wall_thick, 0])
                    cylinder(r=wall_thick, h=lid_thickness);
            }
            
            // Front Viewport Bezel Cutout
            translate([(lid_w - screen_view_w)/2, (lid_l - screen_view_h)/2 + 1, -1])
                cube([screen_view_w, screen_view_h, lid_thickness + 2]);
                
            // Inner OLED Glass Pocket (Recessed)
            translate([(lid_w - oled_width)/2, (lid_l - oled_height)/2 + 1, 1.2])
                cube([oled_width, oled_height, lid_thickness]);
                
            // Cable Pass-through Slot at hinge bottom
            translate([(lid_w - 8)/2, -1, -1])
                cube([8, wall_thick + 3, lid_thickness + 2]);
        }
        
        // Hinge Barrel Hub at bottom edge of lid
        translate([(lid_w - hinge_hub_w)/2, 0, lid_thickness/2]) {
            rotate([0, 90, 0])
                cylinder(r=2.4, h=hinge_hub_w);
                
            // Left Snap Nub (Spherical/Chamfered Pin)
            translate([0, 0, 0])
                rotate([0, -90, 0])
                    cylinder(r1=1.45, r2=0.8, h=1.4);
                    
            // Right Snap Nub (Spherical/Chamfered Pin)
            translate([hinge_hub_w, 0, 0])
                rotate([0, 90, 0])
                    cylinder(r1=1.45, r2=0.8, h=1.4);
        }
    }
}

// ====================================================================
// RENDER SELECTION
// ====================================================================

if (render_part == "assembly") {
    // Render Complete Laptop Assembly View
    color("#2d3748") base_unit();
    
    // Position Lid snapped into the Hinge at tilt_angle
    translate([0, outer_l - 1.5, base_height + 2.5])
        rotate([90 - tilt_angle, 0, 0])
            translate([0, -0.5, -lid_thickness/2])
                color("#1a202c") display_lid();
                
} else if (render_part == "base") {
    // Render Base Unit for Printing
    base_unit();
    
} else if (render_part == "lid") {
    // Render Display Lid Flat for Printing
    display_lid();
}
