#ifndef ALGEBRAICSAMPLING_H
#define ALGEBRAICSAMPLING_H

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <math.h>

#define BUFFER_SIZE 128 								// Tamaño para un bufer que recoge temporalmente tokens de una expresion. Ni de broma el token es mas largo que esto (mucho me parece ya)		
typedef struct {
	float coeficient;
	float exponent;	
} monomial_term;

typedef struct {
	float x;
	float y; 
} coordinate;

typedef struct {
	monomial_term *function_terms;
	uint32_t terms_size;
	uint32_t sample_rate;								// Cuantos puntos calcular por cada unidad de x
	float step;									// La inversa del sample_rate, para saber cuanto avanzar en cada muestreo
	int32_t start_x;								// En que punto de x empezar
	uint32_t points;								// Cuantos puntos calcular
} function_sample;

/**
 * Parsea el primer argumento de entrada, una expresion algebraica a una lista de terminos
 */
monomial_term* parse_args(char *arg1, uint32_t *list_size);

/**
 * Inicializa el struct function_sample antes de tomar muestras de la funcion dada. Importante que esta función sea la primera en ejecutarse antes de cualquier otra operación.
 * Argv se recibe incrementado a la posicion siguiente a la de la expresion monomial
 */
void initialize_function_sample(monomial_term *term_list, uint32_t list_size, function_sample *sample, char **argv);

/**
 * Imprimir de forma bonita una lista de terminos de un monomio
 */
void print_monomial_list(monomial_term *list, uint32_t size);

void print_function_sample(const function_sample *fs);

/**
 * Muestrea la funcion y obtiene los puntos definidos por el struct de function_sample
 */
coordinate* sample_function_sequential(function_sample *sample);

/**
 * Muestra la lista de coordenadas calculadas de la funcion
 */
void print_coords(function_sample *sample, coordinate *coords);

#endif
