# Workoutes para Android

Aplicación nativa en Kotlin y Jetpack Compose con Material 3. Abrir **esta carpeta Android** como proyecto en Android Studio. El proyecto iOS continúa en `../Workoutes`.

## Ejecutar

Requiere JDK 17, Android SDK 35 y Build Tools 35.0.0. Android Studio puede preparar el SDK al sincronizar el proyecto. Compatible con Android 8.0 (API 26) y superiores.

```sh
./gradlew :app:assembleDebug
./gradlew :app:installDebug
```

APK de desarrollo: `app/build/outputs/apk/debug/app-debug.apk`. La publicación en Google Play requiere configurar una firma de distribución propia.

## Funciones

- Cuatro pestañas: Summary, Workouts, Exercises y Settings, con títulos grandes, sombras sutiles en las tarjetas y una barra inferior flotante en forma de cápsula. El contenido se desplaza por detrás y tiene espacio al final para evitar que los controles lo oculten.
- Summary semanal de lunes a domingo, con navegación a semanas anteriores y sin acceso al futuro: bloques por ejercicio completado con los colores de sus etiquetas actuales, total de ejercicios y días activos. Tocar o mantener un bloque abre una vista de solo lectura de los valores guardados al completar. Tirar hacia abajo desde el inicio revela una frase y un emoji motivacionales, con vibración y una celebración de tres segundos.
- Rutinas con ejercicios compartidos; creación automática desde etiquetas; agregar ejercicios existentes y quitar de una rutina sin borrarlos de la biblioteca.
- Crear y editar ejercicios, etiquetas, colores e iconos musculares. Rueda de selección única, con giro, menú de gestión y arrastre del centro para anclarla a cualquiera de los cuatro bordes; posición persistente y selección inmediata desde el menú.
- Peso, series y repeticiones editables desde cada tarjeta. Pesos guardados siempre en kg y visualizados en kg o lb.
- Un solo ejercicio activo, con sesión persistente y temporizador. Detener después de más de 10 segundos completa y registra el ejercicio; 10 segundos o menos cancela el intento. Cambiar de ejercicio cancela la sesión anterior. Restablecer completados conserva el historial.
- Bump mediante deslizamiento hacia la derecha o menú. El menú se abre manteniendo presionada la tarjeta y permite editar, quitar de una rutina y borrar permanentemente con confirmación.
- Fondos independientes para cada rutina y para la biblioteca: degradados de uno a tres colores, colores de etiquetas, fotos y cámara externa nativa. Las fotos se reducen y guardan dentro de la app.
- Siete temas y modo oscuro del sistema: Violet Aura, Electric Rush, Sunset Pop, Ultravolt, Cobalt Heat, Cherry Ice y Midnight Gold. Los temas retirados migran a Violet Aura. Fondos atmosféricos estáticos de tres colores con el grano PNG de iOS, sin contornos en los contenedores. Los temas se eligen en un carrusel centrado con vistas previas y actualizan el icono adaptativo de la app. Theme, unidades e importación se abren como submenús con botón Back.
- Navegación con transición horizontal al entrar y volver de una rutina o submenú; fondos con transición suave entre colores e imágenes. La selección de la barra inferior engloba icono y texto sin cambiar el tamaño de los elementos.
- Importar JSON mediante el selector de archivos; exportar catálogo o catálogo con historial mediante el panel nativo para compartir. Incluye el prompt para convertir rutinas de texto a JSON.
- Acceso persistente al ejercicio activo junto a la barra inferior: abre Exercises, conserva filtros compatibles o elimina los incompatibles, desplaza hasta la tarjeta y la resalta brevemente. Está deshabilitado sin sesión. Notificación con temporizador, Stop y Bump, métricas, notas, etiquetas y miniatura muscular; tocarla revela la tarjeta. Android 13+ solicita permiso al iniciar un ejercicio; el control de sesión en la tarjeta funciona aunque se deniegue el permiso. Las acciones antiguas no pueden modificar una sesión posterior.

## Datos y compatibilidad con iOS

El formato exportado mantiene los arrays `workouts`, `exercises` y `tags`, con relaciones `{ "id": "…" }` y los mismos campos del proyecto Swift. Los pesos exportados están en kilogramos. Se puede exportar en iOS e importar en Android, y viceversa. Las etiquetas pueden incluir `iconName`. El historial opcional usa `history` con `id`, `completedAt` en ISO 8601, `exerciseID` nullable y `snapshot` opcional. Los snapshots conservan los detalles y etiquetas originales aunque el catálogo se edite o borre; los registros antiguos muestran “No Historical Snapshot”. Settings → Exercise History permite eliminar entradas individualmente o en grupo sin modificar los ejercicios.

La importación **actualiza por ID**. Importar el mismo archivo dos veces no crea duplicados. Los registros existentes de historial son inmutables y no se borran al importar catálogo solamente. El archivo se valida completo antes de guardar. Un formato inválido no modifica los datos existentes. Los JSON anteriores sin historial siguen siendo compatibles.

Los fondos, preferencias y la sesión activa se guardan localmente; no forman parte del JSON de intercambio, igual que los ajustes de iOS. La persistencia usa un archivo JSON con escrituras atómicas, protegido por un mutex y publicado a la interfaz mediante StateFlow. Los datos de versiones Android anteriores se conservan sin inventar historial. No necesita una cuenta ni un servidor.

## Adaptaciones de plataforma

Material 3 sustituye Liquid Glass. Los editores usan hojas inferiores, campos y controles de Android; los colores permiten seleccionar una muestra o escribir un HEX. Los formularios conservan su contenido al recrear la actividad.

La actividad de iOS se adapta a una notificación estándar persistente y al acceso al ejercicio activo dentro de la app. Apple Watch y HealthKit quedan fuera de esta versión. No se reproduce Dynamic Island ni se solicita promoción a Live Updates. No hay un servicio en primer plano: el ejercicio activo no necesita ejecutar un temporizador o trabajo continuo. Las acciones de la notificación cargan los datos guardados incluso si el proceso fue cerrado. El sistema y el usuario controlan la visibilidad de las notificaciones.

Las fotos usan Photo Picker y la cámara usa una aplicación de cámara instalada. No se piden permisos generales de almacenamiento ni acceso directo a la cámara. La captura real requiere un dispositivo con una app de cámara disponible.

## Verificación

```sh
./gradlew :app:testDebugUnitTest :app:lintDebug
# Con un dispositivo o emulador conectado:
./gradlew :app:connectedDebugAndroidTest
```

Las pruebas de lógica cubren unidades, umbral estricto de duración, restauración de sesiones, acciones antiguas, historial después de borrar/restablecer, relaciones, auto-población, JSON compatible con iOS, importaciones repetidas, temas y semanas con cambios de zona horaria/horario de verano. Las pruebas de Compose cubren creación, edición de peso, pestañas, restauración de formularios y sesiones, filtros, submenús, geometría de la barra, transición de rutinas, notificaciones, Summary, importación/exportación, gesto motivacional, carrusel e icono del launcher.

Verificado en un emulador Android 15 (API 35): 29 pruebas unitarias y 11 flujos de interfaz, además de cuatro verificaciones con tema oscuro y texto al 150 %. Queda pendiente la revisión en un teléfono físico de cámara, Photo Picker, compartir y el selector de documentos. Android Lint no reporta errores; informa de versiones más recientes de algunas dependencias y de tres rutas largas de los vectores anatómicos originales. Las versiones están fijadas para conservar una compilación reproducible con SDK 35.

La integración más reciente de **47 commits** está documentada commit por commit en [MAIN_SYNC_2026-10-23.md](MAIN_SYNC_2026-10-23.md). El registro de la integración anterior está en [MAIN_SYNC.md](MAIN_SYNC.md). Apple Watch, HealthKit y el entrenamiento coordinado con reloj se excluyeron por instrucción del usuario.

### Iconos

La navegación, acciones, controles y estadísticas usan [Phosphor Icons](https://github.com/phosphor-icons/core/tree/2b75f3ad12b420c9504ef05df8d2564a28f8500e), convertidos a VectorDrawable y centralizados en `AppIcons.kt`. Los iconos musculares comparten las rutas y recortes MIT de iOS; se generan con `python3 tools/generate-muscle-icons.py` desde esta carpeta Android. Las licencias se incluyen en `assets/licenses/`. Las flechas de navegación se reflejan en RTL. No se exportan SF Symbols. Con texto ampliado, la barra muestra iconos con etiquetas accesibles para evitar recortes; con tamaño normal conserva los nombres visibles.

### Gesto motivacional

The motivational banner occupies the space revealed by the pull inside the Summary content viewport, below the native top app bar. Both the banner and celebration particles are clipped to that viewport, preserving the header and floating navigation. Releasing the gesture returns the content smoothly; switching tabs or leaving the app resets the effect. The instrumented motivational flow checks the banner, emoji, phrase, chart, and celebration bounds against the header and viewport.
