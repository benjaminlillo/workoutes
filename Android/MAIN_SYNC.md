# Integración de main — 4 de octubre de 2026

Origen analizado: `7523710` → `origin/main` en `fff9807`. Son 27 commits, incluidos 9 merges. Integración local en `codex/android-main-sync`, merge `83a5e1c`; no se hizo push. Android se preservó antes de fusionar y no hubo conflictos.

## Revisión commit por commit

| Commit | Cambio nuevo | Integración en Android |
| --- | --- | --- |
| `e37a0ef` | Exploraciones de iconos y SVG definitivo de barra EZ con forma de W. | Se reutiliza el SVG como vector del icono adaptativo; las exploraciones no se incluyen en la app. |
| `4a9028b` | Merge de las exploraciones de iconos. | Sin comportamiento adicional; incluido en el merge de main. |
| `55717bb` | Primer borde sutil de acento para las tarjetas de ejercicio. | Borde de 1 dp con degradado diagonal de opacidades 24 %, 8 % y 18 %. |
| `740024c` | Summary semanal, IDs estables, sesiones e historial persistentes; completar solo al detener después de más de 10 segundos; temporizador; backups opcionales con historial; importación por ID y fondos predeterminados. | Cuarta pestaña Summary, gráfico de lunes a domingo, estadísticas, sesión guardada y restaurada, regla estricta de duración, historial independiente del estado actual, temporizador en barra/notificación y JSON actualizado. Cambiar de ejercicio cancela el intento anterior. |
| `5bf1728` | Merge de iconos con Summary e historial. | Conserva ambos cambios; sin otro comportamiento. |
| `b483153` | Integra Summary en la rama de bordes. | Se combinan bordes y nuevo modelo de sesiones. |
| `0686b8a` | Generaliza los bordes a rutinas, Summary, ajustes, importación y formularios. | Bordes en tarjetas de todas esas superficies y grupos de los editores nativos. |
| `ec0556f` | Merge de los bordes en main. | Sin comportamiento adicional. |
| `02a8f3e` | Restaura los fondos nativos de las hojas modales. | ModalBottomSheet mantiene su superficie Material; el fondo de tema se aplica a las pantallas. |
| `7cf870c` | Merge de los fondos de hojas en main. | Sin comportamiento adicional. |
| `0d59eb3` | Fondos predeterminados siguen el acento; editar colores crea una personalización local. | Se conserva la paleta antigua como marcador del fondo predeterminado, se muestran los colores del tema al editar y se mantienen fotos/degradados personalizados. Automatic sin etiquetas vuelve al tema. |
| `6eef2e7` | Valores y opciones de ajustes usan el color de acento. | Nombre del tema, unidad seleccionada y opciones usan el acento. |
| `c724bb8` | Títulos de ajustes conservan el color normal de texto. | Theme y Weight Unit usan el color de texto de Material, independiente del valor. |
| `503f311` | Cinco temas con nuevos nombres/colores y migración de preferencias antiguas. | Blue Slate, Majorelle Blue, Frozen Water, Midnight Violet y Blazing Flame; Blue/Green/Red se resuelven a Indigo/Mint/Orange. |
| `165f487` | Refresca los pickers nativos al cambiar de acento. | Compose recompone valores y controles al cambiar el tema; no conserva estilos UIKit en caché. |
| `77889d7` | Frozen Water y Midnight Violet se adaptan a claro/oscuro. | Colores claros y oscuros equivalentes, también en las vistas previas y notificaciones. |
| `6ff2a7e` | Segundo color propio para el degradado de cada tema; etiqueta Theme. | Paletas de dos colores y ajustes renombrados a Theme. |
| `52f0328` | Degradados de tema diagonales por toda la pantalla. | Canvas con degradado lineal de arriba izquierda a abajo derecha; se conserva la transición suave. |
| `76c102f` | Merge de paleta y degradados. | Sin comportamiento adicional. |
| `811cf47` | Gesto motivacional al tirar de la pantalla inicial: emoji, frase, vibración y celebración de tres segundos. | Gesto en Summary mediante nested scroll, frases/emojis de iOS, vibración nativa y partículas sobre la interfaz; respeta animaciones desactivadas y se limpia al salir. |
| `c738194` | Merge del gesto motivacional con los temas. | Se preservan ambos. |
| `42ac4cb` | Icono de app cambia automáticamente con el tema. | Cinco iconos adaptativos de la misma barra W, con activity aliases y un solo acceso del launcher habilitado. |
| `534d28c` | Pantalla Theme con carrusel de vistas previas independientes. | Submenú con previews decorativas de Exercises; no altera datos reales. |
| `9afde14` | Merge de previews e iconos de tema. | Sin comportamiento adicional. |
| `82b3e1d` | Carrusel centrado similar al selector de apps: tarjetas próximas, escala, ajuste al centro y selección accesible. | HorizontalPager centrado, previews próximas con escala, paginación y recenter al seleccionar; selección con semántica de radio. |
| `cef21ca` | Merge del carrusel definitivo. | Sin comportamiento adicional. |
| `fff9807` | Dynamic Island compacta incluye series × repeticiones y peso. | Android muestra series, repeticiones y peso en la notificación; la barra muestra series × repeticiones y tiempo transcurrido. |

## Reglas de datos y comportamiento

- Tarjeta, barra y notificación detienen la misma sesión. Duraciones de 10 segundos o menos se cancelan; más de 10 segundos marcan completado y guardan un registro, una sola vez.
- Cambiar de ejercicio cancela el intento anterior aunque haya durado más de 10 segundos. Los botones de notificaciones antiguas no pueden modificar una sesión posterior.
- Restablecer completados conserva el historial. Borrar un ejercicio conserva el registro con referencia nula y texto “Exercise deleted”. Los colores del gráfico siguen las etiquetas actuales del ejercicio.
- La semana empieza el lunes y termina al inicio del lunes siguiente, usando fechas locales y respetando cambios de zona horaria/horario de verano. Summary se actualiza al volver a la app y cada minuto.
- Importar actualiza catálogo por ID, conserva elementos que no aparecen en el archivo y añade registros de historial por ID sin duplicarlos ni reescribir registros existentes. Los JSON anteriores sin historial siguen siendo compatibles.
- Exportar permite elegir Include History o Catalog Only. Nunca exporta sesiones activas, fondos ni preferencias.
- Los archivos Android anteriores conservan catálogo, preferencias y fondos. Una sesión antigua sin fecha se migra con una fecha nueva; no se inventan completados retroactivos.

## Adaptaciones nativas

Material 3 y Compose mantienen las hojas, botones y navegación de Android. El launcher controla la forma final del icono y puede tardar en reflejar un cambio. Los aliases usan la API nativa documentada por [Android Developers](https://developer.android.com/guide/topics/manifest/activity-alias-element). Dynamic Island se adapta a la barra y notificación estándar, con temporizador del sistema.

## Validación

La compilación del APK y del APK de pruebas es correcta. Pasaron las 21 pruebas unitarias Android y los seis flujos de Compose, con revisiones adicionales de Summary, gesto motivacional, exportación y temas en modo claro/oscuro. Android Lint reporta 0 errores y ocho avisos de versiones más recientes de dependencias.

La integración iOS pasó sus 52 pruebas en iOS 27. Un intento inicial en iOS 26.5 falló en tres pruebas de la identidad del accesorio/TabView; en iOS 27 pasan sin modificar código iOS. Los archivos iOS del worktree son idénticos al main integrado.

Las capturas de revisión están en `app/build/main-sync-evidence/`; el APK está en `app/build/outputs/apk/debug/app-debug.apk`. Se verificaron tarjetas, Summary vacío/poblado, temporizador, carrusel, icono del launcher y partículas. La revisión corrigió un ripple rectangular en las previews, la distribución de partículas y el color de texto fuera de tarjetas en modo oscuro. El SVG del icono se convirtió a un vector adaptativo con curvas simplificadas y variante monocromática.

Android continúa como archivos locales sin commit, igual que al comenzar esta integración. El merge de main quedó registrado en `83a5e1c`.

Durante la preparación se corrigió un carácter sobrante del SHA-256 del wrapper Gradle, contrastándolo con el checksum oficial de Gradle 8.11.1. No se cambiaron las versiones de dependencias.
