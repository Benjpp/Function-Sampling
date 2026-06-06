#ifndef ALGEBRAICSAMPLING3DPARALLEL_H
#define ALGEBRAICSAMPLING3DPARALLEL_H

#include "algebraicSampling2Dparallel.h"

typedef struct{
	float x;
	float y;
	float z;
} coordinate_3d;

typedef struct{
	float exponent;
	float coeficient;
	char variable;				// este char debe valor o bien 'y', o 'x'
} term;

typedef struct {
	term *function_terms;
	uint32_t terms_size;
	uint32_t lines_rate;
	uint32_t sample_rate;								
	float step;									// El step para las lineas individuales
	float lines_step;								// El step para cuantas lineas calcular por cada incremento de  
	uint32_t points;								// Cuantos puntos calcular en x e y, se sacara un trozo cuadrado de la superficie
} function_sample_3d;

typedef struct {
	coordinate_3d p1;
	coordinate_3d p2;
	coordinate_3d p3;
} triangle;

term *parse_args_3d(char *argv, uint32_t *list_size);

/**
 * Inicia el struct function_sample_3D para la dada expresion 3D. Los argumentos de entrada al programa dan en el orden: puntos a calcular, num de sub rectas, sample rate para las sub rectas. Dar *sample con memoria reservada ya
 */
void initialize_function_sample3d(term *term_list, uint32_t list_size, function_sample_3d *sample, char **argv);

triangle *sample_map_fused_parallel(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size); 

coordinate_3d *sample_function_3d_parallel(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size);

coordinate_3d **sample_function_3d(function_sample_3d *sample3d, uint32_t *outer_coordinate3d_size, uint32_t *inner_coordinate3d_size);

triangle *map_triangles_parallel(coordinate_3d *coords3d, function_sample_3d *sample, uint32_t outer_size, uint32_t inner_size);

triangle *map_triangles(coordinate_3d **coords3d, function_sample_3d *sample, uint32_t outer_size, uint32_t inner_size);

void print_term_list(term *term_list, uint32_t list_size);

#endif
