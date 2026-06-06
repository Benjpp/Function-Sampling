#include "algebraicSampling2Dparallel.h"


// Devuelve el siguiente termino monomial parseado. Se deja el puntero de argumentos incrementado a la posicion del siguiente termino
monomial_term parse_next_arg(char *arg, int *increment) {
    monomial_term current_term = {0.0f, 0.0f};
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

    if (*arg == 'x') {
        arg++;
        current_term.exponent = 1.0f;

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
    }

    *increment = (int)(arg - start);
    return current_term;
}

monomial_term* parse_args(char *arg1, uint32_t *list_size){
	int term_list_length = 0;
	monomial_term *term_list = NULL;
	while(*arg1 != '\0'){
		int increment;
		monomial_term current_term = parse_next_arg(arg1, &increment);
		arg1 += increment;
		term_list = (monomial_term*)realloc(term_list, sizeof(monomial_term) * (term_list_length + 1));
		term_list[term_list_length] = current_term;
		term_list_length++;
	}
	*list_size = term_list_length;
	
	return term_list;		
}

void print_monomial_list(monomial_term *monomial_list, uint32_t list_size) {
    	printf("Se han parseado un total de %d terminos\n", list_size);
	for (uint32_t i = 0; i < list_size; i++) {
		float current_coeficient = monomial_list[i].coeficient;
		float current_exponent = monomial_list[i].exponent;

		printf("Termino %d parseado: ", i);

		if (current_coeficient == 0.0f) {
		    printf("0\n");
		    continue;
		}

		if (current_exponent == 0.0f) {
		    printf("%.2f", current_coeficient);
		} else if (current_exponent == 1.0f) {
		    if (current_coeficient == 1.0f) printf("x");
		    else if (current_coeficient == -1.0f) printf("-x");
		    else printf("%.2fx", current_coeficient);
		} else {
		    if (current_coeficient == 1.0f) printf("x^%.2f", current_exponent);
		    else if (current_coeficient == -1.0f) printf("-x^%.2f", current_exponent);
		    else printf("%.2fx^%.2f", current_coeficient, current_exponent);
		}

		printf("\n");
	}
}

//El *sample debe de ser un puntero valido ya iniciado con malloc
//Primero se implemento cogiendo de los argumentos, asi que al usar con otra funcion, pasar en un array de strings en este orden ["", "", rate_string, start_x_string, points_val_string] 
void initialize_function_sample(monomial_term *term_list, uint32_t terms_length, function_sample *sample, const char **argv) {
	argv++; argv++;
	int32_t rate = strtol(argv[0], NULL, 10);
	int32_t start_x = (int32_t)strtol(argv[1], NULL, 10);
    	uint32_t points_val = (uint32_t)strtoul(argv[2], NULL, 10);

    	sample->function_terms = term_list;
   	sample->terms_size = terms_length;
    	sample->sample_rate = rate;
	sample->start_x = start_x;   
	sample->points = points_val;
    
    	if (rate > 0) {
        	sample->step = 1.0f / rate;
    	} else {
        	sample->step = 0.0f;
		printf("Se ha dado un step de 0, no se podra calcular nada\n");
    	}
}

void print_function_sample(const function_sample *fs) {
    if (fs == NULL) {
        printf("Error: Estructura no inicializada.\n");
        return;
    }

    printf("\n--- DATOS DE LA FUNCION ---\n");
    
    // Puntero y tamaño
    printf("Direccion Memoria : %p\n", (void*)fs->function_terms);
    printf("Numero Terminos  : %u\n",  fs->terms_size);
    
    // Muestreo
    printf("Sample Rate      : %u pts/u\n", fs->sample_rate);
    printf("Paso (Step)      : %f\n",     fs->step);
    
    // Rango
    printf("X inicial        : %d\n",     fs->start_x);
    printf("Total puntos     : %u\n",     fs->points);
    
    // Un pequeño extra para ver el final del rango
    uint32_t end_x = fs->start_x + fs->points;
    printf("Rango x          : [%d -> %d]\n", fs->start_x, end_x);
    
    printf("---------------------------\n\n");
}

coordinate* sample_function_sequential(function_sample *sample){
	uint32_t total_coords = (sample->points) * (sample->sample_rate);	
	size_t tamanyo_lista_coordenadas = (size_t)(sizeof(coordinate) * total_coords);
	coordinate *coords = (coordinate*)malloc(tamanyo_lista_coordenadas);
	if(coords == NULL){
		printf("Fallo en maloc para coords\n");
		return NULL;
	}

	if(sample == NULL){
		printf("Se ha pasado un puntero sample nulo\n");
		return NULL;
	}
	float x = sample->start_x;
	for(uint32_t pos = 0; pos < total_coords; pos++){
		// Aplicamos la x para la lista de terminos
		float y = 0.0f;
		monomial_term *term_list = sample->function_terms;
		for(uint32_t terms_pos = 0; terms_pos < sample->terms_size; terms_pos++){
			float coeficient = term_list[terms_pos].coeficient;
			float exponent = term_list[terms_pos].exponent;
			float eval_x = powf(x, exponent);
			y += coeficient * eval_x;
		}
		coords[pos].x = x;
		coords[pos].y = y;
		x += sample->step;
	}

	return coords;
}

const uint32_t BLOCK_SIZE = 16;

__device__ coordinate compute_coordinate2d(float x, monomial_term *terms, uint32_t terms_size){
	float y = 0.0f;
	for(int i = 0; i < terms_size; i++){
		float coeficient = terms[i].coeficient;
		float exponent = terms[i].exponent;
		float eval_x =powf(x, exponent);
		y += eval_x * coeficient;
	}

	return (coordinate){x, y};
}

__global__ void compute_coords(function_sample *sample, coordinate *coords){
	uint32_t total_coords = sample->points * sample->sample_rate;
	uint32_t idx = blockIdx.x * blockDim.x + threadIdx.x;
	float x = sample->start_x + idx * sample->step;
	if(idx < total_coords){
		coords[idx] = compute_coordinate2d(x, sample->function_terms, sample->terms_size);
	}
}

coordinate* sample_function_parallel(function_sample *sample){
	uint32_t total_coords = (sample->points) * (sample->sample_rate);	
	size_t tamanyo_lista_coordenadas = (size_t)(sizeof(coordinate) * total_coords);
	coordinate *coords = (coordinate*)malloc(tamanyo_lista_coordenadas);
	
	function_sample *gpuSample;
	monomial_term *gpuTerms;
	coordinate *gpuCoords;
	cudaMalloc((void**)&gpuSample, sizeof(function_sample));
	cudaMalloc((void**)&gpuTerms, sizeof(monomial_term) * sample->terms_size);
	cudaMalloc((void**)&gpuCoords, sizeof(coordinate) * total_coords);

	cudaMemcpy(gpuSample, sample, sizeof(function_sample), cudaMemcpyHostToDevice);
	cudaMemcpy(gpuTerms, sample->function_terms, sizeof(monomial_term) * sample->terms_size, cudaMemcpyHostToDevice);
	cudaMemcpy(&(gpuSample->function_terms), &gpuTerms, sizeof(monomial_term*), cudaMemcpyHostToDevice);
	// Lanzamos el kernel
	uint32_t block = BLOCK_SIZE * BLOCK_SIZE;
	uint32_t grids = (total_coords + block - 1) / block;
	compute_coords<<<grids, block>>>(gpuSample, gpuCoords);
	
	// Copiamos datos de vuelta
	cudaMemcpy(coords, gpuCoords, sizeof(coordinate) * total_coords, cudaMemcpyDeviceToHost);
	return coords;
}

void print_coords(function_sample *sample, coordinate *coords){
    if (coords == NULL) {
        printf("Error: No hay coordenadas para imprimir.\n");
        return;
    }

    printf("\n--- Muestreo de la Función ---\n");
    printf("| %-4s | %-10s | %-10s |\n", "ID", "X", "Y");
    printf("|------|------------|------------|\n");

    for (uint32_t i = 0; i < sample->points * sample->sample_rate; i++) {
        printf("| %-4u | %10.4f | %10.4f |\n", i, coords[i].x, coords[i].y);
    }
    printf("------------------------------\n");
    printf("Total puntos: %u\n", sample->points * sample->sample_rate);
}


