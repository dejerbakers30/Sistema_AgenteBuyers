# MANUAL DE CÓDIGO FUENTE

## Agente Conversacional con IA para la Atracción, Filtro de Cobertura y Segmentación de Prospectos en Asesoría Académica

---

### A. CANAL CONVERSACIONAL WHATSAPP (PROSPECTO - SIN LOGIN)

#### 1. Recepción de mensajes y bienvenida con el agente "Vicky"

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(client.on('message') / asegurarConversacion())*

```javascript
// bot.js - Captura de mensajes entrantes y bienvenida del agente Vicky
client.on('message', async (msg) => {
    try {
        // Ignorar mensajes grupales o de estado de WhatsApp
        if (msg.from.includes('@g.us') || msg.from === 'status@broadcast') return;

        const rawPhone = msg.from.replace('@c.us', '').trim();
        const userMessage = (msg.body || '').trim();
        if (!userMessage) return;

        console.log(`[WHATSAPP IN] De: ${rawPhone} | Mensaje: "${userMessage}"`);

        // 1. Asegurar la conversación y el contacto en SQL Server
        const convData = await asegurarConversacion(rawPhone);
        const conversacionId = convData.conversacionId;

        // 2. Registrar el mensaje entrante en la tabla MENSAJE
        await registrarMensajeEnBD(conversacionId, 'PROSPECTO', userMessage);

        // 3. Procesar intención del estudiante mediante el agente Vicky
        const respuestaAgente = await procesarMensajeConGrok(rawPhone, userMessage);

        // 4. Enviar la respuesta generada al estudiante por WhatsApp
        if (respuestaAgente && respuestaAgente.trim()) {
            await client.sendMessage(msg.from, respuestaAgente);
            await registrarMensajeEnBD(conversacionId, 'AGENTE_VICKY', respuestaAgente);
            console.log(`[WHATSAPP OUT] Respuesta enviada a ${rawPhone}`);
        }
    } catch (err) {
        console.error(`[ERROR BOT] Fallo al procesar mensaje de ${msg.from}:`, err.message);
    }
});

async function asegurarConversacion(whatsappNumber) {
    const pool = await getDbPool();
    const cleanPhone = String(whatsappNumber).replace(/\D/g, '');

    // Buscar contacto existente o registrar nuevo prospecto
    let contactoRes = await pool.request()
        .input('telefono', sql.VarChar(50), cleanPhone)
        .query('SELECT id_contacto, nombre_completo FROM CONTACTO WHERE telefono = @telefono');

    let contactoId;
    if (contactoRes.recordset.length === 0) {
        let insertRes = await pool.request()
            .input('telefono', sql.VarChar(50), cleanPhone)
            .input('nombre', sql.VarChar(150), `Prospecto ${cleanPhone.slice(-4)}`)
            .query(`INSERT INTO CONTACTO (nombre_completo, telefono, canal_origen, fecha_registro, estado_interaccion)
                    OUTPUT INSERTED.id_contacto
                    VALUES (@nombre, @telefono, 'WHATSAPP', GETDATE(), 'INICIADO')`);
        contactoId = insertRes.recordset[0].id_contacto;
    } else {
        contactoId = contactoRes.recordset[0].id_contacto;
    }

    // Obtener o inicializar conversacion activa en SQL Server
    let convRes = await pool.request()
        .input('id_contacto', sql.Int, contactoId)
        .query("SELECT TOP 1 id_conversacion FROM CONVERSACION WHERE id_contacto = @id_contacto AND estado = 'ABIERTA'");

    if (convRes.recordset.length === 0) {
        let newConv = await pool.request()
            .input('id_contacto', sql.Int, contactoId)
            .query(`INSERT INTO CONVERSACION (id_contacto, fecha_inicio, estado, agente_asignado)
                    OUTPUT INSERTED.id_conversacion
                    VALUES (@id_contacto, GETDATE(), 'ABIERTA', 'Vicky')`);
        return { contactoId, conversacionId: newConv.recordset[0].id_conversacion };
    }
    return { contactoId, conversacionId: convRes.recordset[0].id_conversacion };
}
```

Descripción: se muestra el código para procesar los mensajes entrantes de WhatsApp en tiempo real, registrando automáticamente al estudiante en las tablas CONTACTO y CONVERSACION de SQL Server y activando la bienvenida del agente Vicky sin requerir autenticación.

---

#### 2. Extracción y verificación de cobertura de universidad y carrera

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(verificarCobertura())*

```javascript
// bot.js - Verificación de reglas de cobertura académica en SQL Server
async function verificarCobertura({ universidad, carrera }) {
    try {
        const pool = await getDbPool();
        console.log(`[COBERTURA] Evaluando: Universidad='${universidad}' | Carrera='${carrera}'`);

        const uniNorm = (universidad || '').trim();
        const carNorm = (carrera || '').trim();

        // Consulta de validación cruzada sobre las tablas UNIVERSIDAD y CARRERA
        const result = await pool.request()
            .input('uni', sql.NVarChar(150), `%${uniNorm}%`)
            .input('car', sql.NVarChar(150), `%${carNorm}%`)
            .query(`
                SELECT 
                    u.id_universidad,
                    u.nombre AS universidad_oficial,
                    u.tiene_cobertura AS uni_cobertura,
                    c.id_carrera,
                    c.nombre AS carrera_oficial,
                    c.tiene_cobertura AS car_cobertura
                FROM UNIVERSIDAD u
                CROSS JOIN CARRERA c
                WHERE (u.nombre LIKE @uni OR u.siglas LIKE @uni)
                  AND (c.nombre LIKE @car OR c.area_conocimiento LIKE @car)
            `);

        if (result.recordset.length === 0) {
            // Intentar búsqueda independiente de universidad
            const checkUni = await pool.request()
                .input('uni', sql.NVarChar(150), `%${uniNorm}%`)
                .query('SELECT TOP 1 id_universidad, nombre, tiene_cobertura FROM UNIVERSIDAD WHERE nombre LIKE @uni OR siglas LIKE @uni');

            const tieneUni = checkUni.recordset.length > 0 && checkUni.recordset[0].tiene_cobertura;
            return {
                tieneCobertura: false,
                motivo: tieneUni ? 'Carrera no cubierta en sede institucional' : 'Universidad fuera de cobertura geográfica',
                universidadId: checkUni.recordset[0]?.id_universidad || null,
                carreraId: null
            };
        }

        const match = result.recordset[0];
        const tieneCoberturaTotal = Boolean(match.uni_cobertura && match.car_cobertura);

        return {
            tieneCobertura: tieneCoberturaTotal,
            motivo: tieneCoberturaTotal 
                ? 'Cobertura total aprobada por catálogo institucional' 
                : 'Programa académico sin vacante metodológica activa',
            universidadId: match.id_universidad,
            carreraId: match.id_carrera,
            nombreOficialUni: match.universidad_oficial,
            nombreOficialCar: match.carrera_oficial
        };
    } catch (err) {
        console.error('[ERROR COBERTURA] Fallo en consulta a SQL Server:', err.message);
        return { tieneCobertura: false, motivo: 'Error en consulta de reglas de cobertura', error: err.message };
    }
}
```

Descripción: se muestra el código para validar los datos académicos ingresados por el prospecto frente al catálogo de universidades y carreras en SQL Server, determinando si el estudiante cumple con los criterios de cobertura metodológica institucional.

---

#### 3. Registro transaccional del prospecto clasificado (tabla BUYER)

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(registrarBuyerTransaccional())*

```javascript
// bot.js - Clasificación y registro transaccional en PERFIL_ACADEMICO y BUYER
async function registrarBuyerTransaccional(data) {
    const pool = await getDbPool();
    const transaction = new sql.Transaction(pool);

    try {
        await transaction.begin();

        const {
            contactoId,
            universidadId,
            carreraId,
            universidadDeclarada,
            carreraDeclarada,
            gradoAcademico = 'PREGRADO',
            faseTesis = 'PLAN_DE_TESIS',
            tieneCobertura,
            motivoClasificacion
        } = data;

        // 1. Upsert en PERFIL_ACADEMICO mediante MERGE en SQL Server
        await transaction.request()
            .input('id_contacto', sql.Int, contactoId)
            .input('id_universidad', sql.Int, universidadId)
            .input('id_carrera', sql.Int, carreraId)
            .input('uni_dec', sql.VarChar(150), universidadDeclarada)
            .input('car_dec', sql.VarChar(150), carreraDeclarada)
            .input('grado', sql.VarChar(50), gradoAcademico)
            .input('fase', sql.VarChar(50), faseTesis)
            .query(`
                MERGE INTO PERFIL_ACADEMICO AS target
                USING (SELECT @id_contacto AS id_contacto) AS source
                ON (target.id_contacto = source.id_contacto)
                WHEN MATCHED THEN
                    UPDATE SET id_universidad = @id_universidad, id_carrera = @id_carrera,
                               universidad_declarada = @uni_dec, carrera_declarada = @car_dec,
                               grado_academico = @grado, fase_tesis = @fase, fecha_actualizacion = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (id_contacto, id_universidad, id_carrera, universidad_declarada, carrera_declarada, grado_academico, fase_tesis, fecha_actualizacion)
                    VALUES (@id_contacto, @id_universidad, @id_carrera, @uni_dec, @car_dec, @grado, @fase, GETDATE());
            `);

        // 2. Determinar estado y score de prioridad
        const estadoBuyer = tieneCobertura ? 'ACTIVO' : 'SIN_COBERTURA';
        const scorePrioridad = tieneCobertura ? 85.0 : 10.0;

        // 3. Upsert en la tabla BUYER
        await transaction.request()
            .input('id_contacto', sql.Int, contactoId)
            .input('estado', sql.VarChar(50), estadoBuyer)
            .input('score', sql.Decimal(5, 2), scorePrioridad)
            .input('motivo', sql.VarChar(255), motivoClasificacion || `Evaluado por Vicky: ${estadoBuyer}`)
            .query(`
                MERGE INTO BUYER AS target
                USING (SELECT @id_contacto AS id_contacto) AS source
                ON (target.id_contacto = source.id_contacto)
                WHEN MATCHED THEN
                    UPDATE SET estado = @estado, score_prioridad = @score, motivo_clasificacion = @motivo, fecha_clasificacion = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (id_contacto, estado, score_prioridad, motivo_clasificacion, fecha_clasificacion)
                    VALUES (@id_contacto, @estado, @score, @motivo, GETDATE());
            `);

        await transaction.commit();
        console.log(`[BUYER OK] Contacto ${contactoId} clasificado como: ${estadoBuyer}`);
        return { success: true, estado: estadoBuyer, score: scorePrioridad };
    } catch (err) {
        await transaction.rollback();
        console.error('[ERROR TRANSACCIONAL BUYER]:', err.message);
        throw err;
    }
}
```

Descripción: se muestra el código para registrar transaccionalmente la segmentación del prospecto en las tablas PERFIL_ACADEMICO y BUYER de SQL Server, asignando el estado ACTIVO o SIN_COBERTURA junto a su puntaje de prioridad.

---

### B. SERVICIOS BACKEND API REST (SQL SERVER)

#### 4. Cálculo de Indicadores BI (KPIs B01, B02, B06, B07)

**ACÁ COLOCAR IMAGEN del archivo server_dashboard.js**  
*(app.get('/api/kpis'))*

```javascript
// server_dashboard.js - Endpoint analítico para cálculo de KPIs B01, B02, B06 y B07
app.get('/api/kpis', async (req, res) => {
    try {
        const pool = await getPool();

        // 1. Consulta analítica consolidada de volúmenes de captación y cobertura
        const kpiQuery = `
            SELECT 
                COUNT(c.id_contacto) AS total_contactos,
                SUM(CASE WHEN b.estado = 'ACTIVO' THEN 1 ELSE 0 END) AS buyers_activos,
                SUM(CASE WHEN b.estado = 'SIN_COBERTURA' THEN 1 ELSE 0 END) AS sin_cobertura,
                SUM(CASE WHEN pa.id_perfil IS NOT NULL THEN 1 ELSE 0 END) AS evaluados
            FROM CONTACTO c
            LEFT JOIN PERFIL_ACADEMICO pa ON c.id_contacto = pa.id_contacto
            LEFT JOIN BUYER b ON c.id_contacto = b.id_contacto
        `;
        const result = await pool.request().query(kpiQuery);
        const data = result.recordset[0] || {};

        const totalContactos = data.total_contactos || 0;
        const buyersActivos = data.buyers_activos || 0;
        const sinCobertura = data.sin_cobertura || 0;
        const evaluados = data.evaluados || 0;

        // KPI B01: Tasa de Conversión (Leads Calificados vs Total Contactos)
        const tasaConversion = totalContactos > 0 
            ? ((buyersActivos / totalContactos) * 100).toFixed(1) 
            : 0;

        // KPI B02: Tasa de Interacción de Valor (% Evaluados vs Total Contactos)
        const tasaInteraccion = totalContactos > 0 
            ? ((evaluados / totalContactos) * 100).toFixed(1) 
            : 0;

        // KPI B06: Demanda Fuera de Cobertura (Conteo en lista de espera)
        const fueraCobertura = sinCobertura;

        // KPI B07: Costo por Prospecto (Inversión estimada / Contactos calificados)
        const inversionEstimada = 120.00; // S/. presupuesto asignado
        const costoPorLead = buyersActivos > 0 
            ? (inversionEstimada / buyersActivos).toFixed(2) 
            : '0.00';

        // 2. Respuesta estructurada para las tarjetas de React
        res.json({
            kpi_b01: { valor: `${tasaConversion}%`, label: 'Tasa de Conversión', detalle: `${buyersActivos} de ${totalContactos} buyers calificados` },
            kpi_b02: { valor: `${tasaInteraccion}%`, label: 'Interacción de Valor', detalle: `${evaluados} con perfil académico completo` },
            kpi_b06: { valor: fueraCobertura, label: 'Fuera de Cobertura', detalle: 'Prospectos en lista de espera preferencial' },
            kpi_b07: { valor: `S/. ${costoPorLead}`, label: 'Costo por Prospecto', detalle: `Basado en S/. ${inversionEstimada} de inversión` },
            resumen: { totalContactos, buyersActivos, sinCobertura, evaluados }
        });
    } catch (err) {
        console.error('[API ERROR] Error en /api/kpis:', err.message);
        res.status(500).json({ error: 'Fallo al consultar métricas analíticas en SQL Server' });
    }
});
```

Descripción: se muestra el código para procesar los indicadores de inteligencia de negocios B01, B02, B06 y B07 sobre Microsoft SQL Server, entregando en formato JSON las métricas que alimentan las tarjetas del dashboard en tiempo real.

---

#### 5. Consulta y sincronización de trazabilidad de prospectos

**ACÁ COLOCAR IMAGEN del archivo server_dashboard.js**  
*(app.get('/api/buyers'))*

```javascript
// server_dashboard.js - Endpoint para listar la trazabilidad completa de prospectos
app.get('/api/buyers', async (req, res) => {
    try {
        const pool = await getPool();

        // Consulta relacional uniendo CONTACTO, PERFIL_ACADEMICO, BUYER y UNIVERSIDAD
        const query = `
            SELECT 
                b.id_buyer,
                c.id_contacto,
                c.nombre_completo,
                c.telefono,
                ISNULL(u.nombre, pa.universidad_declarada) AS universidad,
                ISNULL(car.nombre, pa.carrera_declarada) AS carrera,
                pa.fase_tesis,
                b.estado,
                b.score_prioridad,
                b.motivo_clasificacion,
                FORMAT(b.fecha_clasificacion, 'yyyy-MM-dd HH:mm') AS fecha_registro
            FROM BUYER b
            INNER JOIN CONTACTO c ON b.id_contacto = c.id_contacto
            LEFT JOIN PERFIL_ACADEMICO pa ON c.id_contacto = pa.id_contacto
            LEFT JOIN UNIVERSIDAD u ON pa.id_universidad = u.id_universidad
            LEFT JOIN CARRERA car ON pa.id_carrera = car.id_carrera
            ORDER BY b.fecha_clasificacion DESC
        `;

        const result = await pool.request().query(query);

        const buyersFormat = result.recordset.map(row => ({
            id: row.id_buyer,
            contactoId: row.id_contacto,
            nombre: row.nombre_completo,
            telefono: row.telefono,
            universidad: row.universidad || 'No especificada',
            carrera: row.carrera || 'No especificada',
            faseTesis: row.fase_tesis || 'En consulta inicial',
            estado: row.estado,
            score: row.score_prioridad,
            motivo: row.motivo_clasificacion,
            fecha: row.fecha_registro
        }));

        res.json(buyersFormat);
    } catch (err) {
        console.error('[API ERROR] Error en /api/buyers:', err.message);
        res.status(500).json({ error: 'Fallo al consultar la trazabilidad de buyers' });
    }
});
```

Descripción: se muestra el código para consultar y transformar la trazabilidad de los prospectos almacenados en SQL Server, uniendo las tablas BUYER, CONTACTO y PERFIL_ACADEMICO para alimentar la tabla de seguimiento del administrador.

---

### C. PANEL ADMINISTRATIVO - GESTIÓN Y ANALÍTICA (REACT)

#### 6. Componente de Resumen Ejecutivo y Cuadro de Mando BI

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/KpiCards.jsx**  
*(KpiCards({ kpis }))*

```javascript
// frontend/src/components/KpiCards.jsx - Renderizado de tarjetas de KPIs ejecutivos
import React from 'react';

export default function KpiCards({ kpis }) {
  if (!kpis) return null;

  const cards = [
    {
      kpiId: 'B01',
      title: 'Tasa de Conversión',
      value: kpis.kpi_b01?.valor || '0.0%',
      detalle: kpis.kpi_b01?.detalle,
      color: 'border-l-indigo-500 text-indigo-600',
      badge: 'bg-indigo-50 text-indigo-700',
      icon: '🎯'
    },
    {
      kpiId: 'B02',
      title: 'Interacción de Valor',
      value: kpis.kpi_b02?.valor || '0.0%',
      detalle: kpis.kpi_b02?.detalle,
      color: 'border-l-emerald-500 text-emerald-600',
      badge: 'bg-emerald-50 text-emerald-700',
      icon: '⚡'
    },
    {
      kpiId: 'B06',
      title: 'Fuera de Cobertura',
      value: kpis.kpi_b06?.valor || '0',
      detalle: kpis.kpi_b06?.detalle,
      color: 'border-l-rose-500 text-rose-600',
      badge: 'bg-rose-50 text-rose-700',
      icon: '🚫'
    },
    {
      kpiId: 'B07',
      title: 'Costo por Prospecto',
      value: kpis.kpi_b07?.valor || 'S/. 0.00',
      detalle: kpis.kpi_b07?.detalle,
      color: 'border-l-amber-500 text-amber-600',
      badge: 'bg-amber-50 text-amber-700',
      icon: '💰'
    }
  ];

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      {cards.map((c) => (
        <div
          key={c.kpiId}
          className={`bg-white rounded-xl shadow-sm border border-slate-200 border-l-4 ${c.color} p-5 transition hover:shadow-md`}
        >
          <div className="flex items-center justify-between">
            <span className={`px-2 py-0.5 rounded text-xs font-bold ${c.badge}`}>
              KPI {c.kpiId}
            </span>
            <span className="text-xl">{c.icon}</span>
          </div>
          <h3 className="text-xs font-semibold text-slate-500 uppercase tracking-wider mt-3">
            {c.title}
          </h3>
          <div className="text-2xl font-black text-slate-800 mt-1">
            {c.value}
          </div>
          <p className="text-xs text-slate-500 mt-2 truncate">
            {c.detalle}
          </p>
        </div>
      ))}
    </div>
  );
}
```

Descripción: se muestra el código para renderizar las cuatro tarjetas de indicadores clave de rendimiento (B01, B02, B06 y B07) en la interfaz de React, formateando los valores analíticos y sus etiquetas de estado de manera reactiva.

---

#### 7. Componente de Trazabilidad y Búsqueda de Buyers

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/BuyersTable.jsx**  
*(BuyersTable({ buyers, searchTerm, setSearchTerm, filterStatus, setFilterStatus, onOpenChat }))*

```javascript
// frontend/src/components/BuyersTable.jsx - Tabla interactiva de trazabilidad y filtrado
import React, { useMemo } from 'react';

export default function BuyersTable({
  buyers = [],
  searchTerm,
  setSearchTerm,
  filterStatus,
  setFilterStatus,
  onOpenChat
}) {
  // Filtrado reactivo en memoria por texto y estado
  const filteredBuyers = useMemo(() => {
    return buyers.filter((b) => {
      const matchSearch =
        searchTerm === '' ||
        b.nombre?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        b.telefono?.includes(searchTerm) ||
        b.universidad?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        b.carrera?.toLowerCase().includes(searchTerm.toLowerCase());

      const matchStatus =
        filterStatus === 'ALL' ||
        (filterStatus === 'ACTIVO' && b.estado === 'ACTIVO') ||
        (filterStatus === 'SIN_COBERTURA' && b.estado === 'SIN_COBERTURA');

      return matchSearch && matchStatus;
    });
  }, [buyers, searchTerm, filterStatus]);

  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden">
      {/* Barra de Filtros y Búsqueda */}
      <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row justify-between items-center gap-3">
        <input
          type="text"
          placeholder="Buscar por nombre, teléfono, universidad..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full sm:w-80 px-4 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
        />
        <div className="flex space-x-2">
          {['ALL', 'ACTIVO', 'SIN_COBERTURA'].map((st) => (
            <button
              key={st}
              onClick={() => setFilterStatus(st)}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold transition ${
                filterStatus === st
                  ? 'bg-indigo-600 text-white'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {st === 'ALL' ? 'Todos' : st === 'ACTIVO' ? 'Con Cobertura' : 'Sin Cobertura'}
            </button>
          ))}
        </div>
      </div>

      {/* Tabla de Datos */}
      <div className="overflow-x-auto">
        <table className="w-full text-left text-sm text-slate-600">
          <thead className="bg-slate-50 text-xs uppercase font-bold text-slate-500 border-b border-slate-200">
            <tr>
              <th className="py-3 px-4">Estudiante</th>
              <th className="py-3 px-4">Universidad</th>
              <th className="py-3 px-4">Carrera</th>
              <th className="py-3 px-4">Estado</th>
              <th className="py-3 px-4 text-center">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {filteredBuyers.map((b) => (
              <tr key={b.id} className="hover:bg-slate-50 transition">
                <td className="py-3 px-4 font-semibold text-slate-800">{b.nombre}</td>
                <td className="py-3 px-4">{b.universidad}</td>
                <td className="py-3 px-4">{b.carrera}</td>
                <td className="py-3 px-4">
                  <span className={`px-2.5 py-1 rounded-full text-xs font-bold ${
                    b.estado === 'ACTIVO' ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                  }`}>
                    {b.estado}
                  </span>
                </td>
                <td className="py-3 px-4 text-center">
                  <button
                    onClick={() => onOpenChat(b.telefono)}
                    className="px-3 py-1 bg-indigo-50 text-indigo-600 rounded-md text-xs font-bold hover:bg-indigo-100 transition"
                  >
                    💬 Chat
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

Descripción: se muestra el código para desplegar la tabla interactiva de prospectos clasificados, implementando filtros reactivos en memoria por texto y estado de cobertura, además del enlace directo a la auditoría del chat de WhatsApp.

---

#### 8. Componente de Auditoría de WhatsApp en Vivo

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/ChatAuditor.jsx**  
*(ChatAuditor({ conversaciones, buyers, selectedPhone, setSelectedPhone }))*

```javascript
// frontend/src/components/ChatAuditor.jsx - Consola en vivo estilo WhatsApp Web
import React, { useMemo, useEffect, useRef } from 'react';

export default function ChatAuditor({
  conversaciones = [],
  buyers = [],
  selectedPhone,
  setSelectedPhone
}) {
  const chatBottomRef = useRef(null);

  // Ordenar chats con el mensaje más reciente en el tope (#1 descendente)
  const sortedConversaciones = useMemo(() => {
    return [...conversaciones].sort((a, b) => (b.ultimoMensajeId || 0) - (a.ultimoMensajeId || 0));
  }, [conversaciones]);

  const activeChat = useMemo(() => {
    if (!selectedPhone && sortedConversaciones.length > 0) {
      return sortedConversaciones[0];
    }
    return sortedConversaciones.find((c) => c.telefono === selectedPhone) || sortedConversaciones[0];
  }, [sortedConversaciones, selectedPhone]);

  useEffect(() => {
    chatBottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [activeChat]);

  return (
    <div className="bg-white rounded-xl shadow-sm border border-slate-200 overflow-hidden h-[600px] flex">
      {/* Columna Izquierda: Lista de Contactos WhatsApp */}
      <div className="w-1/3 border-r border-slate-200 flex flex-col bg-slate-50">
        <div className="p-3 bg-slate-100 font-bold text-sm text-slate-700 border-b border-slate-200">
          Chats Recientes ({sortedConversaciones.length})
        </div>
        <div className="flex-1 overflow-y-auto divide-y divide-slate-100">
          {sortedConversaciones.map((conv) => (
            <div
              key={conv.id_conversacion}
              onClick={() => setSelectedPhone(conv.telefono)}
              className={`p-3 cursor-pointer transition flex items-center justify-between ${
                activeChat?.id_conversacion === conv.id_conversacion ? 'bg-indigo-50 border-r-4 border-indigo-600' : 'hover:bg-slate-100'
              }`}
            >
              <div>
                <p className="font-semibold text-slate-800 text-sm">{conv.nombre_completo}</p>
                <p className="text-xs text-slate-400 truncate w-40">{conv.ultimo_mensaje || 'Conversación iniciada'}</p>
              </div>
              <span className="text-[10px] text-slate-400">{conv.hora_ultimo_msg || ''}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Columna Derecha: Ventana de Chat en Vivo */}
      <div className="w-2/3 flex flex-col bg-[#e5ddd5]/30">
        <div className="p-3 bg-white border-b border-slate-200 flex justify-between items-center shadow-sm">
          <div>
            <h4 className="font-bold text-sm text-slate-800">{activeChat?.nombre_completo}</h4>
            <p className="text-xs text-emerald-600 font-semibold">● Vicky (Agente IA Activo)</p>
          </div>
          <span className="text-xs bg-slate-100 px-2.5 py-1 rounded-full font-bold text-slate-600">
            {activeChat?.telefono}
          </span>
        </div>

        {/* Historial de Mensajes */}
        <div className="flex-1 p-4 overflow-y-auto space-y-3">
          {activeChat?.mensajes?.map((m) => {
            const isBot = m.remitente === 'AGENTE_VICKY';
            return (
              <div key={m.id_mensaje} className={`flex ${isBot ? 'justify-start' : 'justify-end'}`}>
                <div className={`max-w-[75%] p-3 rounded-2xl shadow-sm text-sm ${
                  isBot ? 'bg-white text-slate-800 rounded-tl-none' : 'bg-[#dcf8c6] text-slate-900 rounded-tr-none'
                }`}>
                  <p className="text-xs font-bold text-slate-500 mb-1">{isBot ? '🤖 Vicky' : '👤 Estudiante'}</p>
                  <p>{m.contenido}</p>
                  <span className="text-[10px] text-slate-400 block text-right mt-1">{m.hora}</span>
                </div>
              </div>
            );
          })}
          <div ref={chatBottomRef} />
        </div>
      </div>
    </div>
  );
}
```

Descripción: se muestra el código para auditar las conversaciones en tiempo real entre el agente Vicky y los estudiantes, renderizando una interfaz idéntica a WhatsApp Web ordenada de forma descendente según la última interacción.
