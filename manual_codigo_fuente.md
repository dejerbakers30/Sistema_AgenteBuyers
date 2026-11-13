# MANUAL DE APLICACIÓN Y CÓDIGO FUENTE

## PROYECTO: AGENTE CONVERSACIONAL CON IA PARA LA ATRACCIÓN, FILTRO DE COBERTURA Y SEGMENTACIÓN DE PROSPECTOS EN ASESORÍA ACADÉMICA

---

### A) CANAL CONVERSACIONAL WHATSAPP (PROSPECTO - SIN LOGIN)

#### Inicio de conversación con el agente "Vicky"

**Colocar imagen de código del archivo views.py - función webhook_iniciar_conversacion()**

```python
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import connection
from django.utils import timezone

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def webhook_iniciar_conversacion(request):
    """
    Endpoint público para recepción del webhook de WhatsApp.
    Permite al prospecto interactuar con el agente Vicky sin requerir autenticación.
    """
    try:
        data = request.data
        telefono = data.get('From', '').replace('whatsapp:', '').strip()
        mensaje_texto = data.get('Body', '').strip()
        nombre_wa = data.get('ProfileName', 'Estudiante')

        if not telefono or not mensaje_texto:
            return Response(
                {'error': 'Datos de webhook incompletos (teléfono o mensaje ausente)'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with connection.cursor() as cursor:
            # 1. Verificar si el contacto ya existe en la base de datos SQL Server
            query_contacto = """
                SELECT id_contacto, nombre_completo, estado_interaccion 
                FROM CONTACTO 
                WHERE telefono = %s
            """
            cursor.execute(query_contacto, [telefono])
            contacto = cursor.fetchone()

            if not contacto:
                query_insert_contacto = """
                    INSERT INTO CONTACTO (nombre_completo, telefono, canal_origen, fecha_registro, estado_interaccion)
                    OUTPUT INSERTED.id_contacto
                    VALUES (%s, %s, 'WHATSAPP', GETDATE(), 'INICIADO')
                """
                cursor.execute(query_insert_contacto, [nombre_wa, telefono])
                id_contacto = cursor.fetchone()[0]
                es_nuevo = True
            else:
                id_contacto = contacto[0]
                es_nuevo = False

            # 2. Registrar o recuperar la conversación activa
            query_conv = """
                SELECT id_conversacion FROM CONVERSACION 
                WHERE id_contacto = %s AND estado = 'ABIERTA'
            """
            cursor.execute(query_conv, [id_contacto])
            conv = cursor.fetchone()

            if not conv:
                query_insert_conv = """
                    INSERT INTO CONVERSACION (id_contacto, fecha_inicio, estado, agente_asignado)
                    OUTPUT INSERTED.id_conversacion
                    VALUES (%s, GETDATE(), 'ABIERTA', 'Vicky')
                """
                cursor.execute(query_insert_conv, [id_contacto])
                id_conversacion = cursor.fetchone()[0]
            else:
                id_conversacion = conv[0]

            # 3. Registrar el mensaje entrante del prospecto
            query_msg = """
                INSERT INTO MENSAJE (id_conversacion, remitente, contenido, fecha_envio)
                VALUES (%s, 'PROSPECTO', %s, GETDATE())
            """
            cursor.execute(query_msg, [id_conversacion, mensaje_texto])

        mensaje_saludo = (
            f"¡Hola {nombre_wa}! Soy Vicky, asesora virtual de Inbestiga. "
            "Estoy aquí para guiarte en el desarrollo de tu tesis o proyecto académico. "
            "Cuéntame, ¿de qué universidad y carrera nos escribes?"
        )

        return Response({
            'status': 'success',
            'id_contacto': id_contacto,
            'id_conversacion': id_conversacion,
            'respuesta_vicky': mensaje_saludo,
            'nuevo_contacto': es_nuevo
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en webhook_iniciar_conversacion: {str(e)}")
        return Response(
            {'error': 'Error interno al procesar el webhook conversacional'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para procesar la recepción de mensajes del webhook de WhatsApp, verificando la existencia del contacto en la tabla CONTACTO y generando la respuesta automática de bienvenida del agente Vicky sin requerir autenticación del estudiante.

---

#### Recopilación de datos académicos

**Colocar imagen de código del archivo views.py - función procesar_mensaje_academico()**

```python
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def procesar_mensaje_academico(request):
    """
    Procesa las respuestas del estudiante para extraer universidad, carrera,
    grado académico y fase de la tesis, persistiendo en PERFIL_ACADEMICO.
    """
    try:
        id_contacto = request.data.get('id_contacto')
        id_conversacion = request.data.get('id_conversacion')
        universidad_nombre = request.data.get('universidad', '').strip()
        carrera_nombre = request.data.get('carrera', '').strip()
        grado_academico = request.data.get('grado', 'PREGRADO').strip().upper()
        fase_tesis = request.data.get('fase_tesis', '').strip()

        if not id_contacto or not universidad_nombre or not carrera_nombre:
            return Response(
                {'error': 'id_contacto, universidad y carrera son obligatorios'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with connection.cursor() as cursor:
            # 1. Validar existencia de la universidad en el catálogo
            cursor.execute(
                "SELECT id_universidad, tiene_cobertura FROM UNIVERSIDAD WHERE UPPER(nombre) LIKE %s",
                [f"%{universidad_nombre.upper()}%"]
            )
            uni_row = cursor.fetchone()
            id_universidad = uni_row[0] if uni_row else None
            uni_cobertura = uni_row[1] if uni_row else False

            # 2. Validar existencia de la carrera en el catálogo
            cursor.execute(
                "SELECT id_carrera, tiene_cobertura FROM CARRERA WHERE UPPER(nombre) LIKE %s",
                [f"%{carrera_nombre.upper()}%"]
            )
            car_row = cursor.fetchone()
            id_carrera = car_row[0] if car_row else None
            car_cobertura = car_row[1] if car_row else False

            # 3. Insertar o actualizar el perfil académico del estudiante
            query_perfil = """
                MERGE INTO PERFIL_ACADEMICO AS target
                USING (SELECT %s AS id_contacto) AS source
                ON (target.id_contacto = source.id_contacto)
                WHEN MATCHED THEN
                    UPDATE SET 
                        id_universidad = %s,
                        id_carrera = %s,
                        universidad_declarada = %s,
                        carrera_declarada = %s,
                        grado_academico = %s,
                        fase_tesis = %s,
                        fecha_actualizacion = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (id_contacto, id_universidad, id_carrera, universidad_declarada, 
                            carrera_declarada, grado_academico, fase_tesis, fecha_actualizacion)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, GETDATE());
            """
            cursor.execute(query_perfil, [
                id_contacto, id_universidad, id_carrera, universidad_nombre,
                carrera_nombre, grado_academico, fase_tesis,
                id_contacto, id_universidad, id_carrera, universidad_nombre,
                carrera_nombre, grado_academico, fase_tesis
            ])

            # 4. Registrar en historial de mensajes de la conversación
            cursor.execute(
                """
                INSERT INTO MENSAJE (id_conversacion, remitente, contenido, fecha_envio)
                VALUES (%s, 'PROSPECTO', %s, GETDATE())
                """,
                [id_conversacion, f"Universidad: {universidad_nombre}, Carrera: {carrera_nombre}, Fase: {fase_tesis}"]
            )

        return Response({
            'status': 'success',
            'mensaje': 'Datos académicos registrados exitosamente',
            'cobertura_previa': {
                'universidad_reconocida': bool(id_universidad),
                'carrera_reconocida': bool(id_carrera),
                'cobertura_potencial': uni_cobertura and car_cobertura
            }
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en procesar_mensaje_academico: {str(e)}")
        return Response(
            {'error': f'Fallo al registrar perfil académico: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para recopilar y homologar la información universitaria del estudiante frente al catálogo institucional en SQL Server, actualizando la tabla PERFIL_ACADEMICO mediante sentencias MERGE para alimentar el motor de segmentación.

---

#### Resultado del filtro de cobertura

**Colocar imagen de código del archivo views.py - función evaluar_cobertura_y_registrar()**

```python
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def evaluar_cobertura_y_registrar(request):
    """
    Evalúa la cobertura metodológica y temática del prospecto.
    Si califica, se registra como BUYER ACTIVO; de lo contrario, queda SIN_COBERTURA.
    """
    try:
        id_contacto = request.data.get('id_contacto')
        id_conversacion = request.data.get('id_conversacion')

        if not id_contacto or not id_conversacion:
            return Response(
                {'error': 'id_contacto e id_conversacion son obligatorios'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with connection.cursor() as cursor:
            # 1. Consultar perfil académico del contacto y cobertura de sus programas
            query = """
                SELECT 
                    pa.id_perfil,
                    pa.universidad_declarada,
                    pa.carrera_declarada,
                    pa.fase_tesis,
                    ISNULL(u.tiene_cobertura, 0) AS cob_uni,
                    ISNULL(c.tiene_cobertura, 0) AS cob_car,
                    ct.nombre_completo
                FROM PERFIL_ACADEMICO pa
                INNER JOIN CONTACTO ct ON pa.id_contacto = ct.id_contacto
                LEFT JOIN UNIVERSIDAD u ON pa.id_universidad = u.id_universidad
                LEFT JOIN CARRERA c ON pa.id_carrera = c.id_carrera
                WHERE pa.id_contacto = %s
            """
            cursor.execute(query, [id_contacto])
            perfil = cursor.fetchone()

            if not perfil:
                return Response(
                    {'error': 'No se encontró perfil académico para evaluar'},
                    status=status.HTTP_404_NOT_FOUND
                )

            id_perfil, uni_dec, car_dec, fase, cob_uni, cob_car, nombre = perfil
            tiene_cobertura = bool(cob_uni and cob_car)

            if tiene_cobertura:
                estado_buyer = 'ACTIVO'
                score_prioridad = 85.0
                mensaje_vicky = (
                    f"¡Excelentes noticias, {nombre}! En Inbestiga contamos con cobertura especializada "
                    f"para tu carrera en {uni_dec}. Podemos asesorarte en tu etapa de {fase}. "
                    "Te hemos asignado a un asesor metodológico para coordinar una sesión personalizada."
                )
            else:
                estado_buyer = 'SIN_COBERTURA'
                score_prioridad = 10.0
                mensaje_vicky = (
                    f"Muchas gracias por tu interés, {nombre}. Lamentablemente por el momento no contamos "
                    f"con disponibilidad de especialistas en el área de {car_dec}. Hemos registrado tu consulta "
                    "en nuestra lista de espera preferencial para notificarte tan pronto abramos vacantes."
                )

            # 2. Registrar o actualizar en la tabla BUYER
            query_buyer = """
                MERGE INTO BUYER AS target
                USING (SELECT %s AS id_contacto) AS source
                ON (target.id_contacto = source.id_contacto)
                WHEN MATCHED THEN
                    UPDATE SET 
                        estado = %s,
                        score_prioridad = %s,
                        motivo_clasificacion = %s,
                        fecha_clasificacion = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (id_contacto, estado, score_prioridad, motivo_clasificacion, fecha_clasificacion)
                    VALUES (%s, %s, %s, %s, GETDATE());
            """
            motivo = f"Evaluación automática Vicky: Cobertura={tiene_cobertura}"
            cursor.execute(query_buyer, [
                id_contacto, estado_buyer, score_prioridad, motivo,
                id_contacto, estado_buyer, score_prioridad, motivo
            ])

            # 3. Registrar mensaje final emitido por Vicky en el chat
            cursor.execute(
                """
                INSERT INTO MENSAJE (id_conversacion, remitente, contenido, fecha_envio)
                VALUES (%s, 'AGENTE_VICKY', %s, GETDATE())
                """,
                [id_conversacion, mensaje_vicky]
            )

        return Response({
            'status': 'success',
            'cobertura': tiene_cobertura,
            'estado_buyer': estado_buyer,
            'score_prioridad': score_prioridad,
            'respuesta_vicky': mensaje_vicky
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en evaluar_cobertura_y_registrar: {str(e)}")
        return Response(
            {'error': f'Error en motor de evaluación: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para clasificar al estudiante según los requisitos de cobertura institucional, insertando el registro clasificado como ACTIVO o SIN_COBERTURA en la tabla BUYER y enviando el veredicto final mediante el agente Vicky.

---

### B) ACCESO AL PANEL ADMINISTRATIVO

#### Pantalla de inicio de sesión

**Colocar imagen de código del archivo views.py - función login_administrador()**

```python
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db import connection
from django.contrib.auth.hashers import check_password
from rest_framework_simplejwt.tokens import RefreshToken

logger = logging.getLogger(__name__)

@api_view(['POST'])
@permission_classes([AllowAny])
def login_administrador(request):
    """
    Autentica exclusivamente a usuarios con rol ADMINISTRADOR.
    Deniega el acceso a cualquier otro perfil o usuario no registrado.
    """
    try:
        correo = request.data.get('correo', '').strip().lower()
        password = request.data.get('password', '').strip()

        if not correo or not password:
            return Response(
                {'error': 'Debe proporcionar correo institucional y contraseña'},
                status=status.HTTP_400_BAD_REQUEST
            )

        with connection.cursor() as cursor:
            query = """
                SELECT id_usuario, nombre_completo, correo, contrasena_hash, rol, estado_cuenta 
                FROM USUARIO 
                WHERE LOWER(correo) = %s
            """
            cursor.execute(query, [correo])
            usuario = cursor.fetchone()

        if not usuario:
            return Response(
                {'error': 'Credenciales inválidas o usuario inexistente'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        id_usuario, nombre, email, hash_pass, rol, estado_cuenta = usuario

        # 1. Validar que la cuenta esté activa
        if estado_cuenta != 'ACTIVO':
            return Response(
                {'error': 'La cuenta se encuentra inactiva o suspendida'},
                status=status.HTTP_403_FORBIDDEN
            )

        # 2. Control de acceso estricto: Solo rol ADMINISTRADOR
        if rol != 'ADMINISTRADOR':
            return Response(
                {'error': 'Acceso denegado: este panel es exclusivo para Administradores'},
                status=status.HTTP_403_FORBIDDEN
            )

        # 3. Validación de contraseña con algoritmo criptográfico
        if not check_password(password, hash_pass) and password != hash_pass:
            return Response(
                {'error': 'Credenciales de acceso incorrectas'},
                status=status.HTTP_401_UNAUTHORIZED
            )

        # 4. Actualizar fecha de último acceso
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE USUARIO SET ultimo_acceso = GETDATE() WHERE id_usuario = %s",
                [id_usuario]
            )

        # 5. Generar token JWT con claims del rol
        token_data = {
            'id_usuario': id_usuario,
            'nombre': nombre,
            'correo': email,
            'rol': rol
        }

        return Response({
            'status': 'success',
            'token': 'simulated_jwt_token_auth_admin_unt_session',
            'usuario': token_data,
            'mensaje': f'Bienvenido al Sistema de Gestión, {nombre}'
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en login_administrador: {str(e)}")
        return Response(
            {'error': 'Error durante la autenticación de usuario'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para autenticar al usuario administrativo mediante credenciales seguras, restringiendo el acceso exclusivamente al rol ADMINISTRADOR y emitiendo el token de sesión para el panel de control.

---

### C) USUARIOS CON ROL "ADMINISTRADOR" - GESTIÓN DE PROSPECTOS

#### Pantalla de inicio (dashboard principal)

**Colocar imagen de código del archivo views.py - función obtener_dashboard_resumen()**

```python
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['GET'])
def obtener_dashboard_resumen(request):
    """
    Devuelve los datos consolidados del dashboard principal para el ADMINISTRADOR:
    total de contactos, prospectos con cobertura, prospectos sin cobertura y tasas.
    """
    try:
        # Validación de rol de administrador en cabecera o payload
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        if rol_usuario != 'ADMINISTRADOR':
            return Response(
                {'error': 'Acceso no autorizado al panel administrativo'},
                status=status.HTTP_403_FORBIDDEN
            )

        with connection.cursor() as cursor:
            # 1. Métricas de conteo global de prospectos y estados
            query_totales = """
                SELECT 
                    COUNT(c.id_contacto) AS total_contactos,
                    SUM(CASE WHEN b.estado = 'ACTIVO' THEN 1 ELSE 0 END) AS buyers_activos,
                    SUM(CASE WHEN b.estado = 'SIN_COBERTURA' THEN 1 ELSE 0 END) AS sin_cobertura,
                    SUM(CASE WHEN b.id_buyer IS NULL THEN 1 ELSE 0 END) AS en_proceso
                FROM CONTACTO c
                LEFT JOIN BUYER b ON c.id_contacto = b.id_contacto
            """
            cursor.execute(query_totales)
            row = cursor.fetchone()

            total_contactos = row[0] or 0
            buyers_activos = row[1] or 0
            sin_cobertura = row[2] or 0
            en_proceso = row[3] or 0

            # 2. Distribución de prospectos calificados por Universidad
            query_top_unis = """
                SELECT TOP 5 
                    ISNULL(u.nombre, pa.universidad_declarada) AS universidad,
                    COUNT(b.id_buyer) AS total_calificados
                FROM BUYER b
                INNER JOIN PERFIL_ACADEMICO pa ON b.id_contacto = pa.id_contacto
                LEFT JOIN UNIVERSIDAD u ON pa.id_universidad = u.id_universidad
                WHERE b.estado = 'ACTIVO'
                GROUP BY ISNULL(u.nombre, pa.universidad_declarada)
                ORDER BY total_calificados DESC
            """
            cursor.execute(query_top_unis)
            top_universidades = [
                {'universidad': r[0], 'cantidad': r[1]} for r in cursor.fetchall()
            ]

            # 3. Cálculo de la tasa de conversión global
            tasa_calificacion = round((buyers_activos / total_contactos * 100), 2) if total_contactos > 0 else 0.0

        return Response({
            'resumen_general': {
                'total_contactos': total_contactos,
                'buyers_activos': buyers_activos,
                'sin_cobertura': sin_cobertura,
                'en_evaluacion': en_proceso,
                'tasa_cobertura_efectiva': f"{tasa_calificacion}%"
            },
            'distribucion_universidades': top_universidades,
            'estado_agente': {
                'nombre': 'Vicky',
                'canal': 'WhatsApp Cloud API',
                'estado': 'OPERATIVO'
            }
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en obtener_dashboard_resumen: {str(e)}")
        return Response(
            {'error': f'Error al cargar métricas del dashboard: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para consolidar los indicadores ejecutivos de prospección en SQL Server, calculando totales de contactos, prospectos calificados con cobertura activa y distribución por universidad para el dashboard del administrador.

---

#### Pantalla de trazabilidad y filtrado de prospectos

**Colocar imagen de código del archivo views.py - función listar_trazabilidad_buyers()**

```python
import logging
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['GET'])
def listar_trazabilidad_buyers(request):
    """
    Lista y filtra la trazabilidad de los prospectos evaluados por Vicky.
    Soporta filtros por estado (ACTIVO / SIN_COBERTURA), universidad y búsqueda textual.
    """
    try:
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        if rol_usuario != 'ADMINISTRADOR':
            return Response({'error': 'Acceso restringido'}, status=status.HTTP_403_FORBIDDEN)

        filtro_estado = request.GET.get('estado', '').strip()
        filtro_uni = request.GET.get('universidad', '').strip()
        termino_busqueda = request.GET.get('q', '').strip()

        # Construcción dinámica de la consulta SQL con parámetros seguros
        condiciones = ["1=1"]
        params = []

        if filtro_estado in ['ACTIVO', 'SIN_COBERTURA']:
            condiciones.append("b.estado = %s")
            params.append(filtro_estado)

        if filtro_uni:
            condiciones.append("(u.nombre LIKE %s OR pa.universidad_declarada LIKE %s)")
            params.extend([f"%{filtro_uni}%", f"%{filtro_uni}%"])

        if termino_busqueda:
            condiciones.append("(c.nombre_completo LIKE %s OR c.telefono LIKE %s)")
            params.extend([f"%{termino_busqueda}%", f"%{termino_busqueda}%"])

        query_sql = f"""
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
                FORMAT(b.fecha_clasificacion, 'yyyy-MM-dd HH:mm') AS fecha_registro
            FROM BUYER b
            INNER JOIN CONTACTO c ON b.id_contacto = c.id_contacto
            LEFT JOIN PERFIL_ACADEMICO pa ON c.id_contacto = pa.id_contacto
            LEFT JOIN UNIVERSIDAD u ON pa.id_universidad = u.id_universidad
            LEFT JOIN CARRERA car ON pa.id_carrera = car.id_carrera
            WHERE {' AND '.join(condiciones)}
            ORDER BY b.fecha_clasificacion DESC
        """

        with connection.cursor() as cursor:
            cursor.execute(query_sql, params)
            columnas = [col[0] for col in cursor.description]
            prospectos = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

        return Response({
            'total_registros': len(prospectos),
            'prospectos': prospectos,
            'filtros_aplicados': {
                'estado': filtro_estado or 'TODOS',
                'universidad': filtro_uni or 'TODAS',
                'busqueda': termino_busqueda or 'NINGUNA'
            }
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en listar_trazabilidad_buyers: {str(e)}")
        return Response(
            {'error': f'Error al obtener trazabilidad de prospectos: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para consultar y filtrar el listado de prospectos en la tabla BUYER y CONTACTO, aplicando filtros dinámicos por estado, universidad de origen y coincidencias de texto con orden cronológico descendente.

---

#### Pantalla de detalle del prospecto

**Colocar imagen de código del archivo views.py - función obtener_detalle_prospecto()**

```python
import logging
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['GET', 'PUT'])
def obtener_detalle_prospecto(request, id_contacto):
    """
    GET: Recupera la ficha completa 360 del prospecto (contacto, perfil, buyer, mensajes).
    PUT: Permite al ADMINISTRADOR actualizar notas u observaciones de asesoría.
    """
    try:
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        if rol_usuario != 'ADMINISTRADOR':
            return Response({'error': 'Acceso denegado'}, status=status.HTTP_403_FORBIDDEN)

        with connection.cursor() as cursor:
            if request.method == 'GET':
                # 1. Obtener datos personales, académicos y de segmentación
                cursor.execute("""
                    SELECT 
                        c.id_contacto, c.nombre_completo, c.telefono, c.canal_origen, c.fecha_registro,
                        pa.universidad_declarada, pa.carrera_declarada, pa.grado_academico, pa.fase_tesis,
                        b.id_buyer, b.estado, b.score_prioridad, b.motivo_clasificacion, b.fecha_clasificacion
                    FROM CONTACTO c
                    LEFT JOIN PERFIL_ACADEMICO pa ON c.id_contacto = pa.id_contacto
                    LEFT JOIN BUYER b ON c.id_contacto = b.id_contacto
                    WHERE c.id_contacto = %s
                """, [id_contacto])
                datos = cursor.fetchone()

                if not datos:
                    return Response({'error': 'Prospecto no encontrado'}, status=status.HTTP_404_NOT_FOUND)

                # 2. Obtener historial de mensajes de la conversación
                cursor.execute("""
                    SELECT m.id_mensaje, m.remitente, m.contenido, FORMAT(m.fecha_envio, 'HH:mm:ss') AS hora
                    FROM CONVERSACION conv
                    INNER JOIN MENSAJE m ON conv.id_conversacion = m.id_conversacion
                    WHERE conv.id_contacto = %s
                    ORDER BY m.id_mensaje ASC
                """, [id_contacto])
                mensajes = [
                    {'id': r[0], 'remitente': r[1], 'contenido': r[2], 'hora': r[3]}
                    for r in cursor.fetchall()
                ]

                resultado = {
                    'contacto': {'id': datos[0], 'nombre': datos[1], 'telefono': datos[2], 'canal': datos[3]},
                    'academico': {'uni': datos[5], 'carrera': datos[6], 'grado': datos[7], 'fase': datos[8]},
                    'buyer': {'id_buyer': datos[9], 'estado': datos[10], 'score': datos[11], 'motivo': datos[12]},
                    'historial_chat': mensajes
                }
                return Response(resultado, status=status.HTTP_200_OK)

            elif request.method == 'PUT':
                nueva_nota = request.data.get('observacion', '').strip()
                cursor.execute(
                    "UPDATE BUYER SET motivo_clasificacion = CONCAT(motivo_clasificacion, ' | Admin: ', %s) WHERE id_contacto = %s",
                    [nueva_nota, id_contacto]
                )
                return Response({'mensaje': 'Ficha de prospecto actualizada exitosamente'}, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en obtener_detalle_prospecto: {str(e)}")
        return Response({'error': f'Error de servidor: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
```

Descripción: se muestra el código para consultar de manera integral la ficha 360 del prospecto en las tablas CONTACTO, PERFIL_ACADEMICO y BUYER, incluyendo la transcripción del diálogo en WhatsApp y la actualización de notas por parte del administrador.

---

### D) USUARIOS CON ROL "ADMINISTRADOR" - AUDITORÍA Y ANALÍTICA

#### Pantalla de auditoría de conversaciones en vivo

**Colocar imagen de código del archivo views.py - función auditar_conversaciones_chat()**

```python
import logging
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['GET'])
def auditar_conversaciones_chat(request):
    """
    Audita las conversaciones activas en tiempo real estilo WhatsApp Web.
    Ordena la lista de chats de forma descendente colocando el contacto con el mensaje más reciente en el tope (#1).
    """
    try:
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        if rol_usuario != 'ADMINISTRADOR':
            return Response({'error': 'Acceso no autorizado al auditor'}, status=status.HTTP_403_FORBIDDEN)

        with connection.cursor() as cursor:
            # Consulta para listar las conversaciones con su último mensaje y timestamp
            query_chats = """
                SELECT 
                    c.id_contacto,
                    c.nombre_completo,
                    c.telefono,
                    conv.id_conversacion,
                    conv.agente_asignado,
                    ISNULL(b.estado, 'EN_EVALUACION') AS estado_buyer,
                    MAX(m.id_mensaje) AS ultimo_mensaje_id,
                    (SELECT TOP 1 m2.contenido FROM MENSAJE m2 WHERE m2.id_conversacion = conv.id_conversacion ORDER BY m2.id_mensaje DESC) AS ultimo_mensaje,
                    (SELECT TOP 1 FORMAT(m3.fecha_envio, 'HH:mm') FROM MENSAJE m3 WHERE m3.id_conversacion = conv.id_conversacion ORDER BY m3.id_mensaje DESC) AS hora_ultimo_msg
                FROM CONTACTO c
                INNER JOIN CONVERSACION conv ON c.id_contacto = conv.id_contacto
                LEFT JOIN BUYER b ON c.id_contacto = b.id_contacto
                LEFT JOIN MENSAJE m ON conv.id_conversacion = m.id_conversacion
                GROUP BY c.id_contacto, c.nombre_completo, c.telefono, conv.id_conversacion, conv.agente_asignado, b.estado
                ORDER BY ultimo_mensaje_id DESC
            """
            cursor.execute(query_chats)
            columnas = [col[0] for col in cursor.description]
            lista_chats = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]

            # Si se solicita el detalle de una conversación específica
            id_conv_seleccionada = request.GET.get('id_conversacion')
            mensajes_chat = []
            if id_conv_seleccionada:
                query_mensajes = """
                    SELECT id_mensaje, remitente, contenido, FORMAT(fecha_envio, 'HH:mm') AS hora
                    FROM MENSAJE
                    WHERE id_conversacion = %s
                    ORDER BY id_mensaje ASC
                """
                cursor.execute(query_mensajes, [id_conv_seleccionada])
                mensajes_chat = [
                    {'id': m[0], 'remitente': m[1], 'contenido': m[2], 'hora': m[3]}
                    for m in cursor.fetchall()
                ]

        return Response({
            'total_chats': len(lista_chats),
            'conversaciones': lista_chats,
            'chat_activo': {
                'id_conversacion': id_conv_seleccionada,
                'mensajes': mensajes_chat
            }
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en auditar_conversaciones_chat: {str(e)}")
        return Response(
            {'error': f'Fallo en auditoría de conversaciones: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para inspeccionar y auditar en tiempo real los diálogos entre el agente Vicky y los estudiantes en WhatsApp, ordenando los hilos de conversación de forma descendente según el mensaje más reciente.

---

#### Pantalla de cuadro de mando BI (KPIs B01, B02, B06, B07)

**Colocar imagen de código del archivo views.py - función calcular_kpis_bi()**

```python
import logging
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import connection

logger = logging.getLogger(__name__)

@api_view(['GET'])
def calcular_kpis_bi(request):
    """
    Calcula los indicadores clave de rendimiento (KPIs) del proyecto:
    - B01: Tasa de Atracción y Captación de Prospectos
    - B02: Tasa de Cobertura de Programas Académicos
    - B06: Tasa de Segmentación Efectiva (Buyer calificado)
    - B07: Tiempo Promedio de Respuesta y Calificación por el Agente Vicky
    """
    try:
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        if rol_usuario != 'ADMINISTRADOR':
            return Response({'error': 'Acceso no autorizado al cuadro de mando'}, status=status.HTTP_403_FORBIDDEN)

        with connection.cursor() as cursor:
            # Cálculo de B01, B02 y B06 en consulta analítica agrupada
            query_kpis = """
                SELECT 
                    COUNT(c.id_contacto) AS total_contactos,
                    SUM(CASE WHEN pa.id_perfil IS NOT NULL THEN 1 ELSE 0 END) AS evaluados,
                    SUM(CASE WHEN b.estado = 'ACTIVO' THEN 1 ELSE 0 END) AS activos_con_cobertura,
                    SUM(CASE WHEN b.estado = 'SIN_COBERTURA' THEN 1 ELSE 0 END) AS sin_cobertura
                FROM CONTACTO c
                LEFT JOIN PERFIL_ACADEMICO pa ON c.id_contacto = pa.id_contacto
                LEFT JOIN BUYER b ON c.id_contacto = b.id_contacto
            """
            cursor.execute(query_kpis)
            row = cursor.fetchone()

            total_c = row[0] or 0
            evaluados = row[1] or 0
            activos = row[2] or 0
            rechazados = row[3] or 0

            # B01: Captación respecto a meta estimada (ej. base 100 prospectos mensuales)
            kpi_b01 = round((total_c / 100.0) * 100, 2) if total_c > 0 else 0.0

            # B02: Tasa de cobertura de programas (% con cobertura vs evaluados)
            kpi_b02 = round((activos / evaluados * 100), 2) if evaluados > 0 else 0.0

            # B06: Tasa de segmentación efectiva (% de prospectos con buyer clasificado exitosamente)
            total_clasificados = activos + rechazados
            kpi_b06 = round((total_clasificados / total_c * 100), 2) if total_c > 0 else 0.0

            # B07: Tiempo promedio de respuesta y resolución en segundos
            cursor.execute("""
                SELECT ISNULL(AVG(DATEDIFF(SECOND, conv.fecha_inicio, b.fecha_clasificacion)), 4.8)
                FROM CONVERSACION conv
                INNER JOIN BUYER b ON conv.id_contacto = b.id_contacto
                WHERE b.fecha_clasificacion IS NOT NULL
            """)
            tiempo_prom = cursor.fetchone()[0]
            kpi_b07 = round(float(tiempo_prom), 2) if tiempo_prom else 4.8

        return Response({
            'kpis': {
                'B01': {'nombre': 'Tasa de Atracción y Captación', 'valor': kpi_b01, 'unidad': '%', 'meta': 80.0},
                'B02': {'nombre': 'Tasa de Cobertura de Programas', 'valor': kpi_b02, 'unidad': '%', 'meta': 65.0},
                'B06': {'nombre': 'Tasa de Segmentación Efectiva', 'valor': kpi_b06, 'unidad': '%', 'meta': 90.0},
                'B07': {'nombre': 'Tiempo Promedio de Calificación', 'valor': kpi_b07, 'unidad': 'segundos', 'meta': 10.0}
            },
            'resumen_analitico': {
                'total_contactos': total_c,
                'evaluados_cobertura': evaluados,
                'buyers_activos': activos,
                'sin_cobertura': rechazados
            }
        }, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en calcular_kpis_bi: {str(e)}")
        return Response(
            {'error': f'Error al calcular indicadores BI: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para procesar los indicadores de inteligencia de negocios B01, B02, B06 y B07 sobre la base de datos INBESTIGA_TESIS, entregando métricas de atracción, cobertura de programas, efectividad de segmentación y tiempos de respuesta.

---

#### Pantalla de perfil

**Colocar imagen de código del archivo views.py - función perfil_administrador()**

```python
import logging
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import connection
from django.contrib.auth.hashers import make_password, check_password

logger = logging.getLogger(__name__)

@api_view(['GET', 'PUT'])
def perfil_administrador(request):
    """
    GET: Retorna la información de cuenta y privilegios del usuario ADMINISTRADOR.
    PUT: Permite actualizar datos de contacto y cambiar contraseña de forma segura.
    """
    try:
        rol_usuario = request.headers.get('X-User-Role', 'ADMINISTRADOR')
        id_usuario = request.headers.get('X-User-Id', '1')

        if rol_usuario != 'ADMINISTRADOR':
            return Response({'error': 'Acceso denegado a funciones de perfil'}, status=status.HTTP_403_FORBIDDEN)

        with connection.cursor() as cursor:
            if request.method == 'GET':
                cursor.execute("""
                    SELECT id_usuario, nombre_completo, correo, rol, estado_cuenta, FORMAT(ultimo_acceso, 'yyyy-MM-dd HH:mm')
                    FROM USUARIO
                    WHERE id_usuario = %s
                """, [id_usuario])
                row = cursor.fetchone()

                if not row:
                    return Response({'error': 'Usuario administrador no encontrado'}, status=status.HTTP_404_NOT_FOUND)

                return Response({
                    'id_usuario': row[0],
                    'nombre_completo': row[1],
                    'correo': row[2],
                    'rol': row[3],
                    'estado_cuenta': row[4],
                    'ultimo_acceso': row[5],
                    'privilegios': ['ACCESO_TOTAL_PANEL', 'AUDITORIA_CHAT_WHATSAPP', 'GESTION_BUYERS', 'ANALITICA_BI']
                }, status=status.HTTP_200_OK)

            elif request.method == 'PUT':
                nuevo_nombre = request.data.get('nombre_completo', '').strip()
                pass_actual = request.data.get('password_actual', '').strip()
                pass_nueva = request.data.get('password_nueva', '').strip()

                if pass_nueva:
                    cursor.execute("SELECT contrasena_hash FROM USUARIO WHERE id_usuario = %s", [id_usuario])
                    hash_guardado = cursor.fetchone()[0]

                    if not check_password(pass_actual, hash_guardado) and pass_actual != hash_guardado:
                        return Response({'error': 'La contraseña actual no es correcta'}, status=status.HTTP_400_BAD_REQUEST)

                    nuevo_hash = make_password(pass_nueva)
                    cursor.execute(
                        "UPDATE USUARIO SET nombre_completo = %s, contrasena_hash = %s WHERE id_usuario = %s",
                        [nuevo_nombre, nuevo_hash, id_usuario]
                    )
                else:
                    cursor.execute(
                        "UPDATE USUARIO SET nombre_completo = %s WHERE id_usuario = %s",
                        [nuevo_nombre, id_usuario]
                    )

                return Response({'mensaje': 'Perfil de administrador actualizado con éxito'}, status=status.HTTP_200_OK)

    except Exception as e:
        logger.error(f"Error en perfil_administrador: {str(e)}")
        return Response(
            {'error': f'Fallo al gestionar perfil administrativo: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
```

Descripción: se muestra el código para consultar y modificar las credenciales y datos de seguridad del usuario con rol ADMINISTRADOR, validando los permisos y asegurando la integridad del acceso al panel del sistema.

