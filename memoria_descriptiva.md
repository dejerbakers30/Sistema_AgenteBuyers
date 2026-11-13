### TÍTULO DEL SOFTWARE
**Agente Conversacional con IA para la Atracción, Filtro de Cobertura y Segmentación de Prospectos en Asesoría Académica**

---

### 1. PROBLEMA QUE RESUELVE

En primer lugar, los procesos actuales de atención inicial a prospectos en instituciones y centros de asesoría académica son manuales, lentos y dependientes de la disponibilidad del personal humano. Esto genera demoras críticas en la primera respuesta y, sumado a la falta de atención 24/7, provoca que un alto porcentaje de interesados abandone el proceso antes de recibir información clara sobre la oferta académica.

En segundo lugar, no existe un mecanismo estandarizado para filtrar la cobertura de cada prospecto (verificar requisitos académicos, geográficos, económicos o de disponibilidad horaria antes de transferirlo a un asesor). En consecuencia, los asesores académicos pierden tiempo valioso atendiendo leads no calificados, lo que reduce su productividad operativa y la calidad de atención hacia los prospectos realmente aptos.

Adicionalmente, la segmentación de prospectos es empírica o inexistente, lo que impide diseñar estrategias de seguimiento personalizadas y resta efectividad a las campañas de remarketing y llamadas comerciales, afectando negativamente las tasas de conversión y matrícula. Finalmente, los datos recolectados durante las conversaciones iniciales no se aprovechan analíticamente, perdiéndose oportunidades clave para identificar tendencias y tomar decisiones estratégicas basadas en datos.

---

### 2. FUNCIONALIDAD (PARA QUÉ SIRVE)

El sistema propuesto es un agente conversacional con inteligencia artificial que funciona como primer contacto entre la institución y los estudiantes interesados en sus programas académicos y servicios de asesoría. Su principal objetivo es captar, filtrar y clasificar prospectos mediante conversaciones naturales, reduciendo las tareas repetitivas de los asesores para que puedan concentrarse en brindar orientación académica y concretar matrículas. Durante la conversación, el agente identifica las necesidades del estudiante, recopila información sobre su perfil académico y verifica si cumple con los requisitos de cobertura de la institución.

El sistema también facilita el trabajo de los asesores, ya que les permite recibir prospectos previamente evaluados y clasificados, junto con sus datos y el historial de conversación. Además, cuenta con paneles de control que muestran indicadores de captación, conversión y efectividad de la segmentación en tiempo real. Estas funciones se complementan con un módulo administrativo que permite gestionar usuarios, configurar el agente y mantener actualizado el catálogo de programas académicos y universidades atendidas.

El sistema se organiza en los siguientes módulos, donde el rol administrador centraliza el acceso total y unificado a todas las herramientas de supervisión, auditoría y gestión de la plataforma:

**A) Acceso y Seguridad:** Gestiona el control de acceso, autenticación y protección de datos, otorgando al rol administrador acceso integral para operar, supervisar y configurar todas las funciones de la plataforma.

**B) Conversación Inteligente (Interacción del Prospecto):** Permite al estudiante interactuar directamente mediante chat con el agente de IA (disponible 24/7 y sin requerir inicio de sesión previo). Durante el diálogo, el sistema identifica sus intereses académicos, recopila sus datos y verifica en tiempo real los requisitos de cobertura, emitiendo una clasificación automática al finalizar.

**C) Trazabilidad y Gestión de Prospectos (Administrador):** Permite al administrador consultar el listado consolidado de estudiantes calificados por la IA, acceder a sus perfiles académicos completos, conocer su estado (cobertura aprobada o lista de espera) y coordinar el seguimiento personalizado hasta concretar la matrícula.

**D) Validación y Clasificación de Cobertura (Administrador):** Permite al administrador revisar la clasificación realizada por la IA y decidir si la confirma, modifica o rechaza según el criterio institucional, agregando observaciones y comentarios que ayuden a mejorar el seguimiento del estudiante.

**E) Auditoría de Conversaciones en Tiempo Real (Administrador):** Permite al administrador inspeccionar en vivo el historial completo de mensajes intercambiados entre cada estudiante y el agente de IA, garantizando la transparencia de la atención y conociendo el contexto exacto de cada consulta.

**F) Gestión Administrativa y Configuración (Administrador):** Permite administrar las cuentas del sistema, configurar las conversaciones y directivas del agente inteligente, y mantener actualizado el catálogo de programas académicos, universidades y reglas de cobertura de la institución.

**G) Analítica General y Dashboards BI (Administrador):** Presenta paneles con indicadores en tiempo real de captación, conversión, efectividad de la segmentación y demanda fuera de cobertura. Estos datos ayudan a identificar servicios con mayor demanda, conocer las solicitudes que no pueden atenderse y tomar decisiones estratégicas para optimizar la gestión comercial.

Una de las principales características del sistema es que utiliza inteligencia artificial para atender consultas durante las 24 horas del día, sin depender de la disponibilidad de un asesor. Además, permite verificar los requisitos de cobertura y clasificar a los estudiantes en tiempo real. De esta manera, los asesores reciben información organizada sobre cada prospecto y pueden dedicar más tiempo a quienes realmente pueden acceder a los servicios de la institución.

---

### 3. ARQUITECTURA DEL SOFTWARE

La arquitectura de la solución se estructura siguiendo un modelo desacoplado y orientado a servicios:

#### A) Lenguajes de programación
* **JavaScript/Node.js:** Lenguaje principal empleado tanto en el backend (servidor de API REST y orquestación del agente conversacional de WhatsApp) como en el frontend interactivo en React.
* **Python:** Lenguaje complementario utilizado para el análisis de datos, scripts de simulación de pruebas y soporte analítico.
* **SQL (Transact-SQL):** Lenguaje empleado para la gestión estructurada de la base de datos relacional, la definición de restricciones de integridad y la ejecución de transacciones atómicas seguras.

#### B) Base de datos
* **Microsoft SQL Server:** Sistema de gestión de bases de datos relacional (RDBMS) de nivel empresarial que aloja la base de datos transaccional (`INBESTIGA_TESIS`), garantizando integridad referencial estricta, transacciones ACID y persistencia de las tablas de contactos, perfiles académicos, buyers calificados, conversaciones y mensajes de auditoría en tiempo real.

#### C) Backend
* **Node.js (Express):** Entorno de ejecución y servidor backend encargado de exponer los servicios mediante una API REST, gestionar la conexión directa a SQL Server mediante autenticación integrada de Windows (`mssql/msnodesqlv8`), coordinar el cliente de WhatsApp (`whatsapp-web.js`) y administrar la integración con el motor de IA conversacional (Google Gemini / Grok) mediante *Function Calling*.

#### D) Frontend
* **React (con Tailwind CSS):** Biblioteca de JavaScript utilizada para construir el panel web interactivo tipo SPA (Single Page Application), proveyendo dashboards ejecutivos de Inteligencia de Negocios con actualización en tiempo real, gráficos analíticos interactivos y visor de auditoría de conversaciones estilo WhatsApp Web.

---

```
[INCLUIR DIAGRAMA DE ARQUITECTURA DEL SOFTWARE AQUÍ]
```
