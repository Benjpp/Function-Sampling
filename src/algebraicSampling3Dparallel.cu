#include "algebraicSampling3Dparallel.h"

const int BLOCK_SIZE = 16;

// Devuelve el siguiente termino monomial parseado. Se deja el puntero de argumentos incrementado a la posicion del siguiente termino
term parse_next_arg3d(char *arg, int *increment) {
    term current_term = {0.0f, 0.0f, ' '};
    char *start = arg;
    char *endptr;

    float signo = 1.0f;
    if (*arg == '-') {
        signo = -1.0f;
        arg++;
    } else if (*arg == '+') {
        arg++;
    }

    float val = strtof(arg, &endptr);
    if (arg == endptr) {
        current_term.coeficient = 1.0f * signo;
    } else {
        current_term.coeficient = val * signo;
        arg = endptr;
    }

    if (*arg == 'x' || *arg == 'y') {
	current_term.variable = *arg;
        current_term.exponent = 1.0f;
	arg++;
        if (*arg == '^') {
            arg++;
            val = strtof(arg, &endptr);
            if (arg != endptr) {
                current_term.exponent = val;
                arg = endptr;
            }
        }
    } else {
        current_term.exponent = 0.0f;
	current_term.variable = '-';
    }

    *increment = (int)(arg - start);
    return current_term;
}

term* parse_args_3d(char *arg1, uint32_t *list_size){
	int term_list_length = 0;
	term *term_list = NULL;
	while(*arg1 != '\0'){
		int increment;
		term current_term = parse_next_arg3d(arg1, &increment);
		arg1 += increment;
		term_list = (term*)realloc(term_list, sizeof(term) * (term_list_length + 1));
		term_list[term_list_length] = current_term;
		term_list_length++;
	}
	*list_size = term_list_length;
	
	return term_list;		
}

void print_term_list(term *term_list, uint32_t list_size) {
    	printf("Se han parseado un total de %d terminos\n", list_size);
	for (uint32_t i = 0; i < list_size; i++) {
		float current_coeficient = term_list[i].coeficient;
		float current_exponent = term_list[i].exponent;
		char current_variable = term_list[i].variable;
		printf("Termino %d parseado: ", i);

		if (current_coeficient == 0.0f) {
		    printf("0\n");
		    continue;
		}

		if (current_exponent == 0.0f) {
		    printf("%.2f", current_coeficient);
		} else if (current_exponent == 1.0f) {
		    if (current_coeficient == 1.0f) printf("%c", current_variable);
		    else if (current_coeficient == -1.0f) printf("-%c", current_variable);
		    else printf("%.2fx", current_coeficient);
		} else {
		    if (current_coeficient == 1.0f) printf("x^%.2f", current_exponent);
		    else if (current_coeficient == -1.0f) printf("-x^%.2f", current_exponent);
		    else printf("%.2fx^%.2f", current_coeficient, current_exponent);
		}

		printf("\n");
	}
}

/*
typedef struct {
	term *function_terms;
	uint32_t terms_size;
	uint32_t lines_rate;
	uint32_t sample_rate;											
	float lines_step;								// El step para cuantas lineas calcular por cada incremento de  
	uint32_t points;								// Cuantos puntos calcular en x e y, se sacara un trozo cuadrado de la superficie
} function_sample_3D;
*/
void initialize_function_sample3d(term *term_list, uint32_t list_size, function_sample_3d *sample, char **argv){
	argv++; argv++;
	int32_t points_val = strtol(argv[0], NULL, 10);
	int32_t num_lines = (int32_t)strtol(argv[1], NULL, 10);
    	uint32_t lines_rate = (uint32_t)strtoul(argv[2], NULL, 10);
	uint32_t sample_rate = (uint32_t)strtoul(argv[3], NULL, 10);

    	sample->function_terms = term_list;
   	sample->terms_size = list_size;
    	sample->sample_rate = sample_rate;
	sample->lines_rate = lines_rate; 
	sample->points = points_val;
    
    	if (lines_rate > 0) {
        	sample->lines_step = 1.0f / lines_rate;
    	} else {
        	sample->step = 0.0f;
		printf("Se ha dado un step de 0, no se podra calcular nada\n");
    	}
}

// Helper que calcula una sub linea, es decir obtiene la expresion monomial evaluando todos los terminos y para el valor dado
monomial_term *get_monomial_terms(function_sample_3d *sample3d, float y){
	term *terms_list = sample3d->function_terms;
	monomial_term *monomial_terms = (monomial_term*)malloc(sizeof(monomial_term) * sample3d->terms_size);
	for(uint32_t i = 0; i < sample3d->terms_size; i++){
		if(terms_list[i].variable == 'x'){
			monomial_terms[i].coeficient = terms_list[i].coeficient;
			monomial_terms[i].exponent = terms_list[i].exponent;
		}else{
			// La variable es y porque asi usaremos el programa
			monomial_terms[i].exponent = 0;
			float y_evaluated = powf(y, terms_list[i].exponent);
			monomial_terms[i].coeficient = y_evaluated * terms_list[i].coeficient;
		}
	}

	return monomial_terms;
}
/*
typedef struct{
	float exponent;
	float coeficient;
	char variable;				// este char debe valor o bien 'y', o 'x'
} term;
*/
coordinate_3d* sample_2d_coords(coordinate *coords2d, function_sample_3d *sample, uint32_t coords2d_size){
	term *terms = sample->function_terms;
	coordinate_3d *coords3d = (coordinate_3d*)malloc(sizeof(coordinate_3d) * coords2d_size);
	for(int i = 0; i < coords2d_size; i++){
		float z = 0.0f;
		for(int j = 0; j < sample->terms_size; j++){
			if(terms[j].variable == 'x'){
				float coeficient = terms[j].coeficient;
				float exponent = terms[j].exponent;
				float eval_x = powf(coords2d[i].x, exponent);
				z += eval_x * coeficient;
			}else if(terms[j].variable == 'y'){
				float coeficient = terms[j].coeficient;
				float exponent = terms[j].exponent;
				float eval_y = powf(coords2d[i].y, exponent);
				z += eval_y * coeficient;
			}else{
				z += terms[j].coeficient;
			}	
		}
		coords3d[i] = (coordinate_3d){coords2d[i].x, coords2d[i].y, z};
	}

	return coords3d;
}

__device__ float evaluate_term_3d(term t, float x, float y) {
    if (t.variable == 'x') {
        return t.coeficient * powf(x, t.exponent);
    } else if (t.variable == 'y') {
        return t.coeficient * powf(y, t.exponent);
    }
    return 0.0f;
}

__global__ void sample_map_fused_kernel(term *d_terms, uint32_t terms_size,
                                         float lines_step, float step, float start_x, float start_y,
                                         uint32_t total_lines, uint32_t total_lines_coords,
                                         triangle *d_out_triangles) {
    
    // Matriz de memoria compartida con una celda extra para evitar desbordamientos
    __shared__ coordinate_3d s_coords[BLOCK_SIZE + 1][BLOCK_SIZE + 1];

    uint32_t tx = threadIdx.x;
    uint32_t ty = threadIdx.y;
    uint32_t j = blockIdx.x * blockDim.x + tx; 
    uint32_t i = blockIdx.y * blockDim.y + ty; 

    // Los hilos del bloque principal calculan su coordenada asignada
    if (i < total_lines && j < total_lines_coords) {
        float current_y = start_y + (float)i * lines_step;
        float current_x = start_x + (float)j * step;
        float current_z = 0.0f;

        for (uint32_t t = 0; t < terms_size; t++) {
            current_z += evaluate_term_3d(d_terms[t], current_x, current_y);
        }
        s_coords[ty][tx] = (coordinate_3d){current_x, current_y, current_z};
    }

    // Hilos del borde derecho calculan la columna extra para cerrar la rejilla
    if (tx == BLOCK_SIZE - 1 && (j + 1) < total_lines_coords && i < total_lines) {
        float current_y = start_y + (float)i * lines_step;
        float current_x = start_x + (float)(j + 1) * step;
        float current_z = 0.0f;
        for (uint32_t t = 0; t < terms_size; t++) {
            current_z += evaluate_term_3d(d_terms[t], current_x, current_y);
        }
        s_coords[ty][BLOCK_SIZE] = (coordinate_3d){current_x, current_y, current_z};
    }

    // Hilos del borde inferior calculan la fila extra para cerrar la rejilla
    if (ty == BLOCK_SIZE - 1 && (i + 1) < total_lines && j < total_lines_coords) {
        float current_y = start_y + (float)(i + 1) * lines_step;
        float current_x = start_x + (float)j * step;
        float current_z = 0.0f;
        for (uint32_t t = 0; t < terms_size; t++) {
            current_z += evaluate_term_3d(d_terms[t], current_x, current_y);
        }
        s_coords[BLOCK_SIZE][tx] = (coordinate_3d){current_x, current_y, current_z};
    }

    // La esquina inferior derecha calcula el último vértice del bloque geométrico
    if (tx == BLOCK_SIZE - 1 && ty == BLOCK_SIZE - 1 && (j + 1) < total_lines_coords && (i + 1) < total_lines) {
        float current_y = start_y + (float)(i + 1) * lines_step;
        float current_x = start_x + (float)(j + 1) * step;
        float current_z = 0.0f;
        for (uint32_t t = 0; t < terms_size; t++) {
            current_z += evaluate_term_3d(d_terms[t], current_x, current_y);
        }
        s_coords[BLOCK_SIZE][BLOCK_SIZE] = (coordinate_3d){current_x, current_y, current_z};
    }
    
    // Sincronización crucial para garantizar que toda la rejilla local está calculada
    __syncthreads();

    if (i < total_lines - 1 && j < total_lines_coords - 1) {
        coordinate_3d A = s_coords[ty][tx];          
        coordinate_3d B = s_coords[ty][tx + 1];      
        coordinate_3d C = s_coords[ty + 1][tx];      
        coordinate_3d D = s_coords[ty + 1][tx + 1];  

        // Índice base secuencial de la pareja de triángulos para este hilo específico
        uint32_t triangle_base_idx = (i * (total_lines_coords - 1) + j) * 2;

        // Volcado directo estructurado usando los nombres de variables p1, p2 y p3
        
        // Triángulo 1 (A -> B -> C)
        d_out_triangles[triangle_base_idx].p1 = A;
        d_out_triangles[triangle_base_idx].p2 = B;
        d_out_triangles[triangle_base_idx].p3 = C;

        // Triángulo 2 (C -> B -> D)
        d_out_triangles[triangle_base_idx + 1].p1 = C;
        d_out_triangles[triangle_base_idx + 1].p2 = B;
        d_out_triangles[triangle_base_idx + 1].p3 = D;
    }
}

triangle *sample_map_fused_parallel(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size) {
    
    uint32_t total_lines = sample3d->lines_rate * sample3d->points;
    uint32_t total_lines_coords = sample3d->sample_rate * sample3d->points;
    uint32_t triangles_size = (total_lines - 1) * (total_lines_coords - 1) * 2;

    *outer_coordinate3d_size = total_lines;
    *inner_coordinate3d_size = total_lines_coords;

    float pts = (float)sample3d->points;
    float start_y = (sample3d->points % 2 == 0) ? (0.0f - pts / 2.0f) : (0.0f - (pts - 1.0f) / 2.0f);
    float start_x = start_y; 

    float l_step = sample3d->lines_step;
    float h_step = sample3d->step;

    if (l_step == 0.0f && total_lines > 1) {
        l_step = (pts / (float)total_lines);
    }
    if (h_step == 0.0f && total_lines_coords > 1) {
        h_step = 1.0f / (float)sample3d->sample_rate;
    }

    term *d_terms;
    triangle *d_triangles;

    cudaMalloc((void**)&d_terms, sizeof(term) * sample3d->terms_size);
    cudaMalloc((void**)&d_triangles, sizeof(triangle) * triangles_size);

    cudaMemcpy(d_terms, sample3d->function_terms, sizeof(term) * sample3d->terms_size, cudaMemcpyHostToDevice);
    
    dim3 block_size(BLOCK_SIZE, BLOCK_SIZE);
    dim3 grid_size(
        (total_lines_coords + block_size.x - 1) / block_size.x,
        (total_lines + block_size.y - 1) / block_size.y
    );

    sample_map_fused_kernel<<<grid_size, block_size>>>(
        d_terms, sample3d->terms_size, l_step, h_step, 
        start_x, start_y, total_lines, total_lines_coords, d_triangles
    );
    cudaDeviceSynchronize();

    triangle *h_triangles = (triangle*)malloc(sizeof(triangle) * triangles_size);
    cudaMemcpy(h_triangles, d_triangles, sizeof(triangle) * triangles_size, cudaMemcpyDeviceToHost);

    cudaFree(d_terms);
    cudaFree(d_triangles);

    return h_triangles;
}

__global__ void sample_3d_kernel(term *d_terms, uint32_t terms_size,
                                 float lines_step, float step, float start_x, float start_y,
                                 uint32_t total_lines, uint32_t total_lines_coords,
                                 coordinate_3d *d_out_coords) {

    uint32_t j = blockIdx.x * blockDim.x + threadIdx.x; 
    uint32_t i = blockIdx.y * blockDim.y + threadIdx.y; 

    if (i < total_lines && j < total_lines_coords) {
        float current_y = start_y + (float)i * lines_step;
        float current_x = start_x + (float)j * step;

        float current_z = 0.0f;
        for (uint32_t term_it = 0; term_it < terms_size; term_it++) {
            current_z += evaluate_term_3d(d_terms[term_it], current_x, current_y);
        }

        uint32_t global_idx = i * total_lines_coords + j;
        d_out_coords[global_idx] = (coordinate_3d){current_x, current_y, current_z};
    }
}

__global__ void sample_3d_kernel_optimized(term *d_terms, uint32_t terms_size,
                                 float lines_step, float step, float start_x, float start_y,
                                 uint32_t total_lines, uint32_t total_lines_coords,
                                 coordinate_3d *d_out_coords){
	__shared__ coordinate_3d s_coords[BLOCK_SIZE][BLOCK_SIZE];
	// Indice global
	uint32_t j = blockIdx.x * blockDim.x + threadIdx.x; 
	uint32_t i = blockIdx.y * blockDim.y + threadIdx.y; 

	//Indice local
	uint32_t tx = threadIdx.x;
	uint32_t ty =threadIdx.y;

	if(i < total_lines && j < total_lines_coords){
		
	}
}

coordinate_3d *sample_function_3d_parallel(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size) {
    
    uint32_t total_lines = sample3d->lines_rate * sample3d->points;
    uint32_t total_lines_coords = sample3d->sample_rate * sample3d->points;
    uint32_t total_coords = total_lines * total_lines_coords;

    *outer_coordinate3d_size = total_lines;
    *inner_coordinate3d_size = total_lines_coords;

    float pts = (float)sample3d->points;
    float start_y = (sample3d->points % 2 == 0) ? (0.0f - pts / 2.0f) : (0.0f - (pts - 1.0f) / 2.0f);
    float start_x = start_y; 

    float l_step = sample3d->lines_step;
    float h_step = sample3d->step;

    if (l_step == 0.0f && total_lines > 1) {
        l_step = (pts / (float)total_lines);
    }
    if (h_step == 0.0f && total_lines_coords > 1) {
        h_step = 1.0f / (float)sample3d->sample_rate;
    }

    term *d_terms;
    coordinate_3d *d_coords;
    cudaMalloc((void**)&d_terms, sizeof(term) * sample3d->terms_size);
    cudaMalloc((void**)&d_coords, sizeof(coordinate_3d) * total_coords);

    cudaMemcpy(d_terms, sample3d->function_terms, sizeof(term) * sample3d->terms_size, cudaMemcpyHostToDevice);
    
    dim3 block_size(16, 16);
    dim3 grid_size(
        (total_lines_coords + block_size.x - 1) / block_size.x,
        (total_lines + block_size.y - 1) / block_size.y
    );

    sample_3d_kernel<<<grid_size, block_size>>>(
        d_terms, sample3d->terms_size, l_step, h_step, 
        start_x, start_y, total_lines, total_lines_coords, d_coords
    );
    cudaDeviceSynchronize();

    coordinate_3d *h_linear_coords = (coordinate_3d*)malloc(sizeof(coordinate_3d) * total_coords);
    cudaMemcpy(h_linear_coords, d_coords, sizeof(coordinate_3d) * total_coords, cudaMemcpyDeviceToHost);

    cudaFree(d_terms);
    cudaFree(d_coords);

    return h_linear_coords;
}

coordinate_3d **sample_function_3d(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size){
    uint32_t total_lines = sample3d->lines_rate * sample3d->points;
    uint32_t total_lines_coords = sample3d->sample_rate * sample3d->points;

    *outer_coordinate3d_size = total_lines;
    *inner_coordinate3d_size = total_lines_coords;

    float pts = (float)sample3d->points;
    float start_y = (sample3d->points % 2 == 0) ? (0.0f - pts / 2.0f) : (0.0f - (pts - 1.0f) / 2.0f);
    float start_x = start_y;

    // Calculamos los steps exactamente igual que en la versión paralela
    float l_step = sample3d->lines_step;
    float h_step = sample3d->step;
    if (l_step == 0.0f && total_lines > 1) l_step = (pts / (float)total_lines);
    if (h_step == 0.0f && total_lines_coords > 1) h_step = 1.0f / (float)sample3d->sample_rate;

    coordinate_3d **coords3d = (coordinate_3d**)malloc(sizeof(coordinate_3d*) * total_lines);

    for(uint32_t i = 0; i < total_lines; i++){
        coords3d[i] = (coordinate_3d*)malloc(sizeof(coordinate_3d) * total_lines_coords);
        float current_y = start_y + (float)i * l_step;

        for(uint32_t j = 0; j < total_lines_coords; j++){
            float current_x = start_x + (float)j * h_step;
            float current_z = 0.0f;

            // Evaluamos los términos en CPU de forma idéntica al dispositivo
            for (uint32_t t = 0; t < sample3d->terms_size; t++) {
                term term_actual = sample3d->function_terms[t];
                if (term_actual.variable == 'x') {
                    current_z += term_actual.coeficient * powf(current_x, term_actual.exponent);
                } else if (term_actual.variable == 'y') {
                    current_z += term_actual.coeficient * powf(current_y, term_actual.exponent);
                } else if (term_actual.variable == '-') { // Constante
                    current_z += term_actual.coeficient;
                }
            }
            coords3d[i][j] = (coordinate_3d){current_x, current_y, current_z};
        }
    }

    return coords3d;
}

__global__ void map_triangles_kernel(coordinate_3d *d_coords, uint32_t outer_size, 
                                     uint32_t inner_size, triangle *d_triangles) {
    
    uint32_t i = blockIdx.y * blockDim.y + threadIdx.y;
    uint32_t j = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < outer_size - 1 && j < inner_size - 1) {
        uint32_t idx_A = i * inner_size + j;
        uint32_t idx_B = i * inner_size + (j + 1);
        uint32_t idx_C = (i + 1) * inner_size + j;
        uint32_t idx_D = (i + 1) * inner_size + (j + 1);

        coordinate_3d A = d_coords[idx_A];
        coordinate_3d B = d_coords[idx_B];
        coordinate_3d C = d_coords[idx_C];
        coordinate_3d D = d_coords[idx_D];

        uint32_t triangle_base_idx = (i * (inner_size - 1) + j) * 2;

        d_triangles[triangle_base_idx]     = (triangle){A, B, C};
        d_triangles[triangle_base_idx + 1] = (triangle){C, B, D};
    }
}

triangle *map_triangles_parallel(coordinate_3d *coords3d, function_sample_3d *sample, 
                                 uint32_t outer_size, uint32_t inner_size) {
    
    uint32_t total_coords = outer_size * inner_size;
    uint32_t triangles_size = (outer_size - 1) * (inner_size - 1) * 2;

    coordinate_3d *d_coords;
    triangle *d_triangles;
    cudaMalloc((void**)&d_coords, sizeof(coordinate_3d) * total_coords);
    cudaMalloc((void**)&d_triangles, sizeof(triangle) * triangles_size);

    cudaMemcpy(d_coords, coords3d, sizeof(coordinate_3d) * total_coords, cudaMemcpyHostToDevice);

    dim3 block_size(16, 16);
    dim3 grid_size(
        (inner_size + block_size.x - 1) / block_size.x,
        (outer_size + block_size.y - 1) / block_size.y
    );

    map_triangles_kernel<<<grid_size, block_size>>>(d_coords, outer_size, inner_size, d_triangles);
    cudaDeviceSynchronize();

    triangle *triangles = (triangle*)malloc(sizeof(triangle) * triangles_size);
    cudaMemcpy(triangles, d_triangles, sizeof(triangle) * triangles_size, cudaMemcpyDeviceToHost);

    cudaFree(d_coords);
    cudaFree(d_triangles);

    return triangles;
}

triangle *map_triangles(coordinate_3d **coords3d, function_sample_3d *sample, uint32_t outer_size, uint32_t inner_size){
	/*
	 * A	C	Cada 4 puntos, dos en cada linea contiguos, forma un triangulo
	 *
	 * B	D
	 *
	 */
	uint32_t triangles_size = (outer_size - 1) * (inner_size - 1) * 2;
	triangle *triangles = (triangle*)malloc(sizeof(triangle) * triangles_size);
	uint32_t triangles_it = 0;
	for(int i = 0; i < outer_size - 1; i++){
		for(int j = 0; j < inner_size - 1; j++){
			coordinate_3d A = coords3d[i][j];
			coordinate_3d B = coords3d[i][j+1];
			coordinate_3d C = coords3d[i+1][j];
			coordinate_3d D = coords3d[i+1][j+1];

			triangles[triangles_it] = (triangle){A, B, C};
			triangles_it++;

			triangles[triangles_it] = (triangle){C, B, D};
			triangles_it++;
		}
	}

	return triangles;
}
