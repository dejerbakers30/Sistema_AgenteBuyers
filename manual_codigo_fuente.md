# MANUAL DE CÓDIGO FUENTE

## Agente Conversacional con IA para la Atracción, Filtro de Cobertura y Segmentación de Prospectos en Asesoría Académica

---

### A. CANAL CONVERSACIONAL WHATSAPP (PROSPECTO - SIN LOGIN)

#### 1. Recepción de mensajes y registro en SQL Server

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(asegurarConversacion() (líneas 432–488))*

```javascript
async function asegurarConversacion(whatsappNumber) {
    try {
        const pool = await getDbPool();

        // Buscar o crear CONTACTO temporal
        let ctRes = await pool.request()
            .input('wa', sql.VarChar(30), whatsappNumber)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @wa`);

        let contactoId;
        if (ctRes.recordset.length > 0) {
            contactoId = ctRes.recordset[0].contacto_id;
        } else {
            const insRes = await pool.request()
                .input('wa', sql.VarChar(30), whatsappNumber)
                .query(`
                    INSERT INTO CONTACTO (
                        nombres, whatsapp,
                        consentimiento_contacto, fecha_registro, estado
                    ) VALUES (
                        'Estudiante WhatsApp', @wa,
                        1, SYSDATETIME(), 'ACTIVO'
                    );
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = insRes.recordset[0].contacto_id;
        }

        // Buscar conversación EN_CURSO o crear una nueva
        const convRes = await pool.request()
            .input('cid', sql.Int, contactoId)
            .query(`
                SELECT TOP 1 conversacion_id
                FROM CONVERSACION
                WHERE contacto_id = @cid AND estado = 'EN_CURSO'
                ORDER BY conversacion_id DESC
            `);

        if (convRes.recordset.length > 0) {
            return { contactoId, conversacionId: convRes.recordset[0].conversacion_id };
        }

        const newConv = await pool.request()
            .input('cid', sql.Int, contactoId)
            .query(`
                INSERT INTO CONVERSACION (
                    contacto_id, canal_id, campania_id,
                    fecha_inicio, resuelta_sin_humano, estado
                ) VALUES (
                    @cid, 1, NULL,
                    SYSDATETIME(), 1, 'EN_CURSO'
                );
                SELECT SCOPE_IDENTITY() AS conversacion_id;
            `);

        return { contactoId, conversacionId: newConv.recordset[0].conversacion_id };
```

Descripción: se muestra el código para asegurar la conversación y el contacto en SQL Server, consultando mediante @wa en la tabla CONTACTO e inicializando un registro en CONVERSACION en estado EN_CURSO si no existe.

---

#### 2. Verificación de reglas de cobertura académica

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(verificarCobertura() (líneas 173–238))*

```javascript
async function verificarCobertura({ universidad, carrera }) {
    console.log(`\n🔍 [verificar_cobertura] "${universidad}" | "${carrera}"`);
    try {
        const pool    = await getDbPool();
        const uFiltro = `%${universidad.trim()}%`;
        const cFiltro = `%${carrera.trim()}%`;

        // ── Fase 1: JOIN directo ──────────────────────────────────────────────
        const joinResult = await pool.request()
            .input('uFiltro', sql.VarChar(150), uFiltro)
            .input('cFiltro', sql.VarChar(150), cFiltro)
            .query(`
                SELECT TOP 1
                    u.universidad_id,
                    u.nombre     AS universidad_nombre,
                    u.atendida   AS universidad_atendida,
                    c.carrera_id,
                    c.nombre     AS carrera_nombre,
                    c.atendida   AS carrera_atendida
                FROM UNIVERSIDAD u
                INNER JOIN CARRERA c ON c.universidad_id = u.universidad_id
                WHERE u.nombre LIKE @uFiltro
                  AND c.nombre LIKE @cFiltro;
            `);

        if (joinResult.recordset.length > 0) {
            const row       = joinResult.recordset[0];
            const cobertura = !!(row.universidad_atendida) && !!(row.carrera_atendida);
            console.log(`   → JOIN directo: ${cobertura ? '✅ ACTIVA' : '⚠️ SIN COBERTURA'} (${row.universidad_nombre} - ${row.carrera_nombre})`);
            return {
                encontrado         : true,
                universidad_id     : row.universidad_id,
                universidad_nombre : row.universidad_nombre,
                carrera_id         : row.carrera_id,
                carrera_nombre     : row.carrera_nombre,
                cobertura,
                mensaje: cobertura
                    ? `Cobertura activa para ${row.carrera_nombre} en ${row.universidad_nombre}.`
                    : `La carrera o universidad no está atendida actualmente.`,
            };
        }

        // ── Fase 2: búsquedas independientes ─────────────────────────────────
        const [uRes, cRes] = await Promise.all([
            pool.request()
                .input('uFiltro', sql.VarChar(150), uFiltro)
                .query(`SELECT TOP 1 universidad_id, nombre, atendida FROM UNIVERSIDAD WHERE nombre LIKE @uFiltro`),
            pool.request()
                .input('cFiltro', sql.VarChar(150), cFiltro)
                .query(`SELECT TOP 1 carrera_id, universidad_id, nombre, atendida FROM CARRERA WHERE nombre LIKE @cFiltro`),
        ]);

        const uFound = uRes.recordset[0] || null;
        const cFound = cRes.recordset[0] || null;

        if (uFound && cFound) {
            const cobertura = !!(uFound.atendida) && !!(cFound.atendida);
            console.log(`   → Búsqueda independiente: ${cobertura ? '✅ ACTIVA' : '⚠️ SIN COBERTURA'}`);
            return {
                encontrado         : true,
                universidad_id     : uFound.universidad_id,
                universidad_nombre : uFound.nombre,
                carrera_id         : cFound.carrera_id,
                carrera_nombre     : cFound.nombre,
                cobertura,
                mensaje: cobertura
```

Descripción: se muestra el código para validar la universidad y carrera frente a las tablas UNIVERSIDAD y CARRERA en SQL Server, comprobando el campo relacional atendida para determinar si existe cobertura activa.

---

#### 3. Registro transaccional del prospecto clasificado (tabla BUYER)

**ACÁ COLOCAR IMAGEN del archivo bot.js**  
*(registrarBuyerTransaccional() (líneas 272–405))*

```javascript
async function registrarBuyerTransaccional(data) {
    console.log(`\n📝 [registrar_buyer] Iniciando transacción para: ${data.nombres} (${data.whatsapp})`);
    const pool        = await getDbPool();
    const transaction = new sql.Transaction(pool);

    try {
        await transaction.begin();

        // ── 1. CONTACTO ───────────────────────────────────────────────────────
        const checkContacto = await new sql.Request(transaction)
            .input('whatsapp', sql.VarChar(30), data.whatsapp)
            .query(`SELECT contacto_id FROM CONTACTO WHERE whatsapp = @whatsapp`);

        let contactoId;

        if (checkContacto.recordset.length > 0) {
            // Ya existe: actualizar nombre si se conoce más información
            contactoId = checkContacto.recordset[0].contacto_id;
            await new sql.Request(transaction)
                .input('contacto_id', sql.Int,       contactoId)
                .input('nombres',     sql.VarChar(100), data.nombres || 'Estudiante')
                .input('apellidos',   sql.VarChar(100), data.apellidos || null)
                .input('correo',      sql.VarChar(150), data.correo   || null)
                .query(`
                    UPDATE CONTACTO
                    SET  nombres   = @nombres,
                         apellidos = @apellidos,
                         correo    = ISNULL(@correo, correo)
                    WHERE contacto_id = @contacto_id
                `);
            console.log(`   ♻️  CONTACTO existente actualizado: ID ${contactoId}`);
        } else {
            // Nuevo contacto
            const insContacto = await new sql.Request(transaction)
                .input('nombres',   sql.VarChar(100),  data.nombres   || 'Estudiante WhatsApp')
                .input('apellidos', sql.VarChar(100),  data.apellidos || null)
                .input('whatsapp',  sql.VarChar(30),   data.whatsapp)
                .input('correo',    sql.VarChar(150),  data.correo    || null)
                .query(`
                    INSERT INTO CONTACTO (
                        nombres, apellidos, whatsapp, correo,
                        consentimiento_contacto, fecha_consentimiento,
                        no_contactar, fecha_registro, estado
                    ) VALUES (
                        @nombres, @apellidos, @whatsapp, @correo,
                        1, SYSDATETIME(),
                        0, SYSDATETIME(), 'ACTIVO'
                    );
                    SELECT SCOPE_IDENTITY() AS contacto_id;
                `);
            contactoId = insContacto.recordset[0].contacto_id;
            console.log(`   ✅ CONTACTO nuevo creado: ID ${contactoId}`);
        }


        // ...
        const estadoBuyer = data.tiene_cobertura ? 'ACTIVO' : 'SIN_COBERTURA';

        const checkBuyer = await new sql.Request(transaction)
            .input('contacto_id', sql.Int, contactoId)
            .query(`SELECT buyer_id, estado FROM BUYER WHERE contacto_id = @contacto_id`);

        let buyerId;

        if (checkBuyer.recordset.length > 0) {
            buyerId = checkBuyer.recordset[0].buyer_id;
            await new sql.Request(transaction)
                .input('buyer_id',  sql.Int,        buyerId)
                .input('estado',    sql.VarChar(30), estadoBuyer)
                .input('necesidad', sql.VarChar(150), (data.necesidad_inicial || 'Asesoría de Tesis').substring(0, 150))
                .query(`
                    UPDATE BUYER
                    SET  estado            = @estado,
                         necesidad_inicial = @necesidad,
                         fecha_buyer       = SYSDATETIME()
                    WHERE buyer_id = @buyer_id
                `);
            console.log(`   ♻️  BUYER actualizado: ID ${buyerId} → ${estadoBuyer}`);
        } else {
            const insBuyer = await new sql.Request(transaction)
                .input('contacto_id',       sql.Int,        contactoId)
                .input('canal_captacion_id', sql.Int,       1)   // WhatsApp orgánico
                .input('servicio_interes_id',sql.Int,       2)   // Proyecto de Tesis
                .input('necesidad_inicial',  sql.VarChar(150), (data.necesidad_inicial || 'Asesoría Integral de Tesis').substring(0, 150))
                .input('estado',             sql.VarChar(30),  estadoBuyer)
                .query(`
                    INSERT INTO BUYER (
                        contacto_id, canal_captacion_id, campania_id,
                        servicio_interes_id, necesidad_inicial,
                        fecha_buyer, estado
                    ) VALUES (
                        @contacto_id, @canal_captacion_id, NULL,
                        @servicio_interes_id, @necesidad_inicial,
                        SYSDATETIME(), @estado
                    );
                    SELECT SCOPE_IDENTITY() AS buyer_id;
                `);
            buyerId = insBuyer.recordset[0].buyer_id;
            console.log(`   ✅ BUYER nuevo: ID ${buyerId} → ${estadoBuyer}`);
        }

        // ── COMMIT atómico ────────────────────────────────────────────────────
        await transaction.commit();
        console.log(`   🎉 Transacción COMMIT OK · BUYER ${buyerId} [${estadoBuyer}]`);
```

Descripción: se muestra el código para registrar de manera atómica al estudiante en CONTACTO, PERFIL_ACADEMICO y BUYER en SQL Server, asignando el estado ACTIVO o SIN_COBERTURA según el resultado de la cobertura.

---

### B. SERVICIOS BACKEND API REST (SQL SERVER)

#### 4. Cálculo de Indicadores BI (KPIs B01, B02, B06, B07)

**ACÁ COLOCAR IMAGEN del archivo server_dashboard.js**  
*(app.get('/api/kpis') (líneas 102–146))*

```javascript
app.get('/api/kpis', async (req, res) => {
    try {
        const p = await getPool();
        const query = `
            SELECT
                total_buyers = (SELECT COUNT(*) FROM BUYER),
                total_leads  = (SELECT COUNT(*) FROM LEAD),
                interacciones_valor = (SELECT COUNT(*) FROM INTERACCION_CAPTACION WHERE es_valor = 1),
                demanda_sin_cobertura = (SELECT COUNT(*) FROM BUYER WHERE estado = 'SIN_COBERTURA'),
                total_inversion = (SELECT ISNULL(SUM(inversion), 0) FROM CAMPANIA);
        `;
        const result = await p.request().query(query);
        const row = result.recordset[0];

        const total_buyers = parseInt(row.total_buyers, 10) || 0;
        const total_leads = parseInt(row.total_leads, 10) || 0;
        const interacciones_valor = parseInt(row.interacciones_valor, 10) || 0;
        const demanda_sin_cobertura = parseInt(row.demanda_sin_cobertura, 10) || 0;
        const total_inversion = parseFloat(row.total_inversion) || 0.0;

        const b01 = total_buyers > 0 ? (total_leads / total_buyers * 100.0) : 0.0;
        const b02 = total_buyers > 0 ? (interacciones_valor / total_buyers * 100.0) : 0.0;
        const b06 = demanda_sin_cobertura;
        const b07 = total_buyers > 0 ? (total_inversion / total_buyers) : 0.0;
        const buyers_activos = total_buyers - demanda_sin_cobertura;
        const tasa_cobertura = total_buyers > 0 ? (buyers_activos / total_buyers * 100.0) : 0.0;

        res.json({
            b01: Number(b01.toFixed(1)),
            b02: Number(b02.toFixed(1)),
            b06: b06,
            b07: Number(b07.toFixed(2)),
            total_buyers,
            total_leads,
            interacciones_valor,
            demanda_sin_cobertura,
            buyers_activos,
            tasa_cobertura: Number(tasa_cobertura.toFixed(1)),
            total_inversion: Number(total_inversion.toFixed(2))
        });
    } catch (err) {
        console.error('❌ [API /kpis] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});
```

Descripción: se muestra el código para procesar los indicadores de inteligencia de negocios B01 (Conversión), B02 (Interacción de valor), B06 (Demanda sin cobertura) y B07 (Costo por Buyer) directamente sobre SQL Server.

---

#### 5. Consulta y sincronización de trazabilidad de prospectos

**ACÁ COLOCAR IMAGEN del archivo server_dashboard.js**  
*(app.get('/api/buyers') (líneas 151–188))*

```javascript
app.get('/api/buyers', async (req, res) => {
    try {
        const p = await getPool();
        const query = `
            SELECT 
                b.buyer_id,
                b.fecha_buyer,
                b.estado AS estado_buyer,
                b.necesidad_inicial,
                c.contacto_id,
                c.nombres,
                c.apellidos,
                CONCAT(c.nombres, CASE WHEN c.apellidos IS NOT NULL AND c.apellidos NOT IN ('', 'Por Asignar') THEN ' ' + c.apellidos ELSE '' END) AS nombre_completo,
                c.whatsapp,
                c.correo,
                pa.etapa_academica,
                pa.ciclo,
                pa.sede,
                cr.carrera_id,
                cr.nombre AS carrera,
                cr.atendida AS carrera_atendida,
                u.universidad_id,
                u.nombre AS universidad,
                u.atendida AS universidad_atendida
            FROM BUYER b
            INNER JOIN CONTACTO c ON c.contacto_id = b.contacto_id
            LEFT JOIN PERFIL_ACADEMICO pa ON pa.contacto_id = c.contacto_id
            LEFT JOIN CARRERA cr ON cr.carrera_id = pa.carrera_id
            LEFT JOIN UNIVERSIDAD u ON u.universidad_id = cr.universidad_id
            ORDER BY b.buyer_id DESC;
        `;
        const result = await p.request().query(query);
        res.json(result.recordset);
    } catch (err) {
        console.error('❌ [API /buyers] Error:', err.message);
        res.status(500).json({ error: err.message });
    }
});
```

Descripción: se muestra el código para consultar la trazabilidad completa de los prospectos almacenados en SQL Server, uniendo las tablas BUYER, CONTACTO, PERFIL_ACADEMICO, CARRERA y UNIVERSIDAD en orden descendente.

---

### C. PANEL ADMINISTRATIVO - GESTIÓN Y ANALÍTICA (REACT)

#### 6. Componente de Resumen Ejecutivo y Cuadro de Mando BI

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/KpiCards.jsx**  
*(KpiCards({ kpis }) (líneas 4–68))*

```javascript
export default function KpiCards({ kpis }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
      {/* KPI B01 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-emerald-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-emerald-600 uppercase tracking-wider bg-emerald-50 px-2 py-0.5 rounded">
              KPI B01 · Oficial
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Tasa Conversión a LEAD</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-600 flex items-center justify-center">
            <UserCheck className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-900">{kpis?.b01}%</span>
          <span className="text-xs text-slate-500 font-medium">efectividad</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-emerald-500 h-2 rounded-full" style={{ width: `${Math.min(kpis?.b01 || 0, 100)}%` }}></div>
        </div>
        <p className="text-xs text-slate-500 mt-3 flex justify-between">
          <span>{kpis?.total_leads} leads generados</span>
          <span className="font-medium text-slate-700">de {kpis?.total_buyers} buyers</span>
        </p>
      </div>

      {/* KPI B02 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-blue-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-blue-600 uppercase tracking-wider bg-blue-50 px-2 py-0.5 rounded">
              KPI B02 · Oficial
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Tasa Interacción de Valor</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-600 flex items-center justify-center">
            <Sparkles className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-900">{kpis?.b02}%</span>
          <span className="text-xs text-slate-500 font-medium">relevancia</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-blue-500 h-2 rounded-full" style={{ width: `${Math.min(kpis?.b02 || 0, 100)}%` }}></div>
        </div>
        <p className="text-xs text-slate-500 mt-3 flex justify-between">
          <span>{kpis?.interacciones_valor} interacciones clave</span>
          <span className="font-medium text-slate-700">en WhatsApp</span>
        </p>
      </div>

      {/* KPI B06 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-rose-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-rose-600 uppercase tracking-wider bg-rose-50 px-2 py-0.5 rounded">
              KPI B06 · Demanda
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Fuera de Cobertura</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-600 flex items-center justify-center">
```

Descripción: se muestra el código para renderizar las tarjetas ejecutivas de los KPIs B01, B02, B06 y B07 en React, desplegando valores porcentuales, barras de progreso y comparativas de efectividad en tiempo real.

---

#### 7. Componente de Trazabilidad y Búsqueda de Buyers

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/BuyersTable.jsx**  
*(BuyersTable(...) (líneas 4–64))*

```javascript
export default function BuyersTable({ buyers, searchTerm, setSearchTerm, filterStatus, setFilterStatus, onOpenChat }) {
  const filtered = useMemo(() => {
    return buyers.filter(b => {
      const matchSearch =
        (b.nombre_completo || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        (b.universidad || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        (b.carrera || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
        (b.whatsapp || '').includes(searchTerm);

      const matchFilter = filterStatus === 'ALL' ? true : b.estado_buyer === filterStatus;
      return matchSearch && matchFilter;
    });
  }, [buyers, searchTerm, filterStatus]);

  return (
    <div className="bg-white rounded-2xl p-6 shadow-sm border border-slate-200 space-y-5">
      <div className="flex flex-col md:flex-row justify-between items-stretch md:items-center gap-4">
        <div>
          <h2 className="text-lg font-bold text-slate-900">Trazabilidad de Prospectos (Fase BUYER)</h2>
          <p className="text-xs text-slate-500">Mostrando {filtered.length} de {buyers.length} registros en SQL Server</p>
        </div>

        <div className="flex flex-col sm:flex-row gap-3">
          <div className="relative">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
            <input
              type="text"
              placeholder="Buscar por nombre, carrera o uni..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 w-full sm:w-64"
            />
          </div>

          <div className="flex rounded-xl bg-slate-100 p-1 border border-slate-200 text-xs font-semibold">
            <button
              onClick={() => setFilterStatus('ALL')}
              className={`px-3 py-1.5 rounded-lg transition ${filterStatus === 'ALL' ? 'bg-white text-slate-900 shadow-sm' : 'text-slate-600'}`}
            >
              Todos
            </button>
            <button
              onClick={() => setFilterStatus('ACTIVO')}
              className={`px-3 py-1.5 rounded-lg transition ${filterStatus === 'ACTIVO' ? 'bg-emerald-600 text-white shadow-sm' : 'text-slate-600'}`}
            >
              Activos
            </button>
            <button
              onClick={() => setFilterStatus('SIN_COBERTURA')}
              className={`px-3 py-1.5 rounded-lg transition ${filterStatus === 'SIN_COBERTURA' ? 'bg-rose-600 text-white shadow-sm' : 'text-slate-600'}`}
            >
              Sin Cobertura
            </button>
          </div>
        </div>
      </div>

      <div className="overflow-x-auto rounded-xl border border-slate-200">
        <table className="w-full text-left text-xs sm:text-sm">
          <thead className="bg-slate-50 border-b border-slate-200 text-slate-500 uppercase text-[11px] font-bold">
            <tr>
```

Descripción: se muestra el código para construir la tabla interactiva de prospectos en React, aplicando filtros reactivos en memoria por nombre, universidad, carrera y estado (ACTIVO / SIN_COBERTURA).

---

#### 8. Componente de Auditoría de WhatsApp en Vivo

**ACÁ COLOCAR IMAGEN del archivo frontend/src/components/ChatAuditor.jsx**  
*(ChatAuditor(...) (líneas 4–62))*

```javascript
export default function ChatAuditor({ conversaciones, buyers, selectedPhone, setSelectedPhone }) {
  // Agrupar mensajes y ordenar desde la última conversación hacia abajo
  const chatsPorTelefono = useMemo(() => {
    const map = {};
    conversaciones.forEach(m => {
      const wa = m.whatsapp;
      if (!map[wa]) {
        map[wa] = {
          whatsapp: wa,
          nombre: m.nombre_completo,
          mensajes: [],
          ultimoTimestamp: 0,
          ultimoMensajeId: 0
        };
      }
      map[wa].mensajes.push(m);
      const msgTime = new Date(m.fecha_mensaje).getTime() || 0;
      if (msgTime >= map[wa].ultimoTimestamp) {
        map[wa].ultimoTimestamp = msgTime;
        map[wa].ultimoMensajeId = m.mensaje_id || 0;
      }
    });

    // Ordenar de la última conversación (más reciente) hacia abajo
    return Object.values(map).sort((a, b) => {
      if (b.ultimoMensajeId !== a.ultimoMensajeId) {
        return b.ultimoMensajeId - a.ultimoMensajeId;
      }
      return b.ultimoTimestamp - a.ultimoTimestamp;
    });
  }, [conversaciones]);

  const activeChat = useMemo(() => {
    if (selectedPhone) {
      return chatsPorTelefono.find(c => c.whatsapp === selectedPhone) || chatsPorTelefono[0];
    }
    return chatsPorTelefono[0] || null;
  }, [chatsPorTelefono, selectedPhone]);

  const messagesEndRef = useRef(null);
  useEffect(() => {
    if (messagesEndRef.current) {
      messagesEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [activeChat, conversaciones]);

  const buyerRelacionado = useMemo(() => {
    if (!activeChat) return null;
    return buyers.find(b => b.whatsapp === activeChat.whatsapp);
  }, [activeChat, buyers]);

  return (
    <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col md:flex-row h-[680px]">
      {/* Lista de Chats */}
      <div className="w-full md:w-80 border-r border-slate-200 bg-white flex flex-col">
        <div className="p-4 border-b border-slate-200 bg-slate-50">
          <h3 className="font-bold text-slate-800 text-sm flex items-center gap-2">
            <MessagesSquare className="w-4 h-4 text-indigo-600" />
            <span>Conversaciones ({chatsPorTelefono.length})</span>
```

Descripción: se muestra el código para auditar las conversaciones de WhatsApp en tiempo real, agrupando los mensajes por número telefónico y ordenándolos cronológicamente desde la interacción más reciente hacia abajo.

---

