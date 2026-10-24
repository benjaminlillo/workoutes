# Entrenamiento con Apple Watch

La app de iPhone conserva el catálogo de ejercicios. La app de Watch ejecuta la progresión y registra una sesión de fuerza tradicional en HealthKit. Requiere Xcode 27 y watchOS 27; el target de iPhone conserva su mínimo de iOS 26.5.

## Uso

1. Instalar la app de iPhone y su companion `WorkoutesWatch` en el reloj emparejado. Abrir ambas para conectar. Al iniciar desde el iPhone, se presenta la autorización real de Salud antes de enviar el inicio al Watch. Habilitar escritura de entrenamientos y las lecturas deseadas. Si se inicia desde el Watch, también se solicita autorización. Un aviso de error con «OK» solo se descarta, no concede permisos.
2. Desde Summary → Train with Apple Watch, o Settings → Apple Watch, editar la estructura. Por defecto son cuatro bloques de ejercicio con dos minutos entre series y tres descansos de cinco minutos entre ejercicios.
3. Iniciar desde el iPhone o el Watch. Los bloques no tienen ejercicios predeterminados. Mientras aparece “Choose an Exercise”, activar un ejercicio del catálogo del iPhone con su control habitual. Durante una serie o cualquier descanso, ese mismo control permite dejar un ejercicio en cola para el siguiente bloque de ejercicio sin asignar. Hay una sola selección pendiente: elegir otra la reemplaza y pulsar de nuevo el control del ejercicio en cola la quita. La tarjeta del iPhone distingue el estado “Queued” del estado activo. No se salta el descanso ni se cambia el ejercicio que se está haciendo.
4. El Watch muestra el nombre, peso, repeticiones y serie actual. La cantidad de series viene del ejercicio seleccionado. La configuración se copia al seleccionar: editar el catálogo después no cambia un ejercicio ya en curso ni uno en cola. Durante el descanso entre bloques muestra también el ejercicio pendiente; el resto del tiempo se puede consultar en Details. Al llegar a su bloque se inicia automáticamente la primera serie y su cronómetro. La cola se guarda con el bloque de destino para sobrevivir a relanzamientos y retrocesos sin sobrescribir ejercicios ya asignados. El resumen del iPhone permite consultar o quitar la selección pendiente. Seleccionar requiere conexión en vivo y una sesión sin pausar; una cola ya confirmada se ejecuta aunque después se pierda la conexión. Si no quedan bloques vacíos, se informa de ello.
5. La pantalla principal del Watch muestra la tarjeta del ejercicio arriba, el tiempo de la etapa en verde durante el entrenamiento o amarillo durante un descanso, el pulso a su lado y la duración total debajo. Deslizar hacia arriba o girar la corona muestra una segunda página con calorías, promedio y máximo de pulso y zonas disponibles. Deslizar hacia la derecha abre los controles situados a la izquierda: pausar/reanudar, terminar serie/omitir descanso, volver al bloque anterior, deshacer y terminar la sesión. Dos toques en la página principal también terminan la serie. El descanso entre series termina automáticamente con vibración y empieza el cronómetro de la siguiente serie.

   Previous Block vuelve al bloque anterior de la estructura. Si es un ejercicio completado, reabre solamente su última serie, conserva las anteriores y actualiza su estado de hecho en el iPhone. Si es un descanso, reinicia su duración completa. Se conservan las series ya registradas de bloques posteriores y se retoman al volver a ellos. No altera la duración total ni reinicia HealthKit; requiere que la sesión esté sin pausar. Undo Last Transition permite deshacer también este retroceso.
6. La última serie marca el ejercicio como hecho y crea una entrada en su historial. Luego comienza el siguiente bloque de la estructura; no se añade otro descanso entre series después de la última. Cada nuevo bloque de ejercicio espera una selección.
7. Al terminar los bloques, la sesión sigue registrando hasta pulsar Finish Training. Se puede indicar esfuerzo de 1 a 10 o terminar sin calificarlo. Terminar antes conserva las series completadas; un ejercicio incompleto no se marca como hecho.

Los descansos normales mantienen la sesión de HealthKit activa. Pause suspende tanto la progresión como el registro activo de HealthKit. Los cronómetros usan fechas límite para recuperarse después de pasar a segundo plano. La selección requiere conexión al iPhone; el ejercicio elegido y los descansos siguen funcionando sin esa conexión.

## Live Activity del ejercicio

La Live Activity usa el ejercicio activo, tanto si se inició desde el iPhone como si llegó desde el Watch. Iniciar o terminar un tracker genérico no cancela un ejercicio local que siga activo. Una selección real del Watch ocupa ese lugar y actualiza la misma tarjeta sin duplicarla ni crear un segundo registro local de series. Se conserva durante los descansos entre series, las pausas y la pérdida de conexión; un ejercicio en cola todavía no se considera activo. Se sincroniza al recibir snapshots, editar el catálogo y volver a primer plano. La app y los intents usan el mismo estado restaurado, y los botones de etapas antiguas se ignoran.

La presentación sigue sujeta al permiso de Live Activities del sistema. [ActivityKit permite actualizar y terminar actividades existentes en segundo plano, pero restringe el inicio de una nueva a primer plano, intents del sistema o notificaciones push](https://developer.apple.com/documentation/activitykit/activity). Si una selección recibida en segundo plano no puede iniciar una actividad nueva, la app lo reintenta al volver a primer plano y conserva el ejercicio activo sin alertas repetidas. Esta implementación no incorpora un servidor APNs.

## Datos y sincronización

- `HKWorkoutSession` y `HKLiveWorkoutBuilder` usan fuerza tradicional en interior y los algoritmos de Apple. Se muestran pulso reciente, promedio y máximo, calorías activas y totales cuando están disponibles, zonas de pulso del sistema y recuperación al minuto cuando HealthKit ofrece una muestra correspondiente. No se inventan ceros ni estimaciones propias para datos ausentes.
- El builder guarda el entrenamiento y sus muestras en Salud. Workoutes conserva los resultados de las series, la estructura usada y el resumen de métricas recibido del Watch. Las muestras detalladas de sensores permanecen en HealthKit; este cambio no añade gráficas de pulso.
- Las zonas usan las API de watchOS 27. No se estiman VO₂ máximo ni recuperación cardiovascular longitudinal a partir de fuerza.
- El esfuerzo manual se guarda y relaciona con el entrenamiento mediante HealthKit. Su presentación en Fitness y el cálculo de carga dependen de Apple y de los permisos.
- El Watch es la autoridad de una sesión. Los comandos incluyen sesión y revisión para rechazar acciones antiguas; las acciones interactivas no se dejan en cola para ejecutarlas después. Los snapshots durables permiten recuperar resultados al reconectar.
- Durante un entrenamiento real se usa también la conexión bidireccional de `HKWorkoutSession` mediante mirroring. El iPhone registra el receptor al iniciar y el Watch inicia o recupera el enlace junto con su sesión. Los controles están disponibles si HealthKit o WatchConnectivity permiten envío inmediato; recibir un snapshot diferido no se interpreta como confirmación de una conexión interactiva.
- Si falla el envío por HealthKit, se intenta WatchConnectivity con el mismo mensaje y el mismo identificador de comando. La revisión y la caducidad no se renuevan. La app del Watch reintenta el mirroring al volver a primer plano y durante el entrenamiento, con un mínimo de diez segundos entre intentos. Refresh vuelve a consultar el estado del enlace, incluso si el iPhone lo tenía marcado como desconectado.
- El canal de HealthKit se reserva para el estado actual; el historial en bloque sigue usando WatchConnectivity para respetar el límite de 100 KB por diez segundos del mirroring. El modo de simulador continúa usando WatchConnectivity.
- El identificador de sesión se usa como `HKMetadataKeySyncIdentifier`. El guardado conserva la identidad antes de añadir el esfuerzo; los reintentos no crean otra sesión. Las finalizaciones del catálogo usan un identificador por sesión y bloque. Los recibos de reconciliación impiden recrear historial borrado deliberadamente.
- La estructura y los resúmenes se guardan atómicamente en Application Support/Training/training.json de cada dispositivo. El backup existente del catálogo sigue incluyendo sus finalizaciones, pero no incluye este archivo de sesiones completas.
- Si Salud falla, se conserva el registro local y se ofrece reintentar. “Keep Local Record and Continue” permite abandonar explícitamente ese guardado pendiente y empezar otra sesión; el historial muestra el error. Una sesión de sensores que no se puede recuperar se marca como interrumpida, sin simular que continúa grabando.

## Verificación en hardware

Las pruebas automatizadas cubren la estructura genérica, cantidades variables de series, duración indefinida, descansos, pausas, deshacer, restauración, snapshots repetidos o antiguos y reconciliación del historial. Las pantallas de iPhone se capturan desde el simulador. La compilación puede verificarse sin firma:

```sh
xcodebuild -project Workoutes/Workoutes.xcodeproj -scheme Workoutes -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Workoutes/Workoutes.xcodeproj -scheme Workoutes -destination 'generic/platform=iOS' -configuration Release CODE_SIGNING_ALLOWED=NO build
```

Antes de usarlo en el gimnasio, validar con el Apple Watch SE real:

1. Autorizar Salud y comprobar pulso y calorías durante una sesión corta.
2. Seleccionar ejercicios de tres y cuatro series; verificar peso, repeticiones, doble toque y vibración con la pantalla activa y con el brazo bajado.
3. Probar pausa, deshacer la última serie, pérdida de conexión y relanzamiento de la app de Watch.
4. Terminar y confirmar una sola entrada de fuerza tradicional en Salud/Fitness, calorías, pulso y el esfuerzo indicado.
5. Mantener puesto el Watch tras terminar para verificar la disponibilidad de recuperación al minuto. Esta muestra puede tardar o no estar disponible.
6. Denegar permisos de lectura para verificar los datos ausentes y probar el reintento de guardado sin duplicados.
7. Iniciar desde el Watch fuera de la red Wi-Fi de casa, abrir el iPhone y seleccionar un ejercicio. Repetir tras bloquear y reabrir ambas apps y después de interrumpir temporalmente la conexión. Comprobar que se recuperan selección y controles, que no se duplican avances y que la sesión de Salud sigue siendo una sola. Esta validación del enlace real de HealthKit requiere instalar la versión actualizada en ambos dispositivos.

Un simulador no valida sensores, vibración, recuperación, cierre de anillos ni la presentación final de Fitness. La firma y los perfiles de HealthKit del target nuevo también se validan al instalarlo en el reloj.

## Permisos de Salud

Ambos targets incluyen `com.apple.developer.healthkit` y las descripciones de lectura/escritura. El iPhone implementa `applicationShouldRequestHealthAuthorization` para atender solicitudes de autorización que HealthKit derive desde la app compañera. Una solicitud completada no implica acceso concedido: se comprueba el permiso de escritura de entrenamientos antes de comenzar. No se puede consultar el permiso de lectura para deducir si fue denegado.

Si se denegó escribir entrenamientos, cambiarlo en Salud → perfil → Apps → Workoutes. Los comandos de inicio fallidos se recuerdan para que el mismo mensaje de WatchConnectivity no repita el aviso al cerrar «OK».

## Modo de prueba del simulador

Las compilaciones para simulador ejecutan la misma progresión y sincronización, con una etiqueta «Simulator Preview · No Health recording». Abrir ambas apps antes de iniciar desde el iPhone. El modo no solicita permisos, no inicia sensores, no inventa métricas y no guarda entrenamientos ni esfuerzo en Salud. Las sesiones locales quedan identificadas como previews, incluso en el historial y después de relanzar. En dispositivos físicos esta ruta no se compila: se mantiene el inicio con HealthKit y su autorización obligatoria.

Verificado el 12 de octubre de 2026 en iPhone 18 Pro + Apple Watch SE 3 de Device Hub: inicio desde iPhone, selección durante la sesión, nombre/peso/repeticiones/series en Watch, doble toque, avance automático tras dos minutos, restauración del descanso al relanzar ambas apps, tres series que marcan el ejercicio como hecho, siguiente bloque genérico y cierre con historial local identificado como preview. Pasaron 21 pruebas de entrenamiento y las compilaciones Debug para simuladores y Release para dispositivos. La autorización y el registro real de sensores siguen pendientes de validación en hardware.

El 16 de octubre el usuario informó de una primera ejecución correcta en hardware y de una segunda sesión que llegó al iPhone con pulso y calorías, pero cuyos controles quedaron bloqueados por el estado de WatchConnectivity. Se añadió mirroring de HealthKit, reconexión y fallback entre canales inmediatos. Pasaron 83 pruebas en iOS Simulator, incluidas cuatro de selección sin WatchConnectivity, reintento con identidad conservada y fallo sin dejar acciones en cola. La corrección del enlace de HealthKit requiere una nueva prueba con esta versión instalada en ambos dispositivos físicos.

El 23 de octubre se verificaron en un simulador Apple Watch SE 3 de 44 mm las dos páginas verticales, el acceso lateral a controles y el regreso por deslizamiento, el retroceso a un descanso, la reapertura de la última serie de un ejercicio completado y el avance por doble toque. Pasaron cinco pruebas de retroceso, conservación de series, restauración y reconciliación del historial sin duplicados. Estas comprobaciones de interfaz usan una sesión local de ejemplo identificada como preview; no validan sensores ni vibración.
