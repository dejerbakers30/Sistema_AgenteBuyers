/* ============================================================================
04_ETL_POBLAR_DATAMART_DEFINITIVO.sql
INBESTIGA_TESIS -> INBESTIGA_MART

- Carga 18 dimensiones mediante MERGE.
- DIM_TIEMPO se conserva sin cambios.
- En las demás dimensiones se ordenan los atributos desde la agrupación más general hasta el detalle más específico.
- Los niveles jerárquicos van de general a específico; los atributos descriptivos van después; el id natural queda al final.
- Usa IDs físicos del OLTP cuando existe una entidad fuente directa y no inventa códigos auxiliares.
- Carga 13 hechos respetando sus granos.
- Todas las FK de hechos quedan NOT NULL mediante miembros 0 / -1.
- Incluye reconciliaciones OLTP vs DataMart.
- Los SELECT de los 13 hechos usan alias explícitos al estilo del docente.
============================================================================ */

USE INBESTIGA_TESIS;
GO
SET NOCOUNT ON;
GO

/* ============================================================================
1. DIM_TIEMPO
============================================================================ */
IF OBJECT_ID('dbo.v_FechasBI','V') IS NOT NULL
    DROP VIEW dbo.v_FechasBI;
GO

CREATE VIEW dbo.v_FechasBI
AS
SELECT CAST(fecha_buyer AS DATE) AS idFecha FROM BUYER
UNION SELECT CAST(fecha_envio AS DATE) FROM SEGUIMIENTO_BUYER
UNION SELECT CAST(fecha_lead AS DATE) FROM LEAD
UNION SELECT CAST(fecha_solicitud AS DATE) FROM DIAGNOSTICO
UNION SELECT CAST(fecha_presentacion AS DATE) FROM PROPUESTA
UNION SELECT CAST(fecha_registro AS DATE) FROM OBJECION
UNION SELECT CAST(fecha_creacion AS DATE) FROM ORDEN_PAGO
UNION SELECT CAST(fecha_confirmacion AS DATE) FROM PAGO WHERE fecha_confirmacion IS NOT NULL
UNION SELECT CAST(fecha_activacion AS DATE) FROM CUSTOMER
UNION SELECT CAST(fecha_programada AS DATE) FROM SESION
UNION SELECT CAST(fecha_pactada AS DATE) FROM HITO_CRONOGRAMA
UNION SELECT CAST(fecha_inicio AS DATE) FROM CONVERSACION
UNION SELECT CAST(periodo AS DATE) FROM META
UNION SELECT CAST(fecha_inicio AS DATE) FROM CAMPANIA;
GO

MERGE INBESTIGA_MART.dbo.DIM_TIEMPO AS d
USING(
    SELECT DISTINCT
        YEAR(idFecha) AS Anio,
        CONCAT(YEAR(idFecha),'-T',DATEPART(QUARTER,idFecha)) AS Trimestre,
        MONTH(idFecha) AS NroMes,
        DATENAME(MONTH,idFecha) AS Mes,
        DATEPART(ISO_WEEK,idFecha) AS Semana,
        DATENAME(WEEKDAY,idFecha) AS DiaSemana,
        DAY(idFecha) AS Dia,
        idFecha
    FROM dbo.v_FechasBI
) AS s
ON d.idFecha=s.idFecha
WHEN NOT MATCHED THEN
    INSERT(Anio,Trimestre,NroMes,Mes,Semana,DiaSemana,Dia,idFecha)
    VALUES(s.Anio,s.Trimestre,s.NroMes,s.Mes,s.Semana,s.DiaSemana,s.Dia,s.idFecha);
GO

/* ============================================================================
2. DIM_ESTUDIANTE
Ruta analítica general -> específica: Sede > EtapaAcademica > Ciclo.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_ESTUDIANTE AS d
USING(
    SELECT
        sede AS Sede,
        etapa_academica AS EtapaAcademica,
        ciclo AS Ciclo,
        perfil_academico_id AS idPerfilAcademico
    FROM PERFIL_ACADEMICO
) AS s
ON d.idPerfilAcademico=s.idPerfilAcademico
WHEN NOT MATCHED THEN
    INSERT(Sede,EtapaAcademica,Ciclo,idPerfilAcademico)
    VALUES(s.Sede,s.EtapaAcademica,s.Ciclo,s.idPerfilAcademico);
GO

/* ============================================================================
3. DIM_CARRERA
Jerarquía: TipoUniversidad > Universidad > Facultad > Carrera.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_CARRERA AS d
USING(
    SELECT
        u.tipo AS TipoUniversidad,
        u.nombre AS Universidad,
        c.facultad AS Facultad,
        c.nombre AS Carrera,
        c.carrera_id AS idCarrera
    FROM CARRERA c
    INNER JOIN UNIVERSIDAD u ON u.universidad_id=c.universidad_id
) AS s
ON d.idCarrera=s.idCarrera
WHEN NOT MATCHED THEN
    INSERT(TipoUniversidad,Universidad,Facultad,Carrera,idCarrera)
    VALUES(s.TipoUniversidad,s.Universidad,s.Facultad,s.Carrera,s.idCarrera);
GO

/* ============================================================================
4. DIM_CANAL_CAPTACION
Jerarquía: TipoCanal > Plataforma > Canal > Campania.
Grano dimensional: Canal x Campania.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_CANAL_CAPTACION AS d
USING(
    SELECT
        c.tipo AS TipoCanal,
        c.plataforma AS Plataforma,
        c.nombre AS Canal,
        CAST('NO APLICA' AS VARCHAR(150)) AS Campania,
        c.canal_id AS idCanal,
        0 AS idCampania
    FROM CANAL c
    UNION ALL
    SELECT
        c.tipo,
        c.plataforma,
        c.nombre,
        cp.nombre,
        c.canal_id,
        cp.campania_id
    FROM CAMPANIA cp
    INNER JOIN CANAL c ON c.canal_id=cp.canal_id
) AS s
ON d.idCanal=s.idCanal
AND d.idCampania=s.idCampania
WHEN NOT MATCHED THEN
    INSERT(TipoCanal,Plataforma,Canal,Campania,idCanal,idCampania)
    VALUES(s.TipoCanal,s.Plataforma,s.Canal,s.Campania,s.idCanal,s.idCampania);
GO

/* ============================================================================
5. DIM_CONTENIDO
Jerarquía: TipoContenido > Tema > Titulo.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_CONTENIDO AS d
USING(
    SELECT
        tipo_contenido AS TipoContenido,
        tema AS Tema,
        titulo AS Titulo,
        contenido_id AS idContenido
    FROM CONTENIDO
) AS s
ON d.idContenido=s.idContenido
WHEN NOT MATCHED THEN
    INSERT(TipoContenido,Tema,Titulo,idContenido)
    VALUES(s.TipoContenido,s.Tema,s.Titulo,s.idContenido);
GO

/* ============================================================================
6. DIM_SERVICIO
Jerarquía: Familia > TipoServicio > Servicio.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_SERVICIO AS d
USING(
    SELECT
        familia AS Familia,
        tipo_servicio AS TipoServicio,
        nombre AS Servicio,
        servicio_id AS idServicio
    FROM SERVICIO
) AS s
ON d.idServicio=s.idServicio
WHEN NOT MATCHED THEN
    INSERT(Familia,TipoServicio,Servicio,idServicio)
    VALUES(s.Familia,s.TipoServicio,s.Servicio,s.idServicio);
GO

/* ============================================================================
7. DIM_SEGUIMIENTO
No se fuerza una jerarquía artificial.
TipoSeguimiento y Resultado son atributos analíticos del seguimiento.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_SEGUIMIENTO AS d
USING(
    SELECT
        tipo_seguimiento AS TipoSeguimiento,
        resultado AS Resultado,
        seguimiento_buyer_id AS idSeguimientoBuyer
    FROM SEGUIMIENTO_BUYER
) AS s
ON d.idSeguimientoBuyer=s.idSeguimientoBuyer
WHEN NOT MATCHED THEN
    INSERT(TipoSeguimiento,Resultado,idSeguimientoBuyer)
    VALUES(s.TipoSeguimiento,s.Resultado,s.idSeguimientoBuyer);
GO

/* ============================================================================
8. DIM_INVESTIGACION
No se fuerza una jerarquía artificial.
Los tres campos son atributos analíticos del diagnóstico/investigación.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_INVESTIGACION AS d
USING(
    SELECT
        COALESCE(di.tipo_tesis,pa.tipo_investigacion) AS TipoInvestigacion,
        COALESCE(di.avance_declarado,pa.avance) AS RangoAvance,
        di.empresa_aplicacion AS EmpresaAplicacion,
        di.diagnostico_id AS idDiagnostico
    FROM DIAGNOSTICO di
    INNER JOIN LEAD l ON l.lead_id=di.lead_id
    INNER JOIN BUYER b ON b.buyer_id=l.buyer_id
    INNER JOIN PERFIL_ACADEMICO pa ON pa.contacto_id=b.contacto_id
) AS s
ON d.idDiagnostico=s.idDiagnostico
WHEN NOT MATCHED THEN
    INSERT(TipoInvestigacion,RangoAvance,EmpresaAplicacion,idDiagnostico)
    VALUES(s.TipoInvestigacion,s.RangoAvance,s.EmpresaAplicacion,s.idDiagnostico);
GO

/* ============================================================================
9. DIM_ASESOR
Ruta analítica general -> específica: Equipo > Rol > Especialidad > Asesor.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_ASESOR AS d
USING(
    SELECT
        equipo AS Equipo,
        rol AS Rol,
        especialidad AS Especialidad,
        nombre AS Asesor,
        asesor_id AS idAsesor
    FROM ASESOR
) AS s
ON d.idAsesor=s.idAsesor
WHEN NOT MATCHED THEN
    INSERT(Equipo,Rol,Especialidad,Asesor,idAsesor)
    VALUES(s.Equipo,s.Rol,s.Especialidad,s.Asesor,s.idAsesor);
GO

/* ============================================================================
10. DIM_OBJECION
Jerarquía: Grupo > Tipo.
Estado es atributo descriptivo de la objeción.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_OBJECION AS d
USING(
    SELECT
        grupo AS Grupo,
        tipo AS Tipo,
        estado AS Estado,
        objecion_id AS idObjecion
    FROM OBJECION
) AS s
ON d.idObjecion=s.idObjecion
WHEN NOT MATCHED THEN
    INSERT(Grupo,Tipo,Estado,idObjecion)
    VALUES(s.Grupo,s.Tipo,s.Estado,s.idObjecion);
GO

/* ============================================================================
11. DIM_ORIGEN_PROPUESTA
Dimensión categórica de un solo atributo.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_ORIGEN_PROPUESTA AS d
USING(
    SELECT DISTINCT generada_por AS GeneradaPor
    FROM PROPUESTA
) AS s
ON d.GeneradaPor=s.GeneradaPor
WHEN NOT MATCHED THEN
    INSERT(GeneradaPor)
    VALUES(s.GeneradaPor);
GO

/* ============================================================================
12. DIM_MODALIDAD_PAGO
Jerarquía práctica: TipoModalidad > NumeroCuotas.
Condicion es atributo descriptivo.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_MODALIDAD_PAGO AS d
USING(
    SELECT
        tipo_modalidad AS TipoModalidad,
        numero_cuotas AS NumeroCuotas,
        condicion AS Condicion,
        modalidad_pago_id AS idModalidadPago
    FROM MODALIDAD_PAGO
) AS s
ON d.idModalidadPago=s.idModalidadPago
WHEN NOT MATCHED THEN
    INSERT(TipoModalidad,NumeroCuotas,Condicion,idModalidadPago)
    VALUES(s.TipoModalidad,s.NumeroCuotas,s.Condicion,s.idModalidadPago);
GO

/* ============================================================================
13. DIM_MEDIO_PAGO
Ruta analítica general -> específica: TipoMedio > Proveedor > MedioPago.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_MEDIO_PAGO AS d
USING(
    SELECT
        tipo_medio AS TipoMedio,
        proveedor AS Proveedor,
        nombre AS MedioPago,
        medio_pago_id AS idMedioPago
    FROM MEDIO_PAGO
) AS s
ON d.idMedioPago=s.idMedioPago
WHEN NOT MATCHED THEN
    INSERT(TipoMedio,Proveedor,MedioPago,idMedioPago)
    VALUES(s.TipoMedio,s.Proveedor,s.MedioPago,s.idMedioPago);
GO

/* ============================================================================
14. DIM_PAGADOR
Orden analítico de mayor agrupación a mayor detalle:
Segmento > TipoResponsable > Relacion.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_PAGADOR AS d
USING(
    SELECT
        segmento AS Segmento,
        tipo_responsable AS TipoResponsable,
        relacion AS Relacion,
        responsable_pago_id AS idResponsablePago
    FROM RESPONSABLE_PAGO
) AS s
ON d.idResponsablePago=s.idResponsablePago
WHEN NOT MATCHED THEN
    INSERT(Segmento,TipoResponsable,Relacion,idResponsablePago)
    VALUES(s.Segmento,s.TipoResponsable,s.Relacion,s.idResponsablePago);
GO

/* ============================================================================
15. DIM_SESION
Jerarquía: TipoSesion > Modalidad.
EstadoSesion es atributo descriptivo/transaccional.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_SESION AS d
USING(
    SELECT
        tipo_sesion AS TipoSesion,
        modalidad AS Modalidad,
        estado AS EstadoSesion,
        sesion_id AS idSesion
    FROM SESION
) AS s
ON d.idSesion=s.idSesion
WHEN NOT MATCHED THEN
    INSERT(TipoSesion,Modalidad,EstadoSesion,idSesion)
    VALUES(s.TipoSesion,s.Modalidad,s.EstadoSesion,s.idSesion);
GO

/* ============================================================================
16. DIM_HITO
Jerarquía: TipoEntregable > Entregable.
Capitulo es nivel de detalle/atributo específico del hito.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_HITO AS d
USING(
    SELECT
        e.tipo_entregable AS TipoEntregable,
        e.nombre AS Entregable,
        h.capitulo AS Capitulo,
        h.hito_id AS idHito
    FROM HITO_CRONOGRAMA h
    INNER JOIN ENTREGABLE e ON e.entregable_id=h.entregable_id
) AS s
ON d.idHito=s.idHito
WHEN NOT MATCHED THEN
    INSERT(TipoEntregable,Entregable,Capitulo,idHito)
    VALUES(s.TipoEntregable,s.Entregable,s.Capitulo,s.idHito);
GO

/* ============================================================================
17. DIM_MOTIVO_ESCALAMIENTO
Orden analítico: Destino > Motivo.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_MOTIVO_ESCALAMIENTO AS d
USING(
    SELECT DISTINCT
        destino AS Destino,
        motivo AS Motivo
    FROM ESCALAMIENTO
) AS s
ON ISNULL(d.Destino,'')=ISNULL(s.Destino,'')
AND ISNULL(d.Motivo,'')=ISNULL(s.Motivo,'')
WHEN NOT MATCHED THEN
    INSERT(Destino,Motivo)
    VALUES(s.Destino,s.Motivo);
GO

/* ============================================================================
18. DIM_INDICADOR
Jerarquía: FaseIMPULSE > Indicador.
============================================================================ */
MERGE INBESTIGA_MART.dbo.DIM_INDICADOR AS d
USING(
    SELECT DISTINCT
        fase AS FaseIMPULSE,
        indicador AS Indicador
    FROM META
) AS s
ON ISNULL(d.FaseIMPULSE,'')=ISNULL(s.FaseIMPULSE,'')
AND ISNULL(d.Indicador,'')=ISNULL(s.Indicador,'')
WHEN NOT MATCHED THEN
    INSERT(FaseIMPULSE,Indicador)
    VALUES(s.FaseIMPULSE,s.Indicador);
GO

/* ============================================================================
13 HECHOS - VERSION DEFINITIVA
Estructura conservada del docente:
DELETE -> INSERT INTO -> SELECT -> JOIN dimensiones -> GROUP BY cuando corresponde.

Regla adicional: cada carga respeta estrictamente el grano declarado.
============================================================================ */

/* ============================================================================
1. FACT_CAPTACION_BUYER
Grano: 1 fila por BUYER registrado.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_CAPTACION_BUYER;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_CAPTACION_BUYER
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyCanalCaptacion, KeyContenido, KeyServicio,
    buyer_registrado, lead_generado, buyer_con_interaccion_valor, buyer_con_descarga,
    minutos_hasta_primera_interaccion, buyer_sin_cobertura
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyCanalCaptacion = ISNULL(dcan.KeyCanalCaptacion,0),
    KeyContenido = ISNULL(dcon.KeyContenido,0),
    KeyServicio = ISNULL(ds.KeyServicio,0),
    buyer_registrado = 1,
    lead_generado = CASE WHEN l.lead_id IS NULL THEN 0 ELSE 1 END,
    buyer_con_interaccion_valor = CASE WHEN iv.interaccion_id IS NULL THEN 0 ELSE 1 END,
    buyer_con_descarga = CASE WHEN dd.descarga_id IS NULL THEN 0 ELSE 1 END,
    minutos_hasta_primera_interaccion =
        CASE WHEN iv.fecha_interaccion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,b.fecha_buyer,iv.fecha_interaccion) END,
    buyer_sin_cobertura =
        CASE WHEN b.estado='SIN_COBERTURA' THEN 1 ELSE 0 END
FROM BUYER b
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(b.fecha_buyer AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_CANAL_CAPTACION dcan
    ON dcan.idCanal=b.canal_captacion_id
   AND dcan.idCampania=ISNULL(b.campania_id,0)
LEFT JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=b.servicio_interes_id
LEFT JOIN LEAD l
    ON l.buyer_id=b.buyer_id
LEFT JOIN INTERACCION_CAPTACION iv
    ON iv.interaccion_id=(
        SELECT MIN(i2.interaccion_id)
        FROM INTERACCION_CAPTACION i2
        WHERE i2.buyer_id=b.buyer_id AND i2.es_valor=1
    )
LEFT JOIN DESCARGA_CONTENIDO dd
    ON dd.descarga_id=(
        SELECT MIN(d2.descarga_id)
        FROM DESCARGA_CONTENIDO d2
        WHERE d2.buyer_id=b.buyer_id
    )
LEFT JOIN INBESTIGA_MART.dbo.DIM_CONTENIDO dcon
    ON dcon.idContenido=COALESCE(dd.contenido_id,iv.contenido_id);
GO

/* ============================================================================
2. FACT_SEGUIMIENTO_BUYER
Grano: 1 fila por SEGUIMIENTO_BUYER.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_SEGUIMIENTO_BUYER;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_SEGUIMIENTO_BUYER
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeySeguimiento,
    buyer_inactivo_contactado, buyer_reactivado
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeySeguimiento = dsg.KeySeguimiento,
    buyer_inactivo_contactado = 1,
    buyer_reactivado =
        CASE WHEN sb.resultado='REACTIVADO'
               OR EXISTS(
                   SELECT 1 FROM LEAD l
                   WHERE l.buyer_id=b.buyer_id AND l.fecha_lead>sb.fecha_envio
               )
             THEN 1 ELSE 0 END
FROM SEGUIMIENTO_BUYER sb
INNER JOIN BUYER b
    ON b.buyer_id=sb.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(sb.fecha_envio AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SEGUIMIENTO dsg
    ON dsg.idSeguimientoBuyer=sb.seguimiento_buyer_id;
GO

/* ============================================================================
3. FACT_CAMPANIA
Grano: 1 fila por CAMPAÑA.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_CAMPANIA;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_CAMPANIA
(
    KeyTiempo, KeyCanalCaptacion, inversion, buyers_generados
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyCanalCaptacion = dcan.KeyCanalCaptacion,
    inversion = cp.inversion,
    buyers_generados = COUNT(b.buyer_id)
FROM CAMPANIA cp
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=cp.fecha_inicio
INNER JOIN INBESTIGA_MART.dbo.DIM_CANAL_CAPTACION dcan
    ON dcan.idCanal=cp.canal_id
   AND dcan.idCampania=cp.campania_id
LEFT JOIN BUYER b
    ON b.campania_id=cp.campania_id
GROUP BY
    dt.KeyTiempo,
    dcan.KeyCanalCaptacion,
    cp.inversion;
GO

/* ============================================================================
4. FACT_DIAGNOSTICO_LEAD
Grano: 1 fila por DIAGNOSTICO.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_DIAGNOSTICO_LEAD;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_DIAGNOSTICO_LEAD
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyInvestigacion,
    lead_solicita_diagnostico, perfil_completo, diagnostico_solicitado,
    diagnostico_48h, horas_diagnostico
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyInvestigacion = di.KeyInvestigacion,
    lead_solicita_diagnostico = 1,
    perfil_completo = ISNULL(CAST(pn.completo AS INT),0),
    diagnostico_solicitado = 1,
    diagnostico_48h =
        CASE WHEN d.fecha_entrega IS NOT NULL
                  AND DATEDIFF(HOUR,d.fecha_solicitud,d.fecha_entrega)<=48
             THEN 1 ELSE 0 END,
    horas_diagnostico =
        CASE WHEN d.fecha_entrega IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,d.fecha_solicitud,d.fecha_entrega)/60.0 END
FROM DIAGNOSTICO d
INNER JOIN LEAD l
    ON l.lead_id=d.lead_id
INNER JOIN BUYER b
    ON b.buyer_id=l.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
LEFT JOIN PERFIL_NEGOCIACION pn
    ON pn.lead_id=l.lead_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(d.fecha_solicitud AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
INNER JOIN INBESTIGA_MART.dbo.DIM_INVESTIGACION di
    ON di.idDiagnostico=d.diagnostico_id;
GO

/* ============================================================================
5. FACT_NEGOCIACION_LEAD
Grano: 1 fila por LEAD.
Se utiliza la primera propuesta de la cohorte y la primera aceptación.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_NEGOCIACION_LEAD;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_NEGOCIACION_LEAD
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyServicio, KeyAsesor,
    KeyOrigenPropuesta, KeyCanalCaptacion,
    lead_con_propuesta, lead_con_propuesta_aceptada,
    horas_hasta_aceptacion, horas_hasta_primera_propuesta,
    lead_cohorte, payer_generado, monto_descuento, precio_base,
    propuesta_en_minimo, propuesta_aceptada
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyServicio = ISNULL(ds.KeyServicio,0),
    KeyAsesor = ISNULL(da.KeyAsesor,0),
    KeyOrigenPropuesta = ISNULL(dop.KeyOrigenPropuesta,0),
    KeyCanalCaptacion = ISNULL(dcan.KeyCanalCaptacion,0),
    lead_con_propuesta = CASE WHEN p.propuesta_id IS NULL THEN 0 ELSE 1 END,
    lead_con_propuesta_aceptada = CASE WHEN ra.fecha_aceptacion IS NULL THEN 0 ELSE 1 END,
    horas_hasta_aceptacion =
        CASE WHEN ra.fecha_aceptacion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,l.fecha_lead,ra.fecha_aceptacion)/60.0 END,
    horas_hasta_primera_propuesta =
        CASE WHEN p.fecha_presentacion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,l.fecha_lead,p.fecha_presentacion)/60.0 END,
    lead_cohorte = 1,
    payer_generado = CASE WHEN py.payer_id IS NULL THEN 0 ELSE 1 END,
    monto_descuento = ISNULL(p.descuento,0),
    precio_base = ISNULL(p.precio_base,0),
    propuesta_en_minimo =
        CASE WHEN p.propuesta_id IS NOT NULL
                  AND p.precio_final<=p.precio_minimo_aplicado
             THEN 1 ELSE 0 END,
    propuesta_aceptada = CASE WHEN ra.fecha_aceptacion IS NULL THEN 0 ELSE 1 END
FROM LEAD l
INNER JOIN BUYER b
    ON b.buyer_id=l.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(l.fecha_lead AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
LEFT JOIN PROPUESTA p
    ON p.propuesta_id=(
        SELECT MIN(p2.propuesta_id)
        FROM PROPUESTA p2
        WHERE p2.lead_id=l.lead_id
    )
LEFT JOIN (
    SELECT p3.lead_id, MIN(rp.fecha_respuesta) AS fecha_aceptacion
    FROM PROPUESTA p3
    INNER JOIN RESPUESTA_PROPUESTA rp
        ON rp.propuesta_id=p3.propuesta_id
       AND rp.tipo_respuesta='ACEPTA'
    GROUP BY p3.lead_id
) ra
    ON ra.lead_id=l.lead_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=p.servicio_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_ASESOR da
    ON da.idAsesor=COALESCE(p.asesor_id,l.asesor_id)
LEFT JOIN INBESTIGA_MART.dbo.DIM_ORIGEN_PROPUESTA dop
    ON dop.GeneradaPor=p.generada_por
LEFT JOIN INBESTIGA_MART.dbo.DIM_CANAL_CAPTACION dcan
    ON dcan.idCanal=b.canal_captacion_id
   AND dcan.idCampania=ISNULL(b.campania_id,0)
LEFT JOIN PAYER py
    ON py.lead_id=l.lead_id;
GO

/* ============================================================================
6. FACT_OBJECION_LEAD
Grano: 1 fila por LEAD con objecion.
Se conserva la objecion principal: mayor repeticion; en empate, la primera.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_OBJECION_LEAD;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_OBJECION_LEAD
(
    KeyTiempo, KeyObjecion, KeyServicio, KeyAsesor,
    lead_con_objecion, lead_recuperado, lead_objecion_escalada
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyObjecion = dob.KeyObjecion,
    KeyServicio = ds.KeyServicio,
    KeyAsesor = ISNULL(da.KeyAsesor,0),
    lead_con_objecion = 1,
    lead_recuperado =
        CASE WHEN EXISTS(
            SELECT 1
            FROM PROPUESTA p2
            INNER JOIN RESPUESTA_PROPUESTA rp2
                ON rp2.propuesta_id=p2.propuesta_id
            WHERE p2.lead_id=l.lead_id
              AND rp2.tipo_respuesta='ACEPTA'
        ) THEN 1 ELSE 0 END,
    lead_objecion_escalada = CAST(o.escalada AS INT)
FROM LEAD l
INNER JOIN OBJECION o
    ON o.objecion_id=(
        SELECT TOP 1 o2.objecion_id
        FROM OBJECION o2
        INNER JOIN PROPUESTA p2
            ON p2.propuesta_id=o2.propuesta_id
        WHERE p2.lead_id=l.lead_id
        ORDER BY o2.veces_repetida DESC, o2.fecha_registro, o2.objecion_id
    )
INNER JOIN PROPUESTA p
    ON p.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(o.fecha_registro AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_OBJECION dob
    ON dob.idObjecion=o.objecion_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=p.servicio_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_ASESOR da
    ON da.idAsesor=COALESCE(p.asesor_id,l.asesor_id);
GO

/* ============================================================================
7. FACT_COBRANZA
Grano: 1 fila por ORDEN_PAGO.
Las tablas de detalle se agregan antes del JOIN para evitar duplicaciones.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_COBRANZA;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_COBRANZA
(
    KeyTiempo, KeyServicio, KeyModalidadPago, KeyPagador,
    orden_creada, orden_con_pago, minutos_a_primer_pago,
    pendiente_alertado, pendiente_recuperado,
    monto_exigible, monto_cobrado
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyServicio = ds.KeyServicio,
    KeyModalidadPago = dmp.KeyModalidadPago,
    KeyPagador = ISNULL(dpg.KeyPagador,0),
    orden_creada = 1,
    orden_con_pago = CASE WHEN pg.cantidad_pagos>0 THEN 1 ELSE 0 END,
    minutos_a_primer_pago =
        CASE WHEN pg.primera_confirmacion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,o.fecha_creacion,pg.primera_confirmacion) END,
    pendiente_alertado = CASE WHEN ac.cantidad_alertas>0 THEN 1 ELSE 0 END,
    pendiente_recuperado = ISNULL(ac.recuperado,0),
    monto_exigible = ISNULL(cp.monto_exigible,0),
    monto_cobrado = ISNULL(pg.monto_cobrado,0)
FROM ORDEN_PAGO o
INNER JOIN PROPUESTA p
    ON p.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(o.fecha_creacion AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=p.servicio_id
INNER JOIN INBESTIGA_MART.dbo.DIM_MODALIDAD_PAGO dmp
    ON dmp.idModalidadPago=o.modalidad_pago_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_PAGADOR dpg
    ON dpg.idResponsablePago=o.responsable_pago_id
LEFT JOIN (
    SELECT orden_pago_id, SUM(monto_programado) AS monto_exigible
    FROM CUOTA_PAGO
    GROUP BY orden_pago_id
) cp
    ON cp.orden_pago_id=o.orden_pago_id
LEFT JOIN (
    SELECT
        orden_pago_id,
        COUNT(*) AS cantidad_pagos,
        MIN(fecha_confirmacion) AS primera_confirmacion,
        SUM(monto_pagado) AS monto_cobrado
    FROM PAGO
    WHERE estado='CONFIRMADO'
    GROUP BY orden_pago_id
) pg
    ON pg.orden_pago_id=o.orden_pago_id
LEFT JOIN (
    SELECT
        orden_pago_id,
        COUNT(*) AS cantidad_alertas,
        MAX(CASE WHEN resultado='RECUPERADO' THEN 1 ELSE 0 END) AS recuperado
    FROM ALERTA_COBRANZA
    GROUP BY orden_pago_id
) ac
    ON ac.orden_pago_id=o.orden_pago_id;
GO

/* ============================================================================
8. FACT_PAGO
Grano: 1 fila por PAGO confirmado.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_PAGO;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_PAGO
(
    KeyTiempo, KeyServicio, KeyModalidadPago, KeyMedioPago,
    pago_por_webhook, pago_confirmado, comision_pasarela, monto_pagado
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyServicio = ds.KeyServicio,
    KeyModalidadPago = dmp.KeyModalidadPago,
    KeyMedioPago = dmed.KeyMedioPago,
    pago_por_webhook = CASE WHEN ew.eventos>0 THEN 1 ELSE 0 END,
    pago_confirmado = 1,
    comision_pasarela = p.comision_pasarela,
    monto_pagado = p.monto_pagado
FROM PAGO p
INNER JOIN ORDEN_PAGO o
    ON o.orden_pago_id=p.orden_pago_id
INNER JOIN PROPUESTA pr
    ON pr.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(p.fecha_confirmacion AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=pr.servicio_id
INNER JOIN INBESTIGA_MART.dbo.DIM_MODALIDAD_PAGO dmp
    ON dmp.idModalidadPago=o.modalidad_pago_id
INNER JOIN INBESTIGA_MART.dbo.DIM_MEDIO_PAGO dmed
    ON dmed.idMedioPago=p.medio_pago_id
LEFT JOIN (
    SELECT pago_id, COUNT(*) AS eventos
    FROM EVENTO_WEBHOOK
    WHERE procesado=1
    GROUP BY pago_id
) ew
    ON ew.pago_id=p.pago_id
WHERE p.estado='CONFIRMADO'
  AND p.fecha_confirmacion IS NOT NULL;
GO

/* ============================================================================
9. FACT_CUSTOMER_SERVICIO
Grano: 1 fila por CUSTOMER / servicio activado.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_CUSTOMER_SERVICIO;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_CUSTOMER_SERVICIO
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyServicio, KeyAsesor,
    customer_activado, asignacion_24h, horas_asignacion,
    primera_sesion_48h, encuesta_respondida, puntaje_satisfaccion,
    ingresos, comision_pasarela, honorarios, costo_turnitin, margen
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyServicio = ds.KeyServicio,
    KeyAsesor = ISNULL(da.KeyAsesor,0),
    customer_activado = 1,
    asignacion_24h =
        CASE WHEN aa.fecha_asignacion IS NOT NULL
                  AND DATEDIFF(HOUR,c.fecha_activacion,aa.fecha_asignacion)<=24
             THEN 1 ELSE 0 END,
    horas_asignacion =
        CASE WHEN aa.fecha_asignacion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,c.fecha_activacion,aa.fecha_asignacion)/60.0 END,
    primera_sesion_48h =
        CASE WHEN sp.primera_sesion IS NOT NULL
                  AND DATEDIFF(HOUR,c.fecha_activacion,sp.primera_sesion)<=48
             THEN 1 ELSE 0 END,
    encuesta_respondida = CASE WHEN es.cantidad_encuestas>0 THEN 1 ELSE 0 END,
    puntaje_satisfaccion = es.puntaje_promedio,
    ingresos = ISNULL(m.ingresos,0),
    comision_pasarela = ISNULL(m.comision_pasarela,0),
    honorarios = ISNULL(m.honorarios,0),
    costo_turnitin = ISNULL(m.costo_turnitin,0),
    margen = ISNULL(m.margen,0)
FROM CUSTOMER c
INNER JOIN PAYER py
    ON py.payer_id=c.payer_id
INNER JOIN LEAD l
    ON l.lead_id=py.lead_id
INNER JOIN BUYER b
    ON b.buyer_id=l.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN ORDEN_PAGO o
    ON o.orden_pago_id=py.orden_pago_id
INNER JOIN PROPUESTA pr
    ON pr.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(c.fecha_activacion AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=pr.servicio_id
LEFT JOIN ASIGNACION_ASESOR aa
    ON aa.asignacion_id=(
        SELECT MIN(a2.asignacion_id)
        FROM ASIGNACION_ASESOR a2
        WHERE a2.customer_id=c.customer_id
    )
LEFT JOIN INBESTIGA_MART.dbo.DIM_ASESOR da
    ON da.idAsesor=aa.asesor_id
LEFT JOIN (
    SELECT customer_id, MIN(fecha_programada) AS primera_sesion
    FROM SESION
    GROUP BY customer_id
) sp
    ON sp.customer_id=c.customer_id
LEFT JOIN (
    SELECT
        customer_id,
        COUNT(*) AS cantidad_encuestas,
        AVG(CAST(puntaje AS DECIMAL(10,2))) AS puntaje_promedio
    FROM ENCUESTA_SATISFACCION
    GROUP BY customer_id
) es
    ON es.customer_id=c.customer_id
INNER JOIN v_MargenCustomer m
    ON m.customer_id=c.customer_id;
GO

/* ============================================================================
10. FACT_SESION
Grano: 1 fila por SESION.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_SESION;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_SESION
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyServicio, KeyAsesor, KeySesion,
    sesion_programada, sesion_reprogramada
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyServicio = ds.KeyServicio,
    KeyAsesor = da.KeyAsesor,
    KeySesion = dse.KeySesion,
    sesion_programada = 1,
    sesion_reprogramada = CASE WHEN rp.reprogramaciones>0 THEN 1 ELSE 0 END
FROM SESION s
INNER JOIN CUSTOMER c
    ON c.customer_id=s.customer_id
INNER JOIN PAYER py
    ON py.payer_id=c.payer_id
INNER JOIN LEAD l
    ON l.lead_id=py.lead_id
INNER JOIN BUYER b
    ON b.buyer_id=l.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN ORDEN_PAGO o
    ON o.orden_pago_id=py.orden_pago_id
INNER JOIN PROPUESTA pr
    ON pr.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(s.fecha_programada AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=pr.servicio_id
INNER JOIN INBESTIGA_MART.dbo.DIM_ASESOR da
    ON da.idAsesor=s.asesor_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SESION dse
    ON dse.idSesion=s.sesion_id
LEFT JOIN (
    SELECT sesion_id, COUNT(*) AS reprogramaciones
    FROM REPROGRAMACION_SESION
    GROUP BY sesion_id
) rp
    ON rp.sesion_id=s.sesion_id;
GO

/* ============================================================================
11. FACT_HITO_CALIDAD
Grano: 1 fila por HITO_CRONOGRAMA.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_HITO_CALIDAD;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_HITO_CALIDAD
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyServicio, KeyAsesor, KeyHito,
    hito_evaluado, hito_a_tiempo, dias_desviacion,
    reporte_emitido, reporte_cumple_umbral,
    dias_levantamiento, observacion_levantada, ronda_extra, observacion_recibida
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = de.KeyEstudiante,
    KeyCarrera = dc.KeyCarrera,
    KeyServicio = ds.KeyServicio,
    KeyAsesor = ISNULL(da.KeyAsesor,0),
    KeyHito = dh.KeyHito,
    hito_evaluado = 1,
    hito_a_tiempo =
        CASE WHEN h.fecha_entrega_real IS NOT NULL
                  AND h.fecha_entrega_real<=h.fecha_pactada
             THEN 1 ELSE 0 END,
    dias_desviacion =
        CASE WHEN h.fecha_entrega_real IS NULL THEN NULL
             ELSE DATEDIFF(DAY,h.fecha_pactada,h.fecha_entrega_real) END,
    reporte_emitido = ISNULL(rc.reporte_emitido,0),
    reporte_cumple_umbral = ISNULL(rc.reporte_cumple_umbral,0),
    dias_levantamiento = ISNULL(ou.dias_levantamiento,0),
    observacion_levantada = ISNULL(ou.observacion_levantada,0),
    ronda_extra = ISNULL(ou.ronda_extra,0),
    observacion_recibida = ISNULL(ou.observacion_recibida,0)
FROM HITO_CRONOGRAMA h
INNER JOIN CUSTOMER c
    ON c.customer_id=h.customer_id
INNER JOIN PAYER py
    ON py.payer_id=c.payer_id
INNER JOIN LEAD l
    ON l.lead_id=py.lead_id
INNER JOIN BUYER b
    ON b.buyer_id=l.buyer_id
INNER JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=b.contacto_id
INNER JOIN ORDEN_PAGO o
    ON o.orden_pago_id=py.orden_pago_id
INNER JOIN PROPUESTA pr
    ON pr.propuesta_id=o.propuesta_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(h.fecha_pactada AS DATE)
INNER JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
INNER JOIN INBESTIGA_MART.dbo.DIM_SERVICIO ds
    ON ds.idServicio=pr.servicio_id
LEFT JOIN ASIGNACION_ASESOR aa
    ON aa.asignacion_id=(
        SELECT MIN(a2.asignacion_id)
        FROM ASIGNACION_ASESOR a2
        WHERE a2.customer_id=c.customer_id
    )
LEFT JOIN INBESTIGA_MART.dbo.DIM_ASESOR da
    ON da.idAsesor=aa.asesor_id
INNER JOIN INBESTIGA_MART.dbo.DIM_HITO dh
    ON dh.idHito=h.hito_id
LEFT JOIN (
    SELECT
        hito_id,
        COUNT(*) AS reporte_emitido,
        SUM(CASE WHEN cumple_umbral=1 THEN 1 ELSE 0 END) AS reporte_cumple_umbral
    FROM REPORTE_CALIDAD
    GROUP BY hito_id
) rc
    ON rc.hito_id=h.hito_id
LEFT JOIN (
    SELECT
        hito_id,
        SUM(CASE WHEN fecha_levantamiento IS NOT NULL
                 THEN DATEDIFF(DAY,fecha_recepcion,fecha_levantamiento)
                 ELSE 0 END) AS dias_levantamiento,
        SUM(CASE WHEN fecha_levantamiento IS NOT NULL THEN 1 ELSE 0 END) AS observacion_levantada,
        SUM(CASE WHEN es_ronda_extra=1 THEN 1 ELSE 0 END) AS ronda_extra,
        COUNT(*) AS observacion_recibida
    FROM OBSERVACION_UNIVERSITARIA
    GROUP BY hito_id
) ou
    ON ou.hito_id=h.hito_id;
GO

/* ============================================================================
12. FACT_CONVERSACION
Grano: 1 fila por CONVERSACION.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_CONVERSACION;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_CONVERSACION
(
    KeyTiempo, KeyEstudiante, KeyCarrera, KeyCanalCaptacion, KeyMotivoEscalamiento,
    conversacion_iniciada, segundos_primera_respuesta,
    conversacion_resuelta_sin_humano, conversacion_escalada,
    escalamiento, escalamiento_atendido, minutos_hasta_atencion
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyEstudiante = ISNULL(de.KeyEstudiante,0),
    KeyCarrera = ISNULL(dc.KeyCarrera,0),
    KeyCanalCaptacion = ISNULL(dcan.KeyCanalCaptacion,0),
    KeyMotivoEscalamiento =
        CASE WHEN e.escalamiento_id IS NULL THEN 0
             ELSE ISNULL(dme.KeyMotivoEscalamiento,-1) END,
    conversacion_iniciada = 1,
    segundos_primera_respuesta =
        CASE WHEN mb.fecha_mensaje IS NULL THEN NULL
             ELSE DATEDIFF(SECOND,c.fecha_inicio,mb.fecha_mensaje) END,
    conversacion_resuelta_sin_humano = CAST(c.resuelta_sin_humano AS INT),
    conversacion_escalada = CASE WHEN e.escalamiento_id IS NULL THEN 0 ELSE 1 END,
    escalamiento = CASE WHEN e.escalamiento_id IS NULL THEN 0 ELSE 1 END,
    escalamiento_atendido = CASE WHEN e.fecha_atencion IS NULL THEN 0 ELSE 1 END,
    minutos_hasta_atencion =
        CASE WHEN e.fecha_atencion IS NULL THEN NULL
             ELSE DATEDIFF(MINUTE,e.fecha,e.fecha_atencion) END
FROM CONVERSACION c
LEFT JOIN PERFIL_ACADEMICO pa
    ON pa.contacto_id=c.contacto_id
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=CAST(c.fecha_inicio AS DATE)
LEFT JOIN INBESTIGA_MART.dbo.DIM_ESTUDIANTE de
    ON de.idPerfilAcademico=pa.perfil_academico_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=pa.carrera_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_CANAL_CAPTACION dcan
    ON dcan.idCanal=c.canal_id
   AND dcan.idCampania=ISNULL(c.campania_id,0)
LEFT JOIN ESCALAMIENTO e
    ON e.conversacion_id=c.conversacion_id
LEFT JOIN INBESTIGA_MART.dbo.DIM_MOTIVO_ESCALAMIENTO dme
    ON ISNULL(dme.Destino,'')=ISNULL(e.destino,'')
   AND ISNULL(dme.Motivo,'')=ISNULL(e.motivo,'')
LEFT JOIN MENSAJE mb
    ON mb.mensaje_id=(
        SELECT MIN(m2.mensaje_id)
        FROM MENSAJE m2
        WHERE m2.conversacion_id=c.conversacion_id
          AND m2.emisor='BOT'
    );
GO

/* ============================================================================
13. FACT_META
Grano: 1 fila por PERIODO + CARRERA + INDICADOR.
============================================================================ */
DELETE FROM INBESTIGA_MART.dbo.FACT_META;
GO

INSERT INTO INBESTIGA_MART.dbo.FACT_META
(
    KeyTiempo, KeyIndicador, KeyCarrera, valor_meta, valor_real
)
SELECT
    KeyTiempo = dt.KeyTiempo,
    KeyIndicador = di.KeyIndicador,
    KeyCarrera = dc.KeyCarrera,
    valor_meta = SUM(m.valor_meta),
    valor_real = SUM(m.valor_real)
FROM META m
INNER JOIN INBESTIGA_MART.dbo.DIM_TIEMPO dt
    ON dt.idFecha=m.periodo
INNER JOIN INBESTIGA_MART.dbo.DIM_INDICADOR di
    ON ISNULL(di.FaseIMPULSE,'')=ISNULL(m.fase,'')
   AND ISNULL(di.Indicador,'')=ISNULL(m.indicador,'')
INNER JOIN INBESTIGA_MART.dbo.DIM_CARRERA dc
    ON dc.idCarrera=m.carrera_id
GROUP BY
    dt.KeyTiempo,
    di.KeyIndicador,
    dc.KeyCarrera;
GO

/* ============================================================================
RECONCILIACIONES BASICAS
============================================================================ */
PRINT 'RECONCILIACION 1 - PAGOS CONFIRMADOS';
SELECT
    OLTP = CAST(ISNULL((SELECT SUM(monto_pagado) FROM PAGO WHERE estado='CONFIRMADO'),0) AS DECIMAL(18,2)),
    DATAMART = CAST(ISNULL((SELECT SUM(monto_pagado) FROM INBESTIGA_MART.dbo.FACT_PAGO),0) AS DECIMAL(18,2));
GO

PRINT 'RECONCILIACION 2 - BUYERS REGISTRADOS';
SELECT
    OLTP = (SELECT COUNT(*) FROM BUYER),
    DATAMART = ISNULL((SELECT SUM(buyer_registrado) FROM INBESTIGA_MART.dbo.FACT_CAPTACION_BUYER),0);
GO

PRINT 'RECONCILIACION 3 - INVERSION CAMPANIAS';
SELECT
    OLTP = CAST(ISNULL((SELECT SUM(inversion) FROM CAMPANIA),0) AS DECIMAL(18,2)),
    DATAMART = CAST(ISNULL((SELECT SUM(inversion) FROM INBESTIGA_MART.dbo.FACT_CAMPANIA),0) AS DECIMAL(18,2));
GO

PRINT 'RECONCILIACION 4 - CUSTOMERS';
SELECT
    OLTP = (SELECT COUNT(*) FROM CUSTOMER),
    DATAMART = ISNULL((SELECT SUM(customer_activado) FROM INBESTIGA_MART.dbo.FACT_CUSTOMER_SERVICIO),0);
GO

PRINT 'ETL DEFINITIVO COMPLETADO.';
GO