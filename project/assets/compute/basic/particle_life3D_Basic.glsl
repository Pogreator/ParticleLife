#[compute]
#version 450

layout(set = 0, binding = 0, std430) restrict buffer Params {
    float boundry_x;
    float boundry_y;
    float boundry_z;
    float particle_amount;
    float attract_root;
    float max_dist;
    float friction_factor;
    float force_factor;
}
params;

layout(set = 0, binding = 1, std430) readonly buffer Globals {
    float dt;
}
global;

layout(set = 0, binding = 2, std430) buffer Position {
    vec3 data[];
}
pos;

layout(set = 0, binding = 3, std430) restrict buffer Velocity {
    vec3 data[];
}
vel;

layout(set = 0, binding = 4, std430) restrict buffer Type {
    int data[];
}
type;

layout(set = 0, binding = 5, std430) restrict buffer Attract {
    float data[];
}
attract_table;

layout(set = 0, binding = 6, std430) readonly buffer External_Forces {
    vec3 data[];
}
external_forces;

layout(rgba32f, binding = 9) uniform image2D particle_data;

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;


float force(float dist, float attraction){
    float beta = 0.3;
    if (dist < beta){ 
        return (dist/beta-1.); // Maths for retraction if too close
    }
    else if (beta < dist && dist < 1.0){ 
        return (attraction * (1.0 - abs(2.0*dist - 1.0 - beta) / (1.0 - beta))); // Some more math!
    }
    else {
        return 0.0;
    }
}

void main() {

    int id = int(gl_GlobalInvocationID.x); // Id is based on worker for X


    if (id >= int(params.particle_amount)) return;

    // Total forces for the current particle

    float total_force_x = 0.0;
    float total_force_y = 0.0;
    float total_force_z = 0.0;

    for (int k = 0; k < int(params.particle_amount); k++){

        if (id == k) continue;

        float attract = attract_table.data[(int(params.attract_root) * type.data[id]) + type.data[k]]; // Attraction value between particles 
        
        float distx = pos.data[k].x - pos.data[id].x; // Get the distance x and y, used later for resolving direction
        float disty = pos.data[k].y - pos.data[id].y;   
        float distz = pos.data[k].z - pos.data[id].z;

        float dist = sqrt(pow(distx,2) + pow(disty,2)+ pow(distz,2)); // Pythag, simple

        if (0.0 < dist && dist < params.max_dist){ 
            float attraction = force(dist/params.max_dist,attract);

            total_force_x += distx/dist*attraction; // Add to force based on the attraction index and distance
            total_force_y += disty/dist*attraction;
            total_force_z += distz/dist*attraction;
        }

    }
    
    total_force_x *= params.max_dist*params.force_factor;
    total_force_y *= params.max_dist*params.force_factor;
    total_force_z *= params.max_dist*params.force_factor;

    vel.data[id] *= params.friction_factor;

    vel.data[id].x += external_forces.data[0].x+total_force_x * global.dt;
    vel.data[id].y += external_forces.data[0].y+total_force_y * global.dt;
    vel.data[id].z += external_forces.data[0].z+total_force_z * global.dt;

    pos.data[id] += vel.data[id] * global.dt;

    // Check if in boundry ( Horrible way to do it )

    if (pos.data[id].x < 0.0){ vel.data[id].x = -vel.data[id].x; pos.data[id].x = 1.0; }
    if (pos.data[id].x > params.boundry_x){ vel.data[id].x = -vel.data[id].x; pos.data[id].x = params.boundry_x-1.0; }
    if (pos.data[id].y < 0.0){ vel.data[id].y = -vel.data[id].y; pos.data[id].y = 1.0; }
    if (pos.data[id].y > params.boundry_y){ pos.data[id].y = -vel.data[id].y; pos.data[id].y = params.boundry_y-1.0; }
    if (pos.data[id].z < 0.0){ vel.data[id].z = -vel.data[id].y; pos.data[id].z = 1.0; }
    if (pos.data[id].z > params.boundry_z){ pos.data[id].y = -vel.data[id].z; pos.data[id].z = params.boundry_z-1.0; }

    ivec2 pixel_pos = ivec2(id,0);

    // Store the data on to the particle_data image buffer

    imageStore(particle_data,pixel_pos,vec4(pos.data[id].x,pos.data[id].y,pos.data[id].z,float(type.data[id])));
}