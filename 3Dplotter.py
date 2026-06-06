import pygame
from pygame.locals import *
from OpenGL.GL import *
from OpenGL.GLU import *
import sys
import os
import numpy as np
import math

def load_coords_3d_vbo(filename):
    if not os.path.exists(filename):
        print(f"Error: {filename} no existe.")
        sys.exit()
        
    print("Cargando y procesando el archivo de texto...")
    try:
        points = np.loadtxt(filename, dtype=np.float32)
        if points.shape[1] > 3:
            points = points[:, :3]
    except Exception as e:
        print(f"Error al leer con numpy de golpe: {e}")
        print("Intentando parseo alternativo...")
        raw_list = []
        with open(filename, 'r') as f:
            for line in f:
                parts = line.split()
                if len(parts) >= 3:
                    try:
                        raw_list.append([float(parts[0]), float(parts[1]), float(parts[2])])
                    except ValueError:
                        continue
        points = np.array(raw_list, dtype=np.float32)

    return points

def get_center_and_scale_np(points):
    if points.size == 0:
        return (0, 0, 0), 1.0
        
    min_bounds = points.min(axis=0)
    max_bounds = points.max(axis=0)
    
    center = (min_bounds + max_bounds) / 2.0
    max_range = float(np.max(max_bounds - min_bounds))
    if max_range == 0: 
        max_range = 1.0
        
    return center, max_range

def init_opengl_3d(width, height):
    glClearColor(0.08, 0.08, 0.1, 1.0) 
    glEnable(GL_DEPTH_TEST) 
    
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    gluPerspective(45, (width / height), 0.1, 5000.0) 
    
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()

def draw_axes(scale):
    glLineWidth(2.5)
    length = scale * 0.8
    
    glBegin(GL_LINES)
    glColor3f(1.0, 0.0, 0.0)        # Eje x rojo 
    glVertex3f(0.0, 0.0, 0.0)   # Eje y verde 
    glVertex3f(length, 0.0, 0.0)    # Eje z azul
    
    glColor3f(0.0, 1.0, 0.0)
    glVertex3f(0.0, 0.0, 0.0)
    glVertex3f(0.0, length, 0.0)
    
    glColor3f(0.0, 0.3, 1.0)
    glVertex3f(0.0, 0.0, 0.0)
    glVertex3f(0.0, 0.0, length)
    glEnd()

def main():
    if len(sys.argv) < 2:
        print("Uso: python script.py datos_3d.txt")
        return

    filename = sys.argv[1]
    points = load_coords_3d_vbo(filename)
    num_puntos = points.shape[0]
    
    num_triangulos = num_puntos // 3
    print(f"Se han cargado un total de {num_puntos} vértices ({num_triangulos} triángulos).")

    if num_puntos == 0:
        print("Error: No se pudieron procesar puntos válidos.")
        return

    center, max_range = get_center_and_scale_np(points)
    print(f"Centro: X={center[0]:.2f}, Y={center[1]:.2f}, Z={center[2]:.2f} | Tamaño: {max_range:.2f}")

    pygame.init()
    display = (1000, 700)
    pygame.display.set_mode(display, DOUBLEBUF | OPENGL)
    pygame.display.set_caption("Visualizador 3D - Primera Persona (Controles Corregidos)")

    init_opengl_3d(display[0], display[1])

    vbo_id = glGenBuffers(1)
    glBindBuffer(GL_ARRAY_BUFFER, vbo_id)
    glBufferData(GL_ARRAY_BUFFER, points.nbytes, points, GL_STATIC_DRAW)
    glBindBuffer(GL_ARRAY_BUFFER, 0) 
    
    del points 

    glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
    glLineWidth(1.5) 

    zoom = 0.0
    rot_x = 0.0   
    rot_y = 0.0   
    pan_x = 0.0
    pan_y = 0.0
    
    left_mouse_down = False
    last_mouse_pos = (0, 0)

    clock = pygame.time.Clock()

    while True:
        clock.tick(60) 
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                glDeleteBuffers(1, [vbo_id]) 
                pygame.quit()
                sys.exit()
                
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1: 
                    left_mouse_down = True
                    last_mouse_pos = pygame.mouse.get_pos()
                    
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1: left_mouse_down = False
                
            elif event.type == pygame.MOUSEMOTION:
                mouse_pos = pygame.mouse.get_pos()
                dx = mouse_pos[0] - last_mouse_pos[0]
                dy = mouse_pos[1] - last_mouse_pos[1]
                
                if left_mouse_down:
                    rot_y += dx * 0.2
                    rot_x += dy * 0.2
                    rot_x = max(-89.0, min(89.0, rot_x))
                    
                last_mouse_pos = mouse_pos

        keys = pygame.key.get_pressed()
        velocidad = max_range * 0.002 

        rad_y = math.radians(rot_y)

        forward_x = math.sin(rad_y)
        forward_z = math.cos(rad_y)
        right_x = math.cos(rad_y)
        right_z = -math.sin(rad_y)

        if keys[K_w]:       
            pan_x -= forward_x * velocidad
            zoom  += forward_z * velocidad
        if keys[K_s]:       
            pan_x += forward_x * velocidad
            zoom  -= forward_z * velocidad
        if keys[K_a]:       
            pan_x += right_x * velocidad
            zoom  -= right_z * velocidad
        if keys[K_d]:       
            pan_x -= right_x * velocidad
            zoom  += right_z * velocidad
            
        if keys[K_SPACE]:   
            pan_y -= velocidad * 0.6
        if keys[K_LSHIFT]:  
            pan_y += velocidad * 0.6

        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
        glLoadIdentity()
        
        glRotatef(rot_x, 1.0, 0.0, 0.0) 
        glRotatef(rot_y, 0.0, 1.0, 0.0) 
        
        glTranslatef(pan_x, pan_y, zoom)   
        
        glTranslatef(-center[0], -center[1], -center[2])
        
        draw_axes(max_range)
        
        glColor3f(0.0, 1.0, 0.7) 
        
        glEnableClientState(GL_VERTEX_ARRAY)
        glBindBuffer(GL_ARRAY_BUFFER, vbo_id)
        glVertexPointer(3, GL_FLOAT, 0, None)
        
        glDrawArrays(GL_TRIANGLES, 0, num_puntos)
        
        glBindBuffer(GL_ARRAY_BUFFER, 0)
        glDisableClientState(GL_VERTEX_ARRAY)
        
        pygame.display.flip()

if __name__ == "__main__":
    main() 
