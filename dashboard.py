"""
==============================================================================
dashboard.py - DASHBOARD BI EN TIEMPO REAL: FASE BUYER (INBESTIGA)
==============================================================================
Stack: Python + Streamlit + pyodbc + pandas + plotly + python-dotenv
Base de Datos: SQL Server (INBESTIGA_TESIS) - Solo SELECT
==============================================================================
"""

import os
import time
from datetime import datetime, timedelta
import pyodbc
import pandas as pd
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from dotenv import load_dotenv

# Cargar variables de entorno desde .env
load_dotenv()

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN DE PÁGINA Y ESTILOS VISUALES
# ------------------------------------------------------------------------------
st.set_page_config(
    page_title="INBESTIGA BI - Fase BUYER",
    page_icon="🎓",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Inyección de CSS para tarjetas de KPIs y presentación ejecutiva
st.markdown("""
<style>
    .main {
        background-color: #f8fafc;
    }
    .kpi-card {
        background-color: #ffffff;
        border-radius: 12px;
        padding: 20px 24px;
        box-shadow: 0 4px 12px rgba(15, 23, 42, 0.05);
        border: 1px solid #e2e8f0;
        margin-bottom: 16px;
        transition: transform 0.2s ease, box-shadow 0.2s ease;
    }
    .kpi-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 16px rgba(15, 23, 42, 0.09);
    }
    .kpi-card-green {
        border-left: 6px solid #10b981;
    }
    .kpi-card-red {
        border-left: 6px solid #ef4444;
    }
    .kpi-card-blue {
        border-left: 6px solid #2563eb;
    }
    .kpi-code {
        font-size: 0.75rem;
        font-weight: 700;
        letter-spacing: 0.05em;
        text-transform: uppercase;
        margin-bottom: 4px;
    }
    .kpi-code-green { color: #059669; }
    .kpi-code-red { color: #dc2626; }
    .kpi-code-blue { color: #2563eb; }
    
    .kpi-label {
        font-size: 0.88rem;
        font-weight: 600;
        color: #475569;
        margin-bottom: 8px;
    }
    .kpi-value {
        font-size: 2.1rem;
        font-weight: 800;
        line-height: 1.1;
        margin-bottom: 6px;
    }
    .kpi-value-green { color: #047857; }
    .kpi-value-red { color: #b91c1c; }
    .kpi-value-blue { color: #1d4ed8; }

    .kpi-desc {
        font-size: 0.78rem;
        color: #64748b;
    }
</style>
""", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 2. CONEXIÓN A SQL SERVER Y CONSULTAS CACHEADAS
# ------------------------------------------------------------------------------
def get_db_connection():
    """Crea y retorna la conexión a SQL Server usando Autenticación de Windows."""
    server = os.getenv("DB_SERVER", "localhost").strip()
    port = os.getenv("DB_PORT", "1433").strip()
    database = os.getenv("DB_NAME", "INBESTIGA_TESIS").strip()
    driver = os.getenv("DB_DRIVER", "ODBC Driver 17 for SQL Server").strip()
    
    # Sanitizar TrustServerCertificate: ODBC solo acepta 'yes' o 'no'
    raw_trust = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").strip().strip('"').strip("'").lower()
    trust_cert = "yes" if raw_trust in ["true", "1", "yes", "y"] else "no"
    
    # Si es instancia nombrada (ej. localhost\\SQLEXPRESS), no anexar coma de puerto
    if port and "\\" not in server and "," not in server:
        server_str = f"{server},{port}"
    else:
        server_str = server
    
    conn_str = f"DRIVER={{{driver}}};SERVER={server_str};DATABASE={database};Trusted_Connection=yes;TrustServerCertificate={trust_cert};"
    
    try:
        conn = pyodbc.connect(conn_str, timeout=5)
        return conn
    except Exception as e:
        st.error(f"❌ Error al conectar a SQL Server ({database}): {e}")
        st.info("💡 Verifica que el servicio de SQL Server esté iniciado y que el valor de DB_SERVER en el .env sea correcto.")
        return None

@st.cache_data(ttl=2)
def load_kpis():
    """Calcula los indicadores oficiales B01, B02, B06 y B07 de la Fase BUYER."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
        SELECT
            total_buyers = (SELECT COUNT(*) FROM BUYER),
            total_leads  = (SELECT COUNT(*) FROM LEAD),
            interacciones_valor = (SELECT COUNT(*) FROM INTERACCION_CAPTACION WHERE es_valor = 1),
            demanda_sin_cobertura = (SELECT COUNT(*) FROM BUYER WHERE estado = 'SIN_COBERTURA'),
            total_inversion = (SELECT ISNULL(SUM(inversion), 0) FROM CAMPANIA);
        """
        df = pd.read_sql(query, conn)
    finally:
        conn.close()

    total_buyers = int(df['total_buyers'].iloc[0])
    total_leads = int(df['total_leads'].iloc[0])
    interacciones_valor = int(df['interacciones_valor'].iloc[0])
    demanda_sin_cobertura = int(df['demanda_sin_cobertura'].iloc[0])
    total_inversion = float(df['total_inversion'].iloc[0])

    # B01: Tasa de Conversión BUYER -> LEAD (%)
    kpi_b01 = (total_leads / total_buyers * 100.0) if total_buyers > 0 else 0.0
    # B02: Tasa de Interacción de Valor (%)
    kpi_b02 = (interacciones_valor / total_buyers * 100.0) if total_buyers > 0 else 0.0
    # B06: Demanda Fuera de Cobertura (cantidad)
    kpi_b06 = demanda_sin_cobertura
    # B07: Costo por Buyer (S/)
    kpi_b07 = (total_inversion / total_buyers) if total_buyers > 0 else 0.0

    return {
        "b01": kpi_b01,
        "b02": kpi_b02,
        "b06": kpi_b06,
        "b07": kpi_b07,
        "total_buyers": total_buyers,
        "total_leads": total_leads,
        "interacciones_valor": interacciones_valor,
        "total_inversion": total_inversion
    }

@st.cache_data(ttl=2)
def load_buyers_data():
    """Consulta los registros de la tabla BUYER y sus relaciones académicas."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
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
        """
        df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

@st.cache_data(ttl=2)
def load_conversations_data():
    """Consulta los mensajes registrados en la tabla MENSAJE para auditoría."""
    conn = get_db_connection()
    if conn is None:
        return None
    try:
        query = """
        SELECT 
            m.mensaje_id,
            m.conversacion_id,
            m.fecha_mensaje,
            m.emisor,
            m.tipo AS tipo_mensaje,
            m.contenido,
            c.whatsapp,
            CONCAT(c.nombres, ' ', ISNULL(c.apellidos, '')) AS nombre_completo
        FROM MENSAJE m
        INNER JOIN CONVERSACION conv ON conv.conversacion_id = m.conversacion_id
        INNER JOIN CONTACTO c ON c.contacto_id = conv.contacto_id
        ORDER BY m.mensaje_id DESC;
        """
        df = pd.read_sql(query, conn)
        return df
    finally:
        conn.close()

# ------------------------------------------------------------------------------
# 3. SIDEBAR Y AUTO-REFRESCO
# ------------------------------------------------------------------------------
with st.sidebar:
    st.title("🎓 INBESTIGA BI")
    st.caption("Fase BUYER - Monitoreo en Vivo")
    st.markdown("---")

    if st.button("🔄 Refrescar Datos Ahora", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

    auto_refresh = st.checkbox("🔄 Auto-refresco en vivo", value=True)
    st.caption("Intervalo: 3 segundos")

    st.markdown("---")
    timestamp_lectura = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
    st.markdown(f"**Última lectura:**  \n`{timestamp_lectura}`")

# ------------------------------------------------------------------------------
# 4. CARGA DE DATOS CON CONTROL ROBUSTO DE ERRORES
# ------------------------------------------------------------------------------
kpi_data = load_kpis()
df_buyers = load_buyers_data()
df_chat = load_conversations_data()

if kpi_data is None or df_buyers is None or df_chat is None:
    st.stop()

# Encabezado Principal
st.title("📊 Panel de Inteligencia de Negocios - Fase BUYER")
st.markdown("Supervisión de captación de prospectos por WhatsApp, evaluación de cobertura académica y conversión a LEAD.")

# ------------------------------------------------------------------------------
# 5. PARTE SUPERIOR: KPIs EN 4 TARJETAS CON CSS PERSONALIZADO
# ------------------------------------------------------------------------------
col1, col2, col3, col4 = st.columns(4)

with col1:
    st.markdown(f"""
    <div class="kpi-card kpi-card-green">
        <div class="kpi-code kpi-code-green">KPI B01</div>
        <div class="kpi-label">Tasa Conversión BUYER → LEAD</div>
        <div class="kpi-value kpi-value-green">{kpi_data['b01']:.1f}%</div>
        <div class="kpi-desc">{kpi_data['total_leads']} leads de {kpi_data['total_buyers']} buyers</div>
    </div>
    """, unsafe_allow_html=True)

with col2:
    st.markdown(f"""
    <div class="kpi-card kpi-card-green">
        <div class="kpi-code kpi-code-green">KPI B02</div>
        <div class="kpi-label">Tasa Interacción de Valor</div>
        <div class="kpi-value kpi-value-green">{kpi_data['b02']:.1f}%</div>
        <div class="kpi-desc">{kpi_data['interacciones_valor']} interacciones de valor</div>
    </div>
    """, unsafe_allow_html=True)

with col3:
    st.markdown(f"""
    <div class="kpi-card kpi-card-red">
        <div class="kpi-code kpi-code-red">KPI B06</div>
        <div class="kpi-label">Demanda Fuera de Cobertura</div>
        <div class="kpi-value kpi-value-red">{kpi_data['b06']}</div>
        <div class="kpi-desc">Buyers en estado SIN_COBERTURA</div>
    </div>
    """, unsafe_allow_html=True)

with col4:
    st.markdown(f"""
    <div class="kpi-card kpi-card-blue">
        <div class="kpi-code kpi-code-blue">KPI B07</div>
        <div class="kpi-label">Costo por Buyer (CAC)</div>
        <div class="kpi-value kpi-value-blue">S/ {kpi_data['b07']:.2f}</div>
        <div class="kpi-desc">Inversión: S/ {kpi_data['total_inversion']:,.2f}</div>
    </div>
    """, unsafe_allow_html=True)

st.markdown("<br>", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 6. SECCIÓN DE GRÁFICOS (PLOTLY)
# ------------------------------------------------------------------------------
st.subheader("📈 Análisis Dimensional de Captación")

graf_col1, graf_col2 = st.columns([2, 1])

with graf_col1:
    # Gráfico 1: Barras horizontales por Universidad segmentado por estado
    if not df_buyers.empty and 'universidad' in df_buyers.columns:
        df_u = df_buyers.dropna(subset=['universidad']).groupby(['universidad', 'estado_buyer']).size().reset_index(name='cantidad')
        fig_u = px.bar(
            df_u,
            y='universidad',
            x='cantidad',
            color='estado_buyer',
            orientation='h',
            barmode='stack',
            title="Buyers por Universidad (Cobertura vs Sin Cobertura)",
            color_discrete_map={'ACTIVO': '#10b981', 'SIN_COBERTURA': '#ef4444'},
            labels={'universidad': 'Universidad', 'cantidad': 'Total Buyers', 'estado_buyer': 'Estado'}
        )
        fig_u.update_layout(
            margin=dict(l=10, r=20, t=40, b=20),
            height=320,
            yaxis={'categoryorder': 'total ascending'},
            legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
        )
        st.plotly_chart(fig_u, use_container_width=True)
    else:
        st.info("No hay datos suficientes para graficar por universidad.")

with graf_col2:
    # Gráfico 2: Dona - Distribución de Estado de Buyers
    if not df_buyers.empty:
        df_pie = df_buyers['estado_buyer'].value_counts().reset_index()
        df_pie.columns = ['estado_buyer', 'total']
        fig_pie = px.pie(
            df_pie,
            names='estado_buyer',
            values='total',
            hole=0.55,
            title="Distribución de Estado de Buyers",
            color='estado_buyer',
            color_discrete_map={'ACTIVO': '#10b981', 'SIN_COBERTURA': '#ef4444'}
        )
        fig_pie.update_layout(
            margin=dict(l=10, r=10, t=40, b=20),
            height=320,
            legend=dict(orientation="h", yanchor="bottom", y=-0.1, xanchor="center", x=0.5)
        )
        st.plotly_chart(fig_pie, use_container_width=True)
    else:
        st.info("Sin datos para distribución de estado.")

# Gráfico 3: Línea de tiempo - Buyers registrados por día (últimos 30 días)
if not df_buyers.empty:
    df_line = df_buyers.copy()
    df_line['fecha_dia'] = pd.to_datetime(df_line['fecha_buyer']).dt.date
    fecha_limite = (datetime.now() - timedelta(days=30)).date()
    df_line = df_line[df_line['fecha_dia'] >= fecha_limite]

    df_dias = df_line.groupby('fecha_dia').size().reset_index(name='buyers_registrados')
    df_dias['fecha_dia'] = pd.to_datetime(df_dias['fecha_dia'])
    df_dias = df_dias.sort_values('fecha_dia')

    fig_line = px.line(
        df_dias,
        x='fecha_dia',
        y='buyers_registrados',
        markers=True,
        title="Evolución de Buyers Registrados por Día (Últimos 30 días)",
        labels={'fecha_dia': 'Fecha', 'buyers_registrados': 'N° de Buyers'},
        line_shape='linear'
    )
    fig_line.update_traces(line_color='#2563eb', line_width=3, marker=dict(size=8, color='#1d4ed8'))
    fig_line.update_layout(margin=dict(l=20, r=20, t=40, b=20), height=260)
    st.plotly_chart(fig_line, use_container_width=True)

st.markdown("<br>", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 7. TABLA DE TRAZABILIDAD (ÚLTIMOS 15 BUYERS)
# ------------------------------------------------------------------------------
st.subheader("📋 Trazabilidad de Últimos 15 Buyers Registrados")

if not df_buyers.empty:
    df_temp = df_buyers.head(15).copy()
    df_temp['fecha_formateada'] = pd.to_datetime(df_temp['fecha_buyer']).dt.strftime('%d/%m/%Y %H:%M:%S')

    ultimos_15 = df_temp[[
        'buyer_id', 'fecha_formateada', 'nombre_completo', 'whatsapp', 'universidad', 
        'carrera', 'etapa_academica', 'estado_buyer'
    ]].rename(columns={
        'buyer_id': 'ID Buyer',
        'fecha_formateada': 'Fecha y Hora',
        'nombre_completo': 'Estudiante',
        'whatsapp': 'WhatsApp',
        'universidad': 'Universidad',
        'carrera': 'Carrera',
        'etapa_academica': 'Etapa Académica',
        'estado_buyer': 'Estado'
    })

    # Función para dar formato condicional a la columna Estado
    def estilo_estado(val):
        if val == 'ACTIVO':
            return 'background-color: #dcfce7; color: #166534; font-weight: bold;'
        elif val == 'SIN_COBERTURA':
            return 'background-color: #fee2e2; color: #991b1b; font-weight: bold;'
        return ''

    # Compatibilidad con pandas >= 2.1 (map) y versiones anteriores (applymap)
    styler = ultimos_15.style
    if hasattr(styler, "map"):
        styler_formateado = styler.map(estilo_estado, subset=['Estado'])
    else:
        styler_formateado = styler.applymap(estilo_estado, subset=['Estado'])

    st.dataframe(
        styler_formateado,
        use_container_width=True,
        hide_index=True
    )
else:
    st.info("No hay registros en la tabla BUYER.")

st.markdown("<br>", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 8. PESTAÑA DE AUDITORÍA DE CHAT (MENSAJE POR WHATSAPP)
# ------------------------------------------------------------------------------
st.subheader("💬 Auditoría de Interacción WhatsApp en Vivo")
st.caption("Visualiza en tiempo real las consultas que realiza el estudiante y las respuestas generadas por el Agente IA.")

if not df_chat.empty:
    contactos_chat = df_chat[['whatsapp', 'nombre_completo']].drop_duplicates()
    opciones_wa = contactos_chat['whatsapp'].tolist()

    wa_seleccionado = st.selectbox(
        "Seleccione el número de WhatsApp a auditar:",
        options=opciones_wa,
        format_func=lambda w: f"{w} - {contactos_chat[contactos_chat['whatsapp'] == w]['nombre_completo'].values[0]}"
    )

    mensajes_contacto = df_chat[df_chat['whatsapp'] == wa_seleccionado].sort_values('fecha_mensaje', ascending=True)

    with st.container():
        for _, msg in mensajes_contacto.iterrows():
            es_bot = (msg['emisor'] == 'BOT')
            with st.chat_message("assistant" if es_bot else "user"):
                st.markdown(f"**{'🤖 INBESTIGA Bot' if es_bot else '👤 ' + msg['nombre_completo']}**  *({msg['fecha_mensaje']})*")
                st.write(msg['contenido'])
else:
    st.info("Aún no hay mensajes registrados en la tabla MENSAJE.")

# ------------------------------------------------------------------------------
# 9. AUTO-REFRESCO CADA 3 SEGUNDOS
# ------------------------------------------------------------------------------
if auto_refresh:
    time.sleep(3)
    st.rerun()
