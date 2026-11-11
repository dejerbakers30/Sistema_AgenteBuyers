"""
==============================================================================
dashboard.py - DASHBOARD BI EN TIEMPO REAL: FASE BUYER (INBESTIGA)
==============================================================================
Stack: Python + Streamlit + pyodbc + Plotly + Pandas
Fuente de Datos: Conexión directa a INBESTIGA_TESIS (OLTP)
==============================================================================
"""

import os
import time
import pyodbc
import pandas as pd
import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime
from dotenv import load_dotenv
import warnings

# Silenciar advertencia de pandas sobre DBAPI2 (pyodbc)
warnings.filterwarnings('ignore', category=UserWarning, module='pandas')

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

# Inyección de CSS corporativo
st.markdown("""
<style>
    /* Estilos generales */
    .main { background-color: #f8fafc; }
    .metric-card {
        background: white;
        border-radius: 10px;
        padding: 20px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.06);
        border-left: 5px solid #2563eb;
        margin-bottom: 12px;
    }
    .metric-title { font-size: 0.85rem; color: #64748b; font-weight: 600; text-transform: uppercase; }
    .metric-value { font-size: 1.85rem; color: #0f172a; font-weight: 700; margin-top: 4px; }
    .metric-sub { font-size: 0.78rem; color: #10b981; margin-top: 2px; }
    .badge-activo { background-color: #dcfce7; color: #15803d; padding: 4px 10px; border-radius: 12px; font-weight: 600; }
    .badge-sincobertura { background-color: #fee2e2; color: #b91c1c; padding: 4px 10px; border-radius: 12px; font-weight: 600; }
</style>
""", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 2. CONEXIÓN A SQL SERVER
# ------------------------------------------------------------------------------
def get_db_connection():
    server = os.getenv("DB_SERVER", "localhost")
    port = os.getenv("DB_PORT", "1433")
    database = os.getenv("DB_NAME", "INBESTIGA_TESIS")
    user = os.getenv("DB_USER", "sa")
    password = os.getenv("DB_PASSWORD", "")
    driver = os.getenv("DB_ODBC_DRIVER", "ODBC Driver 17 for SQL Server")
    trust_cert_raw = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "yes").lower()
    trust_cert = "yes" if trust_cert_raw in ["true", "yes", "1"] else "no"

    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={server},{port};"
        f"DATABASE={database};"
        f"UID={user};"
        f"PWD={password};"
        f"TrustServerCertificate={trust_cert};"
    )
    try:
        return pyodbc.connect(conn_str, timeout=3)
    except Exception:
        # Fallback a Shared Memory / Local
        conn_str_local = (
            f"DRIVER={{{driver}}};"
            f"SERVER=(local);"
            f"DATABASE={database};"
            f"UID={user};"
            f"PWD={password};"
            f"TrustServerCertificate={trust_cert};"
        )
        return pyodbc.connect(conn_str_local, timeout=5)

@st.cache_data(ttl=2)
def load_buyer_data():
    """Consulta en tiempo real la tabla BUYER y sus relaciones académicas."""
    query = """
    SELECT 
        b.buyer_id,
        b.fecha_buyer,
        b.estado AS estado_buyer,
        b.necesidad_inicial,
        c.contacto_id,
        c.nombres,
        c.apellidos,
        c.whatsapp,
        c.correo,
        pa.etapa_academica,
        pa.ciclo,
        pa.sede,
        pa.tipo_investigacion,
        cr.carrera_id,
        cr.nombre AS carrera,
        cr.atendida AS carrera_atendida,
        u.universidad_id,
        u.nombre AS universidad,
        u.tipo AS tipo_universidad,
        u.atendida AS universidad_atendida,
        cn.nombre AS canal_captacion
    FROM BUYER b
    INNER JOIN CONTACTO c ON c.contacto_id = b.contacto_id
    LEFT JOIN PERFIL_ACADEMICO pa ON pa.contacto_id = c.contacto_id
    LEFT JOIN CARRERA cr ON cr.carrera_id = pa.carrera_id
    LEFT JOIN UNIVERSIDAD u ON u.universidad_id = cr.universidad_id
    LEFT JOIN CANAL cn ON cn.canal_id = b.canal_captacion_id
    ORDER BY b.fecha_buyer DESC;
    """
    conn = get_db_connection()
    df = pd.read_sql(query, conn)
    conn.close()
    return df

@st.cache_data(ttl=2)
def load_conversations_data():
    """Consulta en tiempo real las conversaciones y mensajes del Bot."""
    query = """
    SELECT 
        m.mensaje_id,
        m.conversacion_id,
        m.fecha_mensaje,
        m.emisor,
        m.tipo AS tipo_mensaje,
        m.contenido,
        c.contacto_id,
        c.whatsapp,
        c.nombres,
        conv.resuelta_sin_humano,
        conv.estado AS estado_conversacion
    FROM MENSAJE m
    INNER JOIN CONVERSACION conv ON conv.conversacion_id = m.conversacion_id
    INNER JOIN CONTACTO c ON c.contacto_id = conv.contacto_id
    ORDER BY m.fecha_mensaje DESC;
    """
    conn = get_db_connection()
    df = pd.read_sql(query, conn)
    conn.close()
    return df

# ------------------------------------------------------------------------------
# 3. BARRA LATERAL (FILTROS Y AUTO-REFRESCO)
# ------------------------------------------------------------------------------
with st.sidebar:
    st.image("https://img.icons8.com/fluency/96/graduation-cap.png", width=60)
    st.title("INBESTIGA BI")
    st.caption("Fase BUYER - Prototipo Agente IA")
    st.markdown("---")

    # Mecanismo de refresco en tiempo real
    auto_refresh = st.checkbox("🔄 Auto-refresco en vivo", value=True)
    refresh_rate = st.slider("Intervalo de refresco (segundos)", 2, 30, 5)

    st.markdown("---")
    st.markdown("### ⚙️ Estado de Conexión")
    try:
        test_conn = get_db_connection()
        test_conn.close()
        st.success("🟢 SQL Server: Conectado")
    except Exception as e:
        st.error(f"🔴 SQL Server: Error de conexión")
        st.caption(str(e))

    st.markdown("---")
    st.caption(f"Última lectura: {datetime.now().strftime('%H:%M:%S')}")

# ------------------------------------------------------------------------------
# 4. CARGA DE DATOS Y MÉTRICAS CLAVE (KPIs)
# ------------------------------------------------------------------------------
try:
    df_buyers = load_buyer_data()
    df_chat = load_conversations_data()
except Exception as e:
    st.error(f"⚠️ No se pudo cargar los datos de la base de datos INBESTIGA_TESIS: {e}")
    st.info("Asegúrate de que SQL Server esté corriendo y que hayas configurado el archivo .env.")
    st.stop()

# Encabezado principal
st.title("📊 Panel de Control: Captación de Buyers en Tiempo Real")
st.markdown("Monitoreo continuo de interacciones del Agente IA de WhatsApp, validación de cobertura académica y conversión inicial.")

# Cálculo de KPIs
total_buyers = len(df_buyers)
buyers_activos = len(df_buyers[df_buyers['estado_buyer'] == 'ACTIVO'])
buyers_sin_cobertura = len(df_buyers[df_buyers['estado_buyer'] == 'SIN_COBERTURA'])
pct_cobertura = (buyers_activos / total_buyers * 100) if total_buyers > 0 else 0

total_conv = df_chat['conversacion_id'].nunique() if not df_chat.empty else 0
conv_automatizadas = df_chat[df_chat['resuelta_sin_humano'] == 1]['conversacion_id'].nunique() if not df_chat.empty else 0
pct_automatizacion = (conv_automatizadas / total_conv * 100) if total_conv > 0 else 0

# Fila de Tarjetas KPI
kpi1, kpi2, kpi3, kpi4, kpi5 = st.columns(5)

with kpi1:
    st.markdown(f"""
    <div class="metric-card">
        <div class="metric-title">Total Buyers Registrados</div>
        <div class="metric-value">{total_buyers}</div>
        <div class="metric-sub">Prospectos captados</div>
    </div>
    """, unsafe_allow_html=True)

with kpi2:
    st.markdown(f"""
    <div class="metric-card" style="border-left-color: #10b981;">
        <div class="metric-title">Con Cobertura (ACTIVO)</div>
        <div class="metric-value" style="color: #059669;">{buyers_activos}</div>
        <div class="metric-sub">Califican para asesoría</div>
    </div>
    """, unsafe_allow_html=True)

with kpi3:
    st.markdown(f"""
    <div class="metric-card" style="border-left-color: #ef4444;">
        <div class="metric-title">Sin Cobertura</div>
        <div class="metric-value" style="color: #dc2626;">{buyers_sin_cobertura}</div>
        <div class="metric-sub">En lista de espera</div>
    </div>
    """, unsafe_allow_html=True)

with kpi4:
    st.markdown(f"""
    <div class="metric-card" style="border-left-color: #8b5cf6;">
        <div class="metric-title">Tasa de Cobertura</div>
        <div class="metric-value">{pct_cobertura:.1f}%</div>
        <div class="metric-sub">Efectividad del catálogo</div>
    </div>
    """, unsafe_allow_html=True)

with kpi5:
    st.markdown(f"""
    <div class="metric-card" style="border-left-color: #06b6d4;">
        <div class="metric-title">Resolución Bot 100% IA</div>
        <div class="metric-value">{pct_automatizacion:.1f}%</div>
        <div class="metric-sub">{conv_automatizadas} de {total_conv} chats sin humano</div>
    </div>
    """, unsafe_allow_html=True)

st.markdown("<br>", unsafe_allow_html=True)

# ------------------------------------------------------------------------------
# 5. PESTAÑAS PRINCIPALES DE VISUALIZACIÓN
# ------------------------------------------------------------------------------
tab_graficos, tab_tabla, tab_chat = st.tabs([
    "📈 Gráficos de Inteligencia de Negocios",
    "📋 Registro Detallado de Buyers (En Vivo)",
    "💬 Auditoría de Conversaciones WhatsApp"
])

# ------------------------------------------------------------------------------
# PESTAÑA 1: GRÁFICOS BI
# ------------------------------------------------------------------------------
with tab_graficos:
    c1, c2 = st.columns([1, 2])

    with c1:
        st.subheader("Cobertura Académica")
        if not df_buyers.empty:
            pie_df = df_buyers['estado_buyer'].value_counts().reset_index()
            pie_df.columns = ['Estado', 'Total']
            fig_pie = px.pie(
                pie_df, 
                names='Estado', 
                values='Total',
                hole=0.55,
                color='Estado',
                color_discrete_map={'ACTIVO': '#10b981', 'SIN_COBERTURA': '#ef4444'}
            )
            fig_pie.update_layout(margin=dict(t=20, b=20, l=10, r=10), height=300)
            st.plotly_chart(fig_pie, use_container_width=True)
        else:
            st.info("Sin registros de buyers aún.")

    with c2:
        st.subheader("Captación por Universidad")
        if not df_buyers.empty and 'universidad' in df_buyers.columns:
            u_df = df_buyers.groupby(['universidad', 'estado_buyer']).size().reset_index(name='Cantidad')
            fig_u = px.bar(
                u_df, 
                x='Cantidad', 
                y='universidad', 
                color='estado_buyer',
                orientation='h',
                barmode='stack',
                color_discrete_map={'ACTIVO': '#2563eb', 'SIN_COBERTURA': '#f87171'}
            )
            fig_u.update_layout(margin=dict(t=20, b=20, l=10, r=10), height=300, yaxis={'categoryorder':'total ascending'})
            st.plotly_chart(fig_u, use_container_width=True)
        else:
            st.info("Sin datos de universidades.")

    c3, c4 = st.columns(2)

    with c3:
        st.subheader("Top Carreras con Mayor Demanda")
        if not df_buyers.empty and 'carrera' in df_buyers.columns:
            top_carreras = df_buyers['carrera'].value_counts().nlargest(7).reset_index()
            top_carreras.columns = ['Carrera', 'Buyers']
            fig_carreras = px.bar(
                top_carreras, 
                x='Carrera', 
                y='Buyers',
                color='Buyers',
                color_continuous_scale='Blues'
            )
            fig_carreras.update_layout(margin=dict(t=20, b=20, l=10, r=10), height=300)
            st.plotly_chart(fig_carreras, use_container_width=True)

    with c4:
        st.subheader("Distribución por Etapa Académica")
        if not df_buyers.empty and 'etapa_academica' in df_buyers.columns:
            etapa_df = df_buyers['etapa_academica'].fillna('NO ESPECIFICA').value_counts().reset_index()
            etapa_df.columns = ['Etapa', 'Cantidad']
            fig_etapa = px.bar(
                etapa_df, 
                x='Etapa', 
                y='Cantidad',
                color='Etapa',
                color_discrete_sequence=px.colors.qualitative.Pastel
            )
            fig_etapa.update_layout(margin=dict(t=20, b=20, l=10, r=10), height=300)
            st.plotly_chart(fig_etapa, use_container_width=True)

# ------------------------------------------------------------------------------
# PESTAÑA 2: TABLA DE BUYERS EN VIVO
# ------------------------------------------------------------------------------
with tab_tabla:
    st.subheader("Listado Operativo de Buyers Registrados")
    
    col_f1, col_f2 = st.columns([1, 3])
    with col_f1:
        filtro_estado = st.selectbox("Filtrar por Cobertura:", ["TODOS", "ACTIVO", "SIN_COBERTURA"])
    with col_f2:
        busqueda = st.text_input("Buscar por Nombre, Teléfono o Universidad:")

    df_filtrado = df_buyers.copy()
    if filtro_estado != "TODOS":
        df_filtrado = df_filtrado[df_filtrado['estado_buyer'] == filtro_estado]

    if busqueda:
        mask = (
            df_filtrado['nombres'].astype(str).str.contains(busqueda, case=False, na=False) |
            df_filtrado['whatsapp'].astype(str).str.contains(busqueda, case=False, na=False) |
            df_filtrado['universidad'].astype(str).str.contains(busqueda, case=False, na=False)
        )
        df_filtrado = df_filtrado[mask]

    cols_ver = [
        'buyer_id', 'fecha_buyer', 'estado_buyer', 'nombres', 'whatsapp', 
        'universidad', 'carrera', 'etapa_academica', 'necesidad_inicial'
    ]
    styler = df_filtrado[cols_ver].style
    color_fn = lambda v: 'background-color: #dcfce7; color: #166534; font-weight: bold;' if v == 'ACTIVO' else (
                         'background-color: #fee2e2; color: #991b1b; font-weight: bold;' if v == 'SIN_COBERTURA' else ''
               )
    styler_mapped = styler.map(color_fn, subset=['estado_buyer']) if hasattr(styler, 'map') else styler.applymap(color_fn, subset=['estado_buyer'])
    st.dataframe(
        styler_mapped,
        use_container_width=True,
        height=400
    )

# ------------------------------------------------------------------------------
# PESTAÑA 3: AUDITORÍA DE CONVERSACIONES
# ------------------------------------------------------------------------------
with tab_chat:
    st.subheader("Trazabilidad de Mensajes WhatsApp en Tiempo Real")
    st.caption("Verifica cómo el Bot de Grok ejecutó el Function Calling y respondió al usuario.")

    if not df_chat.empty:
        contactos_unicos = df_chat[['whatsapp', 'nombres']].drop_duplicates()
        contacto_sel = st.selectbox(
            "Seleccionar conversación por Contacto:",
            options=contactos_unicos['whatsapp'].tolist(),
            format_func=lambda wa: f"{wa} - {contactos_unicos[contactos_unicos['whatsapp']==wa]['nombres'].values[0]}"
        )

        chat_filtrado = df_chat[df_chat['whatsapp'] == contacto_sel].sort_values('fecha_mensaje', ascending=True)

        for _, row in chat_filtrado.iterrows():
            es_bot = (row['emisor'] == 'BOT')
            with st.chat_message("assistant" if es_bot else "user"):
                st.markdown(f"**{'🤖 INBESTIGA Bot' if es_bot else '👤 Estudiante'}** ({row['fecha_mensaje']})")
                st.write(row['contenido'])
    else:
        st.info("Aún no hay mensajes registrados en la tabla MENSAJE.")

# ------------------------------------------------------------------------------
# 6. GESTIÓN DEL AUTO-REFRESCO
# ------------------------------------------------------------------------------
if auto_refresh:
    time.sleep(refresh_rate)
    st.rerun()

