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

layout(set = 0, binding = 2, std430) readonly buffer Position {
    vec2 data[];
}
pos;

layout(set = 0, binding = 7, std430) buffer Spatial {
    ivec3 data[];
}
spatial;


layout(set = 0, binding = 8, std430) buffer StartIndicies {
    int data[];
}
start_indicies;

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

const int hashk1 = 15823;
const int hashk2 = 9737333;

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

void updateSpacial(vec2 position){
    int id = int(gl_GlobalInvocationID.x);

    if (id >= int(params.particle_amount)) return;

    ivec2 cell = getCell(position);
    int hash = hashCell(cell.x,cell.y);
    int key = keyHash(hash);

    spatial.data[id] = ivec3(id, hash, key);

}   

void bitonicSort(){

    barrier();
    
    int id = int(gl_LocalInvocationID.x);

    if (id >= int(params.particle_amount)) return;

    for (int k = 2; k <= int(params.particle_amount); k <<= 1) {
        for (int j = k >> 1; j > 0; j >>= 1) {
            int ixj = id ^ j;
            if (ixj > id) {
                bool dir = ((id & k) == 0u);
                int val1 = spatial.data[id].z;
                int val2 = spatial.data[ixj].z;
                if ((val1 > val2) == dir) {
                    spatial.data[id] = spatial.data[ixj];
                    spatial.data[ixj] = spatial.data[id];
                }
            }
            barrier();
        }
    }
}  

void generateStart(){

    barrier();

    int id = int(gl_LocalInvocationID.x);

    int id_left = (id-1) % int(params.particle_amount);
    int id_right = (id+1) % int(params.particle_amount);

    int current_key = spatial.data[id].z;

    if (current_key == spatial.data[id_right].z && spatial.data[id_left].z != current_key){
        start_indicies.data[current_key*2] = current_key;
        start_indicies.data[(current_key*2)+1] = id;
    } else if (spatial.data[id_left].z != current_key && current_key != spatial.data[id_right].z && spatial.data[id_left].z != spatial.data[id_right].z){
        start_indicies.data[current_key*2] = current_key;
        start_indicies.data[(current_key*2)+1] = id;
    }
}

void main(){ 
    int id = int(gl_GlobalInvocationID.x);

    if (id >= int(params.particle_amount)) return;

    updateSpacial(pos.data[id]);
    bitonicSort();
    generateStart();
}