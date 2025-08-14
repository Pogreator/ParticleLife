#[compute]
#version 450

layout(set = 0, binding = 0, std430) readonly buffer Params {
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

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

shared ivec3 local_value[gl_WorkGroupSize.x];
const int hashk1 = 15823;
const int hashk2 = 12582917;

ivec2 getCell(vec2 position){
    return ivec2(floor(position/params.max_dist));
}

int hashCell(int cell_x, int cell_y){
   int hash = (cell_x*hashk1*hashk2) + (cell_y*hashk1*hashk2);
   return hash;
}

int keyHash(int hash){
    int key = hash % 100;
    return key;
}

void updateSpacial(){
    int id = int(gl_GlobalInvocationID.x);
    int spatial_id = spatial.data[id].x;

    if (id < int(params.particle_amount)) return;

    barrier();

    ivec2 cell = getCell(pos.data[spatial_id]);
    int hash = hashCell(cell.x,cell.y);
    int key = keyHash(hash);

    spatial.data[id] = ivec3(spatial_id, hash, key);

}   

void local_compare_and_swap(ivec2 idx){
	if (local_value[idx.x].z >= local_value[idx.y].z) {
		ivec3 tmp = local_value[idx.x];
		local_value[idx.x] = local_value[idx.y];
		local_value[idx.y] = tmp;
	}
}

void do_flip(int h){
	int t = int(gl_GlobalInvocationID.x);
	int q = ((2 * t) / h) * h;
    int half_h = h / 2;
	ivec2 indices = q + ivec2(t % half_h, h - (t % half_h) - 1);
	local_compare_and_swap(indices);
}

void do_disperse(int h){
	int t = int(gl_GlobalInvocationID.x);
	int q = ((2 * t) / h) * h;
    int half_h = h / 2;
	ivec2 indices = q + ivec2(t % half_h, (t % half_h) + half_h);
	local_compare_and_swap(indices);
}

void bitonicSort(){

    int id = int(gl_GlobalInvocationID.x);
    
    if (id >= int(params.particle_amount/2)) return;
    
	local_value[id*2]   = spatial.data[id*2];
	local_value[(id*2)+1] = spatial.data[(id*2)+1];
 
 	int n = int(params.particle_amount);

	for ( int h = 2; h <= n; h *= 2 ) {
        memoryBarrierShared();
        barrier();
		do_flip(h);
		for ( int hh = h / 2; hh > 1 ; hh /= 2 ) {
            memoryBarrierShared();
			barrier();
			do_disperse(hh);
		}
	}

	spatial.data[id*2]   = local_value[id*2];
	spatial.data[(id*2)+1] = local_value[(id*2)+1];

}  

void generateStart(){

    int id = int(gl_GlobalInvocationID.x);
    int n = int(params.particle_amount)-1;

    int id_left = clamp(id-1,0,n);
    int id_right = clamp(id+1,0,n);

    int current_key = spatial.data[id].z;

    if (id == 0){
        start_indicies.data[0] = 0;
        start_indicies.data[1] = 0;
    }
    else if (spatial.data[id_left].z != current_key){
        start_indicies.data[current_key*2] = current_key;
        start_indicies.data[(current_key*2)+1] = id;
    } 
    barrier();
}

void main(){ 
    int id = int(gl_GlobalInvocationID.x);

    if (id < int(params.particle_amount)) return;
    
    updateSpacial();
    bitonicSort();
    generateStart();
}
