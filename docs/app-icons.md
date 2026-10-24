# Iconos de Workoutes

Cada tema usa un paquete `.icon` editable en Icon Composer. Se conservan los nombres registrados en Xcode y el cambio automático de icono al elegir un tema. Apple Watch comparte el icono principal de Violet Aura.

## Capas

- **W original:** PNG transparente proporcionado por el usuario, sin redibujar ni alterar sus píxeles. Canvas de 1254 × 1254, normalizado mediante la escala de Icon Composer.
- **W clara:** variante de grafito con los pliegues y el volumen de la W original, generada con `image_gen` para contrastar sobre fondos claros.
- **Colores del tema:** rectángulo SVG con un gradiente nativo editable en Icon Composer. Usa el primario y secundario de `ThemeColor.swift`, con mezcla Multiply sobre la textura.
- **Textura y luz:** versión neutra del fondo proporcionado por el usuario. Conserva la composición oscura y los reflejos de las esquinas.

En **Default** se muestra un gradiente pastel del primario y secundario (mezclados con blanco al 82 % y 60 % respectivamente), la misma textura en Soft Light al 12 % y la W de grafito. En **Dark** se conserva la composición aprobada: fondo oscuro granulado, luces con los dos tonos del tema y W original de marfil. Cada `.icon` incluye ambas apariencias mediante especializaciones nativas de imagen, posición, relleno y opacidad; no hace falta cambiar de icono al cambiar el modo del sistema.

En Mono, que genera las variantes Clear y Tinted, los dos grupos de fondo tienen opacidad cero para permitir el material nativo y se usa la W original. Apple Watch conserva su composición oscura, ya que utiliza una única apariencia.

Los PNG son recursos internos de cada paquete; el icono final sigue siendo un documento por capas, no un PNG aplanado. Los cambios son recursos de compilación y no generan texturas durante la ejecución de la app.

## Regenerar

Las fuentes canónicas están en `Workoutes/Workoutes/WorkoutesIcon.icon/Assets/`. El script lee los colores, nombres y registros de iconos directamente del enum Swift:

```sh
python3 tools/generate_theme_app_icons.py
```

Las ediciones manuales de estilo realizadas en Icon Composer se reemplazan al regenerar. No es necesario regenerar para abrir y editar un paquete individual.

## Procedencia

- W original: `FE424829-12CD-47FA-A975-8FD4ED55C77A.PNG`.
- Referencia del fondo: `1CE02E88-5251-4EFD-BDDC-DEBD23EBB88B.PNG`.
- Base neutra creada mediante la herramienta integrada `image_gen`, con la referencia de fondo como imagen de entrada. El prompt está en [app-icon-texture-prompt.txt](app-icon-texture-prompt.txt).
- W de grafito creada mediante la herramienta integrada `image_gen`, con la W original como imagen de entrada. El prompt está en [app-icon-light-prompt.txt](app-icon-light-prompt.txt).
- El renderizado y la comprobación de apariencias se realizan con `ictool`, incluido en Icon Composer de Xcode.

Referencia del formato y las apariencias: [Documentación de Apple](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer).
