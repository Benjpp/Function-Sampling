#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/time.h> 
#include <cuda_runtime.h> 
#include "../include/algebraicSampling3Dparallel.h"

void guardar_resultados_y_limpiar(const char *nombre_expresion, triangle *triangles, 
                                  coordinate_3d **coords, uint32_t outer_size, 
                                  uint32_t inner_size, term *term_list) {
    
    int tamano_ruta = 11 + strlen(nombre_expresion) + 1;
    char *ruta_completa = (char*)malloc(tamano_ruta);

    if (ruta_completa == NULL) {
        perror("Error al asignar memoria para la ruta");
        return;
    }

    snprintf(ruta_completa, tamano_ruta, "../results/%s.txt", nombre_expresion);

    FILE *fichero = fopen(ruta_completa, "w");
    if (fichero == NULL) {
        fprintf(stderr, "Error al crear el fichero en %s. Asegúrate de que la carpeta '../results' exista.\n", ruta_completa);
        free(ruta_completa);
        return;
    }
    free(ruta_completa);

    int total_triangulos = (outer_size - 1) * (inner_size - 1) * 2;
    for (int i = 0; i < total_triangulos; i++) {
        fprintf(fichero, "%f %f %f\n", triangles[i].p1.x, triangles[i].p1.y, triangles[i].p1.z);
        fprintf(fichero, "%f %f %f\n", triangles[i].p2.x, triangles[i].p2.y, triangles[i].p2.z);
        fprintf(fichero, "%f %f %f\n", triangles[i].p3.x, triangles[i].p3.y, triangles[i].p3.z);
    }
    fclose(fichero);

    free(triangles);
    if(coords != NULL){
        for (int i = 0; i < outer_size; i++) {
            free(coords[i]);
        }
        free(coords);
    }
    free(term_list);
}

int main(int argc, char **argv){
    // Ahora esperamos 8 argumentos en total debido al nuevo flag de optimización
    if(argc != 8){
        fprintf(stderr, "Uso del programa: %s <expresion> <numero de puntos> <num subrectas> <sample rate subrectas> <sample rate por linea> <mode> <opt_mode: normal|optimized>\n", argv[0]);
        return 1;
    }    

    uint32_t list_size = 0;
    term *term_list = parse_args_3d(argv[1], &list_size);
    if (term_list == NULL || list_size == 0) {
        fprintf(stderr, "Error crítico: El parser no devolvió términos válidos.\n");
        return 1;
    }
    
    function_sample_3d *sample3d = (function_sample_3d*)malloc(sizeof(function_sample_3d));
    initialize_function_sample3d(term_list, list_size, sample3d, argv);
    
    uint32_t outer_coordinate3d_size = 0, inner_coordinate3d_size = 0;
    coordinate_3d **coords = NULL;
    coordinate_3d *coords_parallel = NULL;
    triangle *triangles = NULL;

    const char *mode = argv[6];
    const char *opt_mode = argv[7];
    float tiempo_ms = 0.0f;

    if (strcmp(mode, "sec") == 0) {
        struct timeval start, end;
        gettimeofday(&start, NULL);

        coords = sample_function_3d(sample3d, &outer_coordinate3d_size, &inner_coordinate3d_size);
        triangles = map_triangles(coords, sample3d, outer_coordinate3d_size, inner_coordinate3d_size);
        
        gettimeofday(&end, NULL);
        tiempo_ms = (float)(end.tv_sec - start.tv_sec) * 1000.0f + (float)(end.tv_usec - start.tv_usec) / 1000.0f;

        guardar_resultados_y_limpiar(argv[1], triangles, coords, outer_coordinate3d_size, inner_coordinate3d_size, term_list);
    } 
    else if (strcmp(mode, "parallel") == 0) {
        cudaEvent_t start, stop;
        if (cudaEventCreate(&start) != cudaSuccess || cudaEventCreate(&stop) != cudaSuccess) {
            fprintf(stderr, "Error de CUDA al crear eventos.\n");
            free(term_list);
            free(sample3d);
            return 1;
        }

        if (strcmp(opt_mode, "normal") == 0) {
            cudaEventRecord(start);

            coords_parallel = sample_function_3d_parallel(sample3d, &outer_coordinate3d_size, &inner_coordinate3d_size);
            triangles = map_triangles_parallel(coords_parallel, sample3d, outer_coordinate3d_size, inner_coordinate3d_size);
            
            cudaEventRecord(stop);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&tiempo_ms, start, stop);

            guardar_resultados_y_limpiar(argv[1], triangles, NULL, outer_coordinate3d_size, inner_coordinate3d_size, term_list);
            if (coords_parallel != NULL) free(coords_parallel);

        } else if (strcmp(opt_mode, "optimized") == 0) {
            cudaEventRecord(start);

            // Versión unificada (Fused Kernel con Memoria Compartida)
            triangles = sample_map_fused_parallel(sample3d, &outer_coordinate3d_size, &inner_coordinate3d_size);
            
            cudaEventRecord(stop);
            cudaEventSynchronize(stop);
            cudaEventElapsedTime(&tiempo_ms, start, stop);

            // No se generan coords_parallel de forma aislada, pasamos NULL
            guardar_resultados_y_limpiar(argv[1], triangles, NULL, outer_coordinate3d_size, inner_coordinate3d_size, term_list);

        } else {
            fprintf(stderr, "Error: Modo de optimización '%s' no reconocido. Usa 'normal' o 'optimized'.\n", opt_mode);
            cudaEventDestroy(start);
            cudaEventDestroy(stop);
            free(term_list);
            free(sample3d);
            return 1;
        }

        cudaEventDestroy(start);
        cudaEventDestroy(stop);
    } 
    else {
        fprintf(stderr, "Error: Modo '%s' no reconocido. Usa 'sec' o 'parallel'.\n", mode);
        free(term_list);
        free(sample3d);
        return 1;
    }

    // Calcular el total de coordenadas calculadas en esta ejecución
    uint32_t total_coordenadas = outer_coordinate3d_size * inner_coordinate3d_size;

    // IMPRESIÓN LIMPIA DE DATOS (Única salida por stdout)
    printf("%u %f\n", total_coordenadas, tiempo_ms);

    free(sample3d);
    return tiempo_ms;
}
