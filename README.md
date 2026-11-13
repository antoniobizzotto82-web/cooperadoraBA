# Cooperadora Escuela N.º 2 Nicolás Antonio

Proyecto Flutter preparado para GitHub + Codemagic.

## Funciones incluidas
- Alta inicial del responsable: nombre, teléfono y cargo.
- Registro de tutores/alumnos y teléfono de WhatsApp.
- Registro de pagos en efectivo o transferencia.
- Numeración correlativa de comprobantes.
- Panel con totales por medio de pago y recaudación total.
- Historial de pagos.
- Compartir comprobante base y abrir WhatsApp con un mensaje preparado.
- Exportar un respaldo JSON de los datos y compartirlo desde el celular.
- Persistencia local SQLite en el dispositivo.

## Antes de compilar
1. Crear un repositorio en GitHub.
2. Subir todo el contenido de este proyecto (incluido `codemagic.yaml`).
3. En Codemagic, conectar GitHub y seleccionar este repositorio.
4. Elegir el workflow `android-apk` y ejecutar el build.
5. Descargar `app-release.apk` desde Artifacts. Codemagic genera la carpeta Android necesaria durante el build.

En `codemagic.yaml`, reemplazar `YOUR_EMAIL@example.com` por el correo de notificaciones, o quitar la sección `publishing` si no se desea.

## Comandos locales
```bash
flutter pub get
flutter analyze
flutter build apk --release
```

## Importante sobre WhatsApp
Por las restricciones de WhatsApp, la app abre el chat del tutor con el texto ya preparado. La persona que opera la app debe confirmar el envío. No se realiza envío silencioso desde un WhatsApp personal.

## Datos y copias
Los datos se guardan localmente en la base SQLite privada de la app. El botón **Exportar respaldo** genera un archivo JSON con perfil, tutores y pagos para compartir. Guardar ese respaldo en un lugar seguro. La desinstalación de la app puede borrar los datos locales; exportar copias regularmente.

## Imágenes
- `comprobante_base.jpg`: diseño de comprobante compartido.
- `fondo_cooperadora.jpg`: escudo/fondo institucional.
- `escudo_alternativo.jpg`: versión alternativa del escudo recibida.

## Próximos ajustes antes de uso real
- Confirmar que el nombre institucional correcto que debe imprimirse sea “Escuela N.º 2 Nicolás Antonio” (el arte recibido menciona otra institución).
- Incorporar los datos bancarios oficiales si se desea conciliación de transferencias.
- Definir quién puede administrar o consultar los datos.
- Probar el APK en el teléfono y validar la generación/envío de comprobantes.

## Nota sobre el diseño recibido
El primer diseño de comprobante que se adjuntó contiene el nombre de otra institución (“Escuela de Bellas Artes”). Para evitar entregar comprobantes con datos institucionales incorrectos, la app genera un comprobante nuevo con el escudo recibido y el nombre de la Escuela N.º 2 Nicolás Antonio. El diseño original queda incluido en assets como referencia, no se imprime en los comprobantes generados.
