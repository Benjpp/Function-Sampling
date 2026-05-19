#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <stdio.h>
#include "algebraicSampling2D.h"

void write_coords_file(coordinate *coords, uint32_t size, char* filename) {
    mkdir("../results", 0777);

    char path[512];
    snprintf(path, sizeof(path), "../results/%s.txt", filename);

    FILE *file = fopen(path, "w");
    if (file == NULL) return;

    for (uint32_t i = 0; i < size; i++) {
        fprintf(file, "%f %f\n", coords[i].x, coords[i].y);
    }

    fclose(file);
}

int main(int argc, char **argv){
	if(argc != 5){
		printf("Uso del programa: %s <expresion monomial> <frecuencia muestreo> <x inicial> <numero puntos>\n", *argv);
		return 0;
	}
	uint32_t list_size;
	monomial_term *term_list = parse_args(argv[1], &list_size);
	print_monomial_list(term_list, list_size);

	function_sample *sample = (function_sample*)malloc(sizeof(function_sample));
	initialize_function_sample(term_list, list_size, sample, argv);
	print_function_sample(sample);
	coordinate *coords = sample_function_sequential(sample);
	print_coords(sample, coords);

	write_coords_file(coords, (sample->points) * (sample->sample_rate), argv[1]);
	free(coords);
	free(term_list);
	free(sample);
	return 0;
}
