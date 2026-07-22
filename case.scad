// ====================================================================
// ESP32-C3 Supermini 0.42" OLED Laptop-Style Case
// Parametric OpenSCAD Model for 3D Printing
// ====================================================================

/* [Render Selection] */
// Part to render: "assembly", "base", "lid", "hinge"
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

$fn = 40; // Cylinder smoothness

// ====================================================================
// MODULES
// ====================================================================

// 1. ESP32-C3 Base Chassis (Laptop Keyboard Body)
module base_unit() {
    outer_w = pcb_width + (wall_thick * 2);
    outer_l = pcb_length + (wall_thick * 2);
    
    difference() {
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
        
        // Inner cavity for PCB
        translate([wall_thick, wall_thick, wall_thick])
            cube([pcb_width, pcb_length, base_height]);
            
        // USB-C Cutout at back
        translate([(outer_w - usb_width)/2, -1, wall_thick])
            cube([usb_width, wall_thick + 2, usb_height]);
            
        // Side ventilation & reset pin access slot
        translate([-1, outer_l/2 - 3, wall_thick + 1])
            cube([wall_thick + 2, 6, 3]);
    }
    
    // Internal PCB support ledge / corner guide pins
    translate([wall_thick, wall_thick, 0]) {
        cylinder(r=1.2, h=wall_thick + 1.2);
        translate([pcb_width, 0, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
        translate([0, pcb_length, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
        translate([pcb_width, pcb_length, 0]) cylinder(r=1.2, h=wall_thick + 1.2);
    }
    
    // Hinge Mounting Knuckles at rear edge
    translate([wall_thick, outer_l, base_height - 2.5]) {
        rotate([0, 90, 0])
            cylinder(r=3.0, h=3);
        translate([pcb_width - 3, 0, 0])
            rotate([0, 90, 0])
                cylinder(r=3.0, h=3);
    }
}

// 2. Laptop Display Lid (Screen Bezel Frame)
module display_lid() {
    lid_w = pcb_width + (wall_thick * 2);
    lid_l = oled_height + (wall_thick * 2) + 4;
    
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
        translate([(lid_w - screen_view_w)/2, (lid_l - screen_view_h)/2 + 2, -1])
            cube([screen_view_w, screen_view_h, lid_thickness + 2]);
            
        // Inner OLED Glass Pocket (Recessed)
        translate([(lid_w - oled_width)/2, (lid_l - oled_height)/2 + 2, 1.2])
            cube([oled_width, oled_height, lid_thickness]);
            
        // Cable Pass-through Slot at hinge bottom
        translate([(lid_w - 8)/2, -1, -1])
            cube([8, wall_thick + 3, lid_thickness + 2]);
    }
    
    // Center Hinge Mounting Knuckle
    translate([lid_w/2 - 2.5, 0, lid_thickness/2]) {
        rotate([0, 90, 0])
            cylinder(r=2.8, h=5);
    }
}

// 3. Hinge Pivot Pin
module hinge_pin() {
    cylinder(r=1.3, h=pcb_width + 4);
}

// ====================================================================
// RENDER SELECTION
// ====================================================================

if (render_part == "assembly") {
    // Render Complete Laptop Assembly View
    color("#2d3748") base_unit();
    
    // Position Lid at Hinge Angle
    translate([0, pcb_length + (wall_thick * 2), base_height - 2.5])
        rotate([-tilt_angle, 0, 0])
            translate([0, 0, -lid_thickness/2])
                color("#1a202c") display_lid();
                
} else if (render_part == "base") {
    // Render Base Unit for Printing
    base_unit();
    
} else if (render_part == "lid") {
    // Render Display Lid Flat for Printing
    display_lid();
    
} else if (render_part == "hinge") {
    // Render Hinge Pin
    hinge_pin();
}
