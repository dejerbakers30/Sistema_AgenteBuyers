# 🎓 INBESTIGA - Sistema Agente IA de Captación (Fase BUYER) & Dashboard BI

Prototipo funcional end-to-end de la **Fase BUYER** para la startup de asesoría de tesis **INBESTIGA**. El sistema implementa un Agente IA en WhatsApp que califica prospectos universitarios, valida la cobertura de su universidad y carrera mediante Function Calling, ejecuta transacciones atómicas en SQL Server y alimenta en tiempo real un Dashboard de Inteligencia de Negocios en Streamlit.

---

## 🏗️ 1. Arquitectura del Sistema

El prototipo opera en una arquitectura desacoplada de dos procesos concurrentes conectados a una única fuente de verdad transaccional (**OLTP**):

```
                                  ┌───────────────────────────────┐
                                  │      xAI Grok API (LLM)       │
                                  │  - Extracción de Entidades    │
                                  │  - Function Calling (Tools)   │
                                  └──────────────▲────────────────┘
                                                 │ Tools Payload / Response
                                                 ▼
┌─────────────────────────┐             ┌─────────────────────────────────┐
│     Estudiante          │  WhatsApp   │       Bot Node.js Backend       │
│  (WhatsApp en Vivo)     │◄───────────►│       (whatsapp-web.js)         │
└─────────────────────────┘             └────────────────┬────────────────┘
                                                         │ Inserción Transaccional
                                                         │ (CONTACTO -> PERFIL -> BUYER)
                                                         ▼
                                        ┌─────────────────────────────────┐
                                        │    SQL Server (INBESTIGA_TESIS) │
                                        │   Tablas: BUYER, CONTACTO,      │
                                        │   PERFIL_ACADEMICO, CARRERA,    │
                                        │   UNIVERSIDAD, MENSAJE, etc.    │
                                        └────────────────┬────────────────┘
                                                         │
                                                         │ SELECT Directo en Tiempo Real
                                                         │ (Auto-refresco cada 2-5s)
                                                         ▼
                                        ┌─────────────────────────────────┐
                                        │    Dashboard BI (Streamlit)     │
                                        │  - KPIs Ejecutivos              │
                                        │  - Tasa de Cobertura            │
                                        │  - Distribución por Carrera     │
                                        │  - Auditoría de Conversaciones  │
                                        └─────────────────────────────────┘
```

---

## 💻 2. Stack Tecnológico Definido

| Componente | Tecnología | Rol / Responsabilidad |
| :--- | :--- | :--- |
| **Frontend & BI** | Python 3.10+ / Streamlit / Plotly | Panel ejecutivo con KPIs en tiempo real, tablas operativas y auto-refresco. |
| **Backend / Bot** | Node.js (v18+) / `whatsapp-web.js` | Automatización de WhatsApp Multi-Device con persistencia de sesión local (`LocalAuth`). |
| **Cerebro NLP** | API de Grok (`xAI`) / OpenAI SDK | Procesamiento de lenguaje natural, clasificación y ejecución de *Function Calling*. |
| **Base de Datos** | Microsoft SQL Server (OLTP: `INBESTIGA_TESIS`) | Almacenamiento relacional con integridad referencial estricta. |
| **Conectores DB** | `mssql` (Node.js) & `pyodbc` (Python) | Pool de conexiones y ejecución de transacciones atómicas seguras. |

---

## 🗄️ 3. Estructura de la Base de Datos (Fase BUYER)

El prototipo interactúa exclusivamente con las siguientes **9 tablas del modelo transaccional**:

1. **`UNIVERSIDAD`**: Catálogo universitario con flag de cobertura `atendida` (1 = Sí, 0 = No).
2. **`CARRERA`**: Programas académicos vinculados a cada universidad (`atendida BIT`).
3. **`CONTACTO`**: Identidad del estudiante (nombres, apellidos, número de WhatsApp único, consentimiento).
4. **`PERFIL_ACADEMICO`**: Información académica del tesista (etapa, ciclo, sede, tipo de investigación).
5. **`BUYER`**: Estado del prospecto (`ACTIVO` si cuenta con cobertura completa o `SIN_COBERTURA` si pasa a lista de espera).
6. **`CANAL`**: Canal de origen (por defecto `canal_id = 1`: "WhatsApp organico").
7. **`CAMPANIA`**: Campaña publicitaria asociada (`NULL` para tráfico orgánico).
8. **`CONVERSACION`**: Sesión de chat registrada por contacto y canal.
9. **`MENSAJE`**: Trazabilidad completa de mensajes emitidos tanto por el `CLIENTE` como por el `BOT`.

> **Integridad Referencial Garantizada:** La función `registrarBuyerTransaccional` en `bot.js` ejecuta un bloque de transacción SQL Server (`BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`) para garantizar que nunca se inserte un registro huérfano.

---

## 📂 4. Estructura del Proyecto

```
Sistema_AgenteBuyers/
├── 01_CREAR_BD_TRANSACCIONAL_DEFINITIVO.sql   # Script oficial de creación del OLTP
├── 02_POBLAR_BD_TRANSACCIONAL_DEFINITIVO.sql  # Poblado determinista de prueba
├── 03_CREAR_DATAMART_DEFINITIVO.sql           # Esquema dimensional (INBESTIGA_MART)
├── 04_ETL_POBLAR_DATAMART_DEFINITIVO.sql      # Procedimiento ETL de reconciliación
├── bot.js                                     # Backend del Bot WhatsApp + Grok + SQL Server
├── dashboard.py                               # Dashboard BI interactivo en Streamlit
├── database.sql                               # Script auxiliar de validación de datos
├── diagnostico_sistema.py                     # Script pre-vuelo para chequear conectividad
├── simulador_chat.js                          # Simulador CLI para pruebas sin teléfono
├── package.json                               # Dependencias Node.js
├── requirements.txt                           # Dependencias Python
├── .env.example                               # Plantilla de variables de configuración
├── .env                                       # Variables de entorno locales (en .gitignore)
├── .gitignore                                 # Protección de secretos y sesión de WhatsApp
└── README.md                                  # Documentación completa del proyecto
```

---

## 🚀 5. Guía de Instalación y Configuración

### Prerrequisitos
* **Node.js** v18 o superior (`node -v`).
* **Python** 3.10 o superior (`python --version`).
* **SQL Server** en ejecución con la base de datos `INBESTIGA_TESIS` creada (ejecutando previamente los scripts `01` y `02`).
* **ODBC Driver 17 for SQL Server** instalado.
* **API Key de Grok (xAI)** obtenida en [console.x.ai](https://console.x.ai/).

### Paso 1: Configurar Variables de Entorno (`.env`)
Edita el archivo `.env` en la raíz del proyecto:
```env
# Conexión SQL Server
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=INBESTIGA_TESIS
DB_USER=sa
DB_PASSWORD=TuPassword123*
DB_TRUST_SERVER_CERTIFICATE=true
DB_ODBC_DRIVER=ODBC Driver 17 for SQL Server

# Inteligencia Artificial (xAI Grok)
XAI_API_KEY=xai-tu-api-key-real-aqui
XAI_MODEL=grok-2-latest
```

### Paso 2: Instalar Dependencias
Abre una terminal de PowerShell:

```powershell
# 1. Dependencias del Bot de Node.js
npm install

# 2. Dependencias de Python para el Dashboard
pip install -r requirements.txt
```

### Paso 3: Diagnóstico Pre-Vuelo
Ejecuta el script de diagnóstico para verificar que SQL Server y las 9 tablas estén listos:
```powershell
python diagnostico_sistema.py
```

---

## 🎬 6. Ejecución del Prototipo

Para una demostración en vivo, se deben abrir **dos terminales independientes**:

### Terminal 1: Iniciar el Bot de WhatsApp
```powershell
npm start
```
1. Se generará un código QR en la consola.
2. Abre WhatsApp en tu celular $\rightarrow$ **Dispositivos vinculados** $\rightarrow$ **Vincular un dispositivo** y escanea el QR.
3. Tras autenticarse, aparecerá: `🤖 AGENTE BUYER LISTO Y CONECTADO A WHATSAPP REAL`.

### Terminal 2: Iniciar el Dashboard BI
```powershell
streamlit run dashboard.py
```
* Tu navegador abrirá automáticamente `http://localhost:8501`.
* Verás los KPIs iniciales y el botón de auto-refresco activado (actualización cada 5 segundos).

---

## 🧪 7. Guion de Demostración (Casos de Prueba)

### Caso A: Estudiante con Cobertura (`ACTIVO`)
1. Envía un mensaje al bot desde otro teléfono:
   > *"Hola, me llamo David Salazar, estudio Ingeniería de Sistemas en la Universidad Nacional de Trujillo y necesito ayuda urgente con mi proyecto de tesis."*
2. **Lo que hace el Bot:**
   * Llama a `verificar_cobertura` con UNT + Sistemas $\rightarrow$ Detecta `atendida = 1`.
   * Llama a `registrar_buyer` $\rightarrow$ Inserta `CONTACTO`, `PERFIL_ACADEMICO` y `BUYER` con `estado = 'ACTIVO'`.
   * Responde al estudiante felicitándolo y confirmándole que INBESTIGA cubre su programa y universidad.
3. **Lo que se ve en el Dashboard:**
   * El contador **Total Buyers** y **Con Cobertura** se incrementa de inmediato en pantalla sin recargar manualmente.
   * Aparece en la pestaña **Lista de Buyers** con etiqueta verde `ACTIVO`.

### Caso B: Estudiante sin Cobertura (`SIN_COBERTURA`)
1. Envía otro mensaje:
   > *"Hola, soy Andrea Peña de la Universidad de Lima, estudio Diseño Gráfico y quiero saber si asesoran tesis."*
2. **Lo que hace el Bot:**
   * Llama a `verificar_cobertura` $\rightarrow$ Detecta `atendida = 0` (o no listada).
   * Llama a `registrar_buyer` $\rightarrow$ Registra el prospecto con `estado = 'SIN_COBERTURA'`.
   * Responde cordialmente explicándole que por ahora no se atiende esa carrera, pero que sus datos quedan guardados en lista de espera preferencial.
3. **Lo que se ve en el Dashboard:**
   * Se incrementa el KPI **Sin Cobertura (Rojo)** y se actualiza el gráfico de torta de efectividad de catálogo.

### Caso C: Demostración Rápida por Terminal (Simulador CLI)
Si en plena exposición no se desea usar el celular o la red falla, puedes lanzar una prueba directa:
```powershell
node simulador_chat.js "Hola, soy Roberto Gómez de la UPAO de Administracion y necesito asesoría" 988776655
```
El script ejecutará el flujo idéntico de Grok y SQL Server, y el registro impactará al Dashboard en el segundo exacto.

---

## 🔒 8. Seguridad y Buenas Prácticas
* Las credenciales y llaves privadas de Grok se gestionan estrictamente mediante variables de entorno (`.env`).
* Las carpetas criptográficas de sesión de WhatsApp (`.wwebjs_auth/`) están excluidas del control de versiones en [.gitignore](file:///c:/Trabajos%20UNT/CICLO%20VIII/INTELIGENCIA%20DE%20NEGOCIOS/Sistema_AgenteBuyers/.gitignore).
* Todas las consultas SQL Server utilizan parámetros tipados (`sql.VarChar`, `sql.Int`) previniendo cualquier vulnerabilidad de SQL Injection.

