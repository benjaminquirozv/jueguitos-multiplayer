shader_type canvas_item;

// Variables de diseño ajustables
uniform vec4 bg_color : source_color = vec4(0.01, 0.02, 0.05, 1.0); // Fondo súper oscuro
uniform float star_density : hint_range(0.0, 0.1) = 0.01; // Densidad de estrellas
uniform float resolution = 128.0; // Cuadrícula Pixel Art

// NUEVAS Variables de Parpadeo Independiente
uniform float parpadeo_velocidad : hint_range(0.0, 10.0) = 5.0; // Rapidez global
uniform float parpadeo_intensidad : hint_range(0.0, 1.0) = 0.7; // Cuánto se oscurecen (1.0 = casi desaparecen)

// Función clásica de ruido pseudoaleatorio 2D
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Una segunda función aleatoria levemente distinta para el desfase
float random_desfase(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(34.9898, 12.233))) * 23758.5453123);
}

void fragment() {
    // 1. Cuantizar UV para el efecto Pixel Art
    vec2 pixelated_uv = floor(UV * resolution);

    // 2. Generar la semilla de posición de estrella
    float rand_pos = random(pixelated_uv);

    // 3. Determinar el color final
    if (rand_pos < star_density) {
        // --- ES UNA ESTRELLA --- Lógica de Parpadeo Independiente
        
        // A. Generar desfase único para este píxel (reloj individual)
        // Usamos una semilla distinta (random_desfase) basada en la posición
        float desfase = random_desfase(pixelated_uv) * 20.0; // Multiplicador grande para buena variedad
        
        // B. Calcular la oscilación (sinoidal) usando el reloj local: (TIME + desfase)
        float oscilacion = sin(TIME * parpadeo_velocidad + desfase);
        
        // C. Normalizar oscilación: de rango [-1.0 a 1.0] a [0.0 a 1.0]
        float brillo_normalizado = (oscilacion + 1.0) / 2.0;
        
        // D. Aplicar intensidad: Usamos mix para que el brillo oscile
        // entre (1.0 - intensidad) y 1.0 (blanco puro)
        float brillo_final = mix(1.0 - parpadeo_intensidad, 1.0, brillo_normalizado);
        
        // Aplicar el color blanco con el brillo variable
        COLOR = vec4(vec3(brillo_final), 1.0);
        
    } else {
        // --- ESPACIO VACÍO ---
        COLOR = bg_color;
    }
}