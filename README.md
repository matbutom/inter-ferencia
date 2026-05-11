# inter/ferencia

**Instalación de arte interactivo — Processing + webcam + televisión de tubo**

Una instalación sonora y visual que convierte el cuerpo humano en instrumento. Seis barras verticales invisibles atraviesan el espacio de la pantalla. Cuando una persona pasa frente a la cámara, su silueta —renderizada en caracteres ASCII— colisiona con esas barras y genera sonido. La obra no requiere instrucciones: la presencia es suficiente.

---

## Concepto

*inter/ferencia* toma su nombre del doble sentido de la palabra: la interferencia como fenómeno físico —ondas que se superponen, señales que se cruzan— y como acto relacional —intervenir el espacio del otro, ser intervenido sin saberlo.

Montada sobre una televisión de tubo en un corredor universitario de alto tráfico, la obra opera en el margen de la percepción. Las personas no buscan interactuar: pasan. Pero al pasar, componen. Su cuerpo se convierte en partitura involuntaria; sus movimientos, en notas de una escala pentatónica que suena y decae.

El sistema no muestra el video de la cámara. Muestra únicamente la diferencia entre el fondo vacío y la presencia del cuerpo, traducida a caracteres ASCII de distintos tamaños. Lo que queda en pantalla no es una imagen de la persona —es la huella de su paso.

---

<video width="100%" controls>
  <source src="/assets/inter-ferencia-01.mov" type="video/mov">
  Tu navegador no soporta el video.
</video>

## Requisitos de hardware

| Componente | Especificación mínima |
|---|---|
| Computador | Raspberry Pi 4 (4GB RAM) o cualquier Mac/PC |
| Cámara | Webcam USB (720p suficiente) |
| Pantalla | Televisión de tubo con entrada de video compuesto, o cualquier monitor |
| Audio | Parlantes o salida de audio del computador |

---

## Requisitos de software

- [Processing 4](https://processing.org/download) — entorno de desarrollo
- Java 17+ (incluido en Processing 4)

### Librerías de Processing (instalar desde Sketch → Import Library → Manage Libraries)

| Librería | Autor | Para qué sirve |
|---|---|---|
| **Video** | The Processing Foundation | Acceso a webcam |
| **Sound** | The Processing Foundation | Síntesis de audio |
| **OpenCV for Processing** | Greg Borenstein | Visión computacional |

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/matbutom/inter-ferencia.git
cd inter-ferencia
```

### 2. Instalar Processing 4

Descargar desde [processing.org/download](https://processing.org/download) según el sistema operativo:

- **macOS** → `.dmg`
- **Windows** → `.exe`
- **Linux / Raspberry Pi** → `.tgz` (versión ARM para Raspberry Pi)

#### En Raspberry Pi específicamente:

```bash
# Descargar versión ARM64
wget https://github.com/processing/processing4/releases/download/processing-1293-4.3/processing-4.3-linux-arm64.tgz

# Descomprimir
tar -xf processing-4.3-linux-arm64.tgz

# Ejecutar
cd processing-4.3
./processing
```

### 3. Instalar librerías

Abrir Processing → `Sketch` → `Import Library` → `Manage Libraries`

Buscar e instalar en orden:
1. `Video` (de The Processing Foundation)
2. `Sound` (de The Processing Foundation)
3. `OpenCV for Processing` (de Greg Borenstein)

Reiniciar Processing después de instalar.

### 4. Abrir el sketch

`File` → `Open` → seleccionar `inter_ferencia/inter_ferencia.pde`

### 5. Conectar la webcam

Conectar la webcam USB antes de correr el sketch. Si hay múltiples cámaras disponibles, la consola de Processing mostrará la lista al iniciar — cambiar el índice `cameras[0]` en el código si es necesario.

### 6. Correr

Presionar el botón ▶ o `Ctrl+R` (`Cmd+R` en Mac).

---

## Uso

Al iniciar, el sistema pide que el encuadre esté vacío durante **2 segundos** para capturar el fondo de referencia. Alejarse del campo de visión de la cámara durante ese tiempo.

Una vez capturado el fondo, la instalación está activa.

### Controles en vivo

| Tecla | Acción |
|---|---|
| `r` | Recapturar fondo (útil si cambia la iluminación) |
| `[` | Bajar umbral de detección del cuerpo (detecta más) |
| `]` | Subir umbral de detección del cuerpo (detecta menos) |
| `1` – `6` | Disparar manualmente cada barra (para pruebas de audio) |

### Calibración según el espacio

El parámetro más importante es `UMBRAL_CUERPO` (línea ~14 del código). Su valor por defecto es `55`.

- **Si detecta demasiado ruido** (caracteres aparecen solos sin nadie): subir el umbral con `]` o cambiar el valor en el código
- **Si no detecta bien el cuerpo** (silueta incompleta): bajar con `[`
- La iluminación del espacio afecta mucho — luz uniforme sin sombras duras funciona mejor

---

## Configuración en Raspberry Pi para instalación permanente

### Iniciar automáticamente al encender

Crear un script de inicio:

```bash
nano /home/pi/start_interferencia.sh
```

Contenido:

```bash
#!/bin/bash
export DISPLAY=:0
sleep 10  # esperar que el escritorio cargue
cd /home/pi/processing-4.3
./processing-java --sketch=/home/pi/inter-ferencia --run
```

Hacer ejecutable:

```bash
chmod +x /home/pi/start_interferencia.sh
```

Agregar al inicio automático:

```bash
nano /home/pi/.config/lxsession/LXDE-pi/autostart
```

Agregar al final:

```
@/home/pi/start_interferencia.sh
```

### Salida de video compuesto (para televisión de tubo)

En Raspberry Pi, editar `/boot/config.txt`:

```
# Forzar salida de video compuesto PAL (para TV de tubo)
sdtv_mode=2
sdtv_aspect=1
hdmi_force_hotplug=0
```

Reiniciar para aplicar cambios.

---

## Estructura del proyecto

```
inter-ferencia/
├── inter_ferencia/
│   └── inter_ferencia.pde    ← código principal
├── README.md
└── LICENSE
```

---

## Cómo funciona

El sistema tiene tres capas:

**Detección** — cada frame, compara el video de la cámara con una imagen de referencia del fondo vacío. Los píxeles con diferencia significativa (umbral configurable) son parte de la silueta. Opera con dos umbrales: uno alto para "cuerpo real" y uno bajo para "ruido de fondo".

**Visualización** — la silueta se renderiza como caracteres ASCII de dos tamaños. Los puntos de alta diferencia generan caracteres grandes y densos (`@#W&8B`). Los de baja diferencia generan puntos diminutos y casi invisibles (`.·`). No se muestra el video de la cámara.

**Sonido** — seis barras verticales fijas dividen el ancho de la pantalla. Cuando la silueta ASCII toca una barra (durante al menos 3 frames consecutivos), se dispara una nota de la escala pentatónica de Sol menor. Cada barra tiene su nota, su color y su oscilador independiente. El sonido decae suavemente (envelope de tipo arpa). Las barras se iluminan con glow al contacto y desaparecen gradualmente al alejarse.

---

## Créditos

Desarrollado en Processing con librerías de código abierto.

Concepto y código: **Mateo** / [Rafita Studio](https://rafita-studio.cl)

Colaboración en desarrollo: Claude (Anthropic)

---

## Licencia

MIT — libre para usar, modificar y redistribuir con atribución.