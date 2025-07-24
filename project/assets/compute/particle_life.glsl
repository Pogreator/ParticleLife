#[compute]
#version 450

layout(set = 0, binding = 0, std430) restrict buffer Params {
    float boundry_x;
    float boundry_y;
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
    vec2 data[];
}
pos;

layout(set = 0, binding = 3, std430) restrict buffer Velocity {
    vec2 data[];
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

layout(set = 0, binding = 7, std430) buffer Spatial {
    ivec3 data[];
}
spatial;


layout(set = 0, binding = 8, std430) buffer StartIndicies {
    int data[];
}
start_indicies;

layout(rgba32f, binding = 9) uniform image2D particle_data;

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

const int hashk1 = 15823;
const int hashk2 = 9737333;

const ivec2 offsets2D[9] =
{
	ivec2(-1, 1),
	ivec2(0, 1),
	ivec2(1, 1),
	ivec2(-1, 0),
	ivec2(0, 0),
	ivec2(1, 0),
	ivec2(-1, -1),
	ivec2(0, -1),
	ivec2(1, -1),
};

ivec2 getCell(vec2 position){
    return ivec2(floor(position/params.max_dist));
}

int hashCell(int cell_x, int cell_y){ 
   int hash = (cell_x*hashk1) + (cell_y*hashk2);
   return hash;
}

int keyHash(int hash){
    int key = hash % 10;
    return key;
}

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

ivec2 search_Start(int value){
    int array_end = int(params.particle_amount)-1;
    
    int value_start = start_indicies.data[(value*2)+1];

    if (value < 9){ 
        array_end = start_indicies.data[(value*2)+3];
    }

    return ivec2(value_start,array_end);
}

void main() {

    int id = int(gl_GlobalInvocationID.x); // Id is based on worker for X


    if (id >= int(params.particle_amount)) return;

    // Total forces for the current particle

    float total_force_x = 0.0;
    float total_force_y = 0.0;

    ivec2 own_cell = getCell(pos.data[id]);

    for (int i = 0; i < 9; i++){
        int neighbour_x = own_cell.x + offsets2D[i].x;
        int neighbour_y = own_cell.y + offsets2D[i].y;

        int hash = hashCell(neighbour_x,neighbour_y);
        int key = keyHash(hash);

        ivec2 spatial_lookup = search_Start(key);

        int k = spatial_lookup.x;

        while (k < spatial_lookup.y){

            k++;

            int kid = int(spatial.data[k].x);

            if (id == kid) continue;

            float attract = attract_table.data[(int(params.attract_root) * type.data[id]) + type.data[kid]]; // Attraction value between particles 
            
            float distx = pos.data[kid].x - pos.data[id].x; // Get the distance x and y, used later for resolving direction
            float disty = pos.data[kid].y - pos.data[id].y;   

            float dist = sqrt(pow(distx,2) + pow(disty,2)); // Pythag, simple

            if (0.0 < dist && dist < params.max_dist){ 
                float attraction = force(dist/params.max_dist,attract);

                total_force_x += distx/dist*attraction; // Add to force based on the attraction index and distance
                total_force_y += disty/dist*attraction;
            }

        }

    }
    
    total_force_x *= params.max_dist*params.force_factor;
    total_force_y *= params.max_dist*params.force_factor;

    vel.data[id] *= params.friction_factor;

    vel.data[id].x += total_force_x * global.dt;
    vel.data[id].y += total_force_y * global.dt;

    pos.data[id] += vel.data[id] * global.dt;

    // Check if in boundry ( Horrible way to do it )

    if (pos.data[id].x < 0.0){ vel.data[id].x = -vel.data[id].x; pos.data[id].x = 1.0; }
    else if (pos.data[id].x > params.boundry_x){ vel.data[id].x = -vel.data[id].x; pos.data[id].x = params.boundry_x-1.0; }
    else if (pos.data[id].y < 0.0){ vel.data[id].y = -vel.data[id].y; pos.data[id].y = 1.0; }
    else if (pos.data[id].y > params.boundry_y){ pos.data[id].y = -vel.data[id].y; pos.data[id].y = params.boundry_y-1.0; }

    ivec2 pixel_pos = ivec2(id,0);

    // Store the data on to the particle_data image buffer

    imageStore(particle_data,pixel_pos,vec4(pos.data[id].x,pos.data[id].y,float(type.data[id]),0.0));
}