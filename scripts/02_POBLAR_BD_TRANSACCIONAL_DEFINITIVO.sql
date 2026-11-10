/* =============================================================
02_POBLAR_BD_TRANSACCIONAL.sql
Poblamiento determinista definitivo para pruebas BI.
Compatible con 01_CREAR_BD_TRANSACCIONAL_DEFINITIVO.sql.
============================================================= */
USE INBESTIGA_TESIS;
GO
SET NOCOUNT ON;

INSERT UNIVERSIDAD(nombre,tipo,departamento,distrito,norma_citacion,atendida) VALUES
('Universidad Nacional de Trujillo','PUBLICA','La Libertad','Trujillo','APA 7',1),
('Universidad Privada Antenor Orrego','PRIVADA','La Libertad','Trujillo','APA 7',1),
('Universidad Cesar Vallejo','PRIVADA','La Libertad','Trujillo','APA 7',1),
('Universidad Privada del Norte','PRIVADA','La Libertad','Trujillo','APA 7',1),
('Universidad Catolica de Trujillo','PRIVADA','La Libertad','Trujillo','APA 7',1);
INSERT CARRERA(universidad_id,nombre,facultad,atendida)
SELECT universidad_id,'Ingenieria de Sistemas','Ingenieria',1 FROM UNIVERSIDAD;
INSERT CARRERA(universidad_id,nombre,facultad,atendida)
SELECT universidad_id,'Administracion','Ciencias Empresariales',1 FROM UNIVERSIDAD;

INSERT CANAL(nombre,tipo,plataforma) VALUES
('WhatsApp organico','ORGANICO','WhatsApp'),('Instagram Ads','PAGADO','Instagram'),('Facebook Ads','PAGADO','Facebook'),('Referido','REFERIDO','Referidos');
INSERT CAMPANIA(canal_id,nombre,fecha_inicio,fecha_fin,inversion) VALUES
(2,'Agosto - Proyecto de tesis','2026-08-01','2026-08-31',1200),(3,'Setiembre - Paquete completo','2026-09-01','2026-09-30',1500),(2,'Octubre - Cierre de ciclo','2026-10-01','2026-10-31',1800);
INSERT SERVICIO(familia,nombre,tipo_servicio,paquete,modalidad,precio_referencia) VALUES
('DIAGNOSTICO','Diagnostico gratuito','DIAGNOSTICO','INICIAL','VIRTUAL',0),
('ASESORIA','Proyecto de tesis','PROYECTO','BACHILLER','VIRTUAL',1800),
('ASESORIA','Informe de tesis','INFORME','TITULO','VIRTUAL',2400),
('ASESORIA','Paquete completo','COMPLETO','TITULO','HIBRIDA',3900),
('COMPLEMENTARIO','Revision de similitud y redaccion','REVISION','COMPLEMENTARIO','VIRTUAL',150);
INSERT ENTREGABLE(nombre,tipo_entregable,descripcion,precio_extra) VALUES
('Proyecto aprobado','PROYECTO','Documento de proyecto',0),('Capitulo metodologico','CAPITULO','Metodologia',0),('Reporte de similitud','CALIDAD','Turnitin',0),('Simulacro de sustentacion','SUSTENTACION','Sesion de preparacion',0),('PPT de sustentacion','EXTRA','Presentacion',250);
INSERT SERVICIO_ENTREGABLE(servicio_id,entregable_id,cantidad_incluida,umbral_pct,frecuencia_dias,duracion_min,precio_unidad_extra)
VALUES (2,1,1,NULL,7,NULL,0),(3,2,1,NULL,7,NULL,0),(4,3,4,20,7,NULL,25),(4,4,2,NULL,14,90,100),(4,5,0,NULL,NULL,NULL,250);
INSERT CONTENIDO(servicio_id,tipo_contenido,tema,titulo) VALUES
(2,'INFOGRAFIA','Proyecto','Estructura del proyecto'),(3,'GUIA','Informe','Ruta del informe'),(4,'INFOGRAFIA','Completo','Beneficios del paquete completo');
INSERT PLANTILLA_MENSAJE(nombre,tipo,contenido,ventana) VALUES
('Bienvenida','CAPTACION','Hola, soy el asistente virtual de INBESTIGA.','24H'),('Seguimiento 24h','SEGUIMIENTO','¿Deseas continuar con tu diagnóstico?','72H'),('Cobranza 1','COBRANZA','Tu cuota está pendiente.','72H'),('Recordatorio sesion','SERVICIO','Te recordamos tu próxima sesión.','72H');
INSERT ASESOR(nombre,rol,equipo,especialidad) VALUES
('Andrea Comercial','COMERCIAL','Ventas','Negociacion'),('Carlos Sistemas','ACADEMICO','Academico','Ingenieria de Sistemas'),('Maria Negocios','ACADEMICO','Academico','Administracion'),('Supervisor','ADMIN','Direccion','Gestion');
INSERT ASESOR_CARRERA(asesor_id,carrera_id) SELECT 2,carrera_id FROM CARRERA WHERE nombre='Ingenieria de Sistemas';
INSERT ASESOR_CARRERA(asesor_id,carrera_id) SELECT 3,carrera_id FROM CARRERA WHERE nombre='Administracion';
INSERT TARIFA(servicio_id,carrera_id,etapa_academica,precio_base,precio_minimo,tope_descuento_pct,vigente_desde,activo)
SELECT s.servicio_id,NULL,NULL,s.precio_referencia,CASE WHEN s.precio_referencia=0 THEN 0 ELSE s.precio_referencia*0.85 END,25,'2026-01-01',1 FROM SERVICIO s;
INSERT REGLA_PRECIO(nombre,tipo,factor,valor_condicion,umbral_dias,porcentaje,vigente_desde) VALUES
('Urgencia menor a 15 dias','RECARGO',NULL,'URGENTE',15,10,'2026-01-01'),('Descuento cierre','DESCUENTO',NULL,'PROMO',NULL,10,'2026-01-01');
INSERT PLANTILLA_CONTRATO(nombre,version,clausulas_variables,vigente_desde) VALUES('Contrato estandar',1,'Plazos, cuotas y penalidad','2026-01-01');
INSERT MODALIDAD_PAGO(nombre,tipo_modalidad,numero_cuotas,condicion) VALUES
('Contado','CONTADO',1,'100% al inicio'),('3 cuotas','CUOTAS',3,'40/30/30'),('6 cuotas','CUOTAS',6,'Inicial + hitos');
INSERT MEDIO_PAGO(nombre,tipo_medio,proveedor,comision_pct,automatico) VALUES
('Yape','BILLETERA','Yape',0,0),('Transferencia','TRANSFERENCIA','Banco',0,0),('Tarjeta','TARJETA','Culqi',3.5,1);
INSERT HONORARIO_TARIFA(servicio_id,rol,monto_base,vigente_desde) VALUES (2,'ACADEMICO',500,'2026-01-01'),(3,'ACADEMICO',700,'2026-01-01'),(4,'ACADEMICO',1000,'2026-01-01');
INSERT LICENCIA_HERRAMIENTA(nombre,proveedor,costo_mensual,fecha_inicio) VALUES('Turnitin','Turnitin',500,'2026-01-01'),('WhatsApp API','Meta',200,'2026-01-01');

DECLARE @i INT=1,@contacto INT,@perfil INT,@buyer INT,@lead INT,@diag INT,@prop INT,@resp INT,@rp INT,@contrato INT,@orden INT,@payer INT,@customer INT,@sesion INT,@hito INT,@pago INT;
WHILE @i<=120
BEGIN
  INSERT CONTACTO(nombres,apellidos,whatsapp,correo,fecha_consentimiento,fecha_registro)
  VALUES(CONCAT('Estudiante ',@i),'Demo',CONCAT('9',RIGHT('00000000'+CAST(@i AS VARCHAR(8)),8)),CONCAT('est',@i,'@demo.pe'),DATEADD(day,@i%80,'2026-08-01'),DATEADD(day,@i%80,'2026-08-01'));
  SET @contacto=SCOPE_IDENTITY();
  INSERT PERFIL_ACADEMICO(contacto_id,carrera_id,etapa_academica,ciclo,sede,tipo_investigacion,avance)
  VALUES(@contacto,1+((@i-1)%10),CASE WHEN @i%3=0 THEN 'EGRESADO' WHEN @i%4=0 THEN 'BACHILLER' ELSE 'X CICLO' END,
         CASE WHEN @i%3=0 THEN NULL ELSE 'X' END,'TRUJILLO',CASE WHEN @i%2=0 THEN 'TESIS' ELSE 'PROYECTO' END,
         CASE WHEN @i%3=0 THEN '0-25%' WHEN @i%3=1 THEN '26-50%' ELSE '51-75%' END);
  SET @perfil=SCOPE_IDENTITY();
  INSERT BUYER(contacto_id,canal_captacion_id,campania_id,servicio_interes_id,necesidad_inicial,fecha_buyer,estado)
  VALUES(@contacto,1+((@i-1)%4),CASE WHEN @i%4=1 THEN 1 WHEN @i%4=2 THEN 2 WHEN @i%4=3 THEN 3 ELSE NULL END,
         2+((@i-1)%4),'Necesita apoyo metodologico',DATEADD(day,@i%80,'2026-08-01T09:00:00'),CASE WHEN @i%17=0 THEN 'SIN_COBERTURA' ELSE 'ACTIVO' END);
  SET @buyer=SCOPE_IDENTITY();
  INSERT INTERACCION_CAPTACION(buyer_id,canal_id,contenido_id,fecha_interaccion,tipo_interaccion,es_valor)
  VALUES(@buyer,1+((@i-1)%4),1+((@i-1)%3),DATEADD(minute,5+(@i%180),DATEADD(day,@i%80,'2026-08-01T09:00:00')),'CONSULTA',CASE WHEN @i%5<>0 THEN 1 ELSE 0 END);
  IF @i%3=0 INSERT DESCARGA_CONTENIDO(buyer_id,contenido_id,fecha_descarga) VALUES(@buyer,1+((@i-1)%3),DATEADD(hour,2,DATEADD(day,@i%80,'2026-08-01T09:00:00')));
  IF @i%4=0 INSERT SEGUIMIENTO_BUYER(buyer_id,plantilla_msg_id,fecha_envio,intento,intervalo_horas,tipo_seguimiento,resultado)
       VALUES(@buyer,2,DATEADD(day,1,DATEADD(day,@i%80,'2026-08-01T09:00:00')),1,24,'INACTIVO',CASE WHEN @i%8=0 THEN 'REACTIVADO' ELSE 'SIN_RESPUESTA' END);

  INSERT CONVERSACION(contacto_id,canal_id,campania_id,fecha_inicio,fecha_cierre,resuelta_sin_humano,estado)
  VALUES(@contacto,1+((@i-1)%4),CASE WHEN @i%4=1 THEN 1 WHEN @i%4=2 THEN 2 WHEN @i%4=3 THEN 3 ELSE NULL END,
         DATEADD(day,@i%80,'2026-08-01T08:00:00'),DATEADD(minute,30+(@i%60),DATEADD(day,@i%80,'2026-08-01T08:00:00')),CASE WHEN @i%6<>0 THEN 1 ELSE 0 END,'CERRADA');
  DECLARE @conv INT=SCOPE_IDENTITY();
  INSERT MENSAJE(conversacion_id,fecha_mensaje,emisor,tipo,contenido) VALUES(@conv,DATEADD(day,@i%80,'2026-08-01T08:00:00'),'CLIENTE','TEXTO','Hola');
  INSERT MENSAJE(conversacion_id,fecha_mensaje,emisor,tipo,contenido,plantilla_msg_id) VALUES(@conv,DATEADD(second,20+(@i%100),DATEADD(day,@i%80,'2026-08-01T08:00:00')),'BOT','TEXTO','Hola, ¿en qué te ayudo?',1);
  IF @i%6=0 INSERT ESCALAMIENTO(conversacion_id,asesor_id,fecha,fecha_atencion,motivo,destino,estado)
       VALUES(@conv,4,DATEADD(minute,5,DATEADD(day,@i%80,'2026-08-01T08:00:00')),DATEADD(minute,20+(@i%50),DATEADD(day,@i%80,'2026-08-01T08:00:00')),'SOLICITA_HUMANO','ESPECIALISTA','ATENDIDO');

  IF @i%5<>0
  BEGIN
    INSERT LEAD(buyer_id,asesor_id,fecha_lead,prioridad,estado) VALUES(@buyer,1,DATEADD(hour,3,DATEADD(day,@i%80,'2026-08-01T09:00:00')),CASE WHEN @i%3=0 THEN 'ALTA' ELSE 'MEDIA' END,'ABIERTO');
    SET @lead=SCOPE_IDENTITY();
    UPDATE ESCALAMIENTO SET lead_id=@lead WHERE conversacion_id=@conv;
    INSERT PERFIL_NEGOCIACION(lead_id,disponibilidad,urgencia,nivel_confianza,completo)
    VALUES(@lead,'NOCHES',CASE WHEN @i%4=0 THEN 'URGENTE' ELSE 'NORMAL' END,'MEDIA',CASE WHEN @i%7<>0 THEN 1 ELSE 0 END);
    INSERT DIAGNOSTICO(lead_id,fecha_solicitud,fecha_entrega,tema_tesis,tipo_tesis,avance_declarado,limitaciones,tiene_empresa_aplicacion,empresa_aplicacion)
    VALUES(@lead,DATEADD(hour,4,DATEADD(day,@i%80,'2026-08-01T09:00:00')),DATEADD(hour,10+(@i%55),DATEADD(day,@i%80,'2026-08-01T09:00:00')),
           'Transformacion digital',CASE WHEN @i%2=0 THEN 'TESIS' ELSE 'PROYECTO' END,'MEDIO','Tiempo y metodologia',CASE WHEN @i%5=0 THEN 1 ELSE 0 END,CASE WHEN @i%5=0 THEN CONCAT('Empresa ',@i) END);
    SET @diag=SCOPE_IDENTITY();
    INSERT RESPONSABLE_PAGO(lead_id,tipo_responsable,relacion,segmento,nombre,participa_decision)
    VALUES(@lead,CASE WHEN @i%3=0 THEN 'FAMILIAR' ELSE 'ESTUDIANTE' END,CASE WHEN @i%3=0 THEN 'PADRE/MADRE' ELSE 'TESISTA' END,
           CASE WHEN @i%3=0 THEN 'FAMILIA' ELSE 'DIRECTO' END,'Responsable Demo',1);
    SET @rp=SCOPE_IDENTITY();
    INSERT PROPUESTA(lead_id,servicio_id,tarifa_id,asesor_id,generada_por,fecha_presentacion,precio_base,monto_extras,descuento,recargo,precio_minimo_aplicado,tope_descuento_aplicado,vigencia_hasta,estado)
    SELECT @lead,2+((@i-1)%4),2+((@i-1)%4),1,CASE WHEN @i%4=0 THEN 'HUMANO' ELSE 'BOT' END,
           DATEADD(hour,6+(@i%8),DATEADD(day,@i%80,'2026-08-01T09:00:00')),precio_base,CASE WHEN @i%9=0 THEN 250 ELSE 0 END,
           CASE WHEN @i%3=0 THEN 150 ELSE 0 END,CASE WHEN @i%11=0 THEN 100 ELSE 0 END,precio_minimo,tope_descuento_pct,
           DATEADD(day,7,DATEADD(day,@i%80,'2026-08-01T09:00:00')),CASE WHEN @i%4<>0 THEN 'ACEPTADA' ELSE 'RECHAZADA' END
    FROM TARIFA WHERE tarifa_id=2+((@i-1)%4);
    SET @prop=SCOPE_IDENTITY();
    INSERT PROPUESTA_AJUSTE(propuesta_id,tipo,concepto,porcentaje,monto) VALUES(@prop,'DESCUENTO','Promocion',NULL,CASE WHEN @i%3=0 THEN 150 ELSE 0 END);
    INSERT PROPUESTA_ENTREGABLE(propuesta_id,entregable_id,cantidad,precio_unitario,es_extra) VALUES(@prop,1+((@i-1)%4),1,0,0);
    INSERT RESPUESTA_PROPUESTA(propuesta_id,fecha_respuesta,tipo_respuesta,observacion) VALUES(@prop,DATEADD(hour,18+(@i%30),DATEADD(day,@i%80,'2026-08-01T09:00:00')),CASE WHEN @i%4<>0 THEN 'ACEPTA' ELSE 'RECHAZA' END,NULL);
    IF @i%3=0 INSERT OBJECION(propuesta_id,grupo,tipo,descripcion,fecha_registro,veces_repetida,escalada,estado,fecha_resolucion,resultado)
         VALUES(@prop,'COMERCIAL','PRECIO','Solicita descuento',DATEADD(hour,10,DATEADD(day,@i%80,'2026-08-01T09:00:00')),1+(@i%3),CASE WHEN @i%6=0 THEN 1 ELSE 0 END,'RESUELTA',DATEADD(hour,16,DATEADD(day,@i%80,'2026-08-01T09:00:00')),CASE WHEN @i%4<>0 THEN 'RECUPERADO' ELSE 'NO_RECUPERADO' END);
    INSERT SEGUIMIENTO_LEAD(lead_id,asesor_id,canal_id,plantilla_msg_id,propuesta_id,fecha_accion,resultado,siguiente_accion)
    VALUES(@lead,1,1,2,@prop,DATEADD(hour,12,DATEADD(day,@i%80,'2026-08-01T09:00:00')),'CONTACTADO','Esperar respuesta');

    IF @i%4<>0
    BEGIN
      INSERT CONTRATO(propuesta_id,plantilla_contrato_id,fecha_generacion,fecha_confirmacion,plazo_dias,penalidad_pct,estado)
      VALUES(@prop,1,DATEADD(day,1,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,1,DATEADD(day,@i%80,'2026-08-01')),60,5,'CONFIRMADO');
      SET @contrato=SCOPE_IDENTITY();
      INSERT ORDEN_PAGO(propuesta_id,contrato_id,responsable_pago_id,modalidad_pago_id,fecha_creacion,monto_comprometido,estado)
      SELECT @prop,@contrato,@rp,CASE WHEN @i%2=0 THEN 2 ELSE 1 END,DATEADD(day,1,fecha_presentacion),precio_final,'ACTIVA' FROM PROPUESTA WHERE propuesta_id=@prop;
      SET @orden=SCOPE_IDENTITY();
      INSERT PAYER(lead_id,orden_pago_id,fecha_payer,estado) VALUES(@lead,@orden,DATEADD(day,1,DATEADD(day,@i%80,'2026-08-01')),'ACTIVO'); SET @payer=SCOPE_IDENTITY();
      DECLARE @monto DECIMAL(12,2)=(SELECT monto_comprometido FROM ORDEN_PAGO WHERE orden_pago_id=@orden);
      INSERT CUOTA_PAGO(orden_pago_id,numero_cuota,porcentaje,monto_programado,condicion,fecha_vencimiento,estado)
      VALUES(@orden,1,CASE WHEN @i%2=0 THEN 40 ELSE 100 END,CASE WHEN @i%2=0 THEN @monto*.4 ELSE @monto END,'INICIAL',DATEADD(day,2,DATEADD(day,@i%80,'2026-08-01')),'EXIGIBLE');
      DECLARE @cuota INT=SCOPE_IDENTITY();
      INSERT ENLACE_PAGO(orden_pago_id,cuota_id,medio_pago_id,referencia_externa,fecha_envio,fecha_expiracion,estado)
      VALUES(@orden,@cuota,CASE WHEN @i%2=0 THEN 3 ELSE 1 END,CONCAT('PAY-',@orden),DATEADD(day,1,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,3,DATEADD(day,@i%80,'2026-08-01')),'ENVIADO');
      INSERT PAGO(orden_pago_id,cuota_id,medio_pago_id,fecha_inicio,fecha_confirmacion,monto_pagado,comision_pasarela,referencia,metodo_verificacion,estado)
      VALUES(@orden,@cuota,CASE WHEN @i%2=0 THEN 3 ELSE 1 END,DATEADD(day,2,DATEADD(day,@i%80,'2026-08-01')),DATEADD(minute,5+(@i%25),DATEADD(day,2,DATEADD(day,@i%80,'2026-08-01'))),
             CASE WHEN @i%2=0 THEN @monto*.4 ELSE @monto END,CASE WHEN @i%2=0 THEN (@monto*.4)*.035 ELSE 0 END,CONCAT('REF-',@orden),CASE WHEN @i%2=0 THEN 'WEBHOOK' ELSE 'MANUAL' END,'CONFIRMADO');
      SET @pago=SCOPE_IDENTITY();
      IF @i%2=0 INSERT EVENTO_WEBHOOK(pago_id,proveedor,tipo_evento,fecha_recepcion,procesado,detalle) VALUES(@pago,'Culqi','payment.confirmed',DATEADD(minute,1,GETDATE()),1,'OK');
      IF @i%5=0 INSERT ALERTA_COBRANZA(orden_pago_id,cuota_id,plantilla_msg_id,fecha_envio,secuencia,tipo,resultado,escalado)
           VALUES(@orden,@cuota,3,DATEADD(day,2,DATEADD(day,@i%80,'2026-08-01')),1,'PENDIENTE',CASE WHEN @i%10=0 THEN 'RECUPERADO' ELSE 'SIN_CAMBIO' END,0);
      INSERT CUSTOMER(payer_id,fecha_activacion,estado_servicio) VALUES(@payer,DATEADD(day,3,DATEADD(day,@i%80,'2026-08-01')),'ACTIVO'); SET @customer=SCOPE_IDENTITY();
      INSERT ASIGNACION_ASESOR(customer_id,asesor_id,fecha_asignacion,activa) VALUES(@customer,CASE WHEN @i%2=0 THEN 2 ELSE 3 END,DATEADD(hour,6+(@i%25),DATEADD(day,3,DATEADD(day,@i%80,'2026-08-01'))),1);
      INSERT SESION(customer_id,asesor_id,tipo_sesion,modalidad,fecha_programada,fecha_real,duracion_min,estado)
      VALUES(@customer,CASE WHEN @i%2=0 THEN 2 ELSE 3 END,'ASESORIA','VIRTUAL',DATEADD(day,4,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,4,DATEADD(day,@i%80,'2026-08-01')),90,'REALIZADA'); SET @sesion=SCOPE_IDENTITY();
      IF @i%7=0 INSERT REPROGRAMACION_SESION(sesion_id,fecha_anterior,fecha_nueva,motivo,fecha_registro) VALUES(@sesion,DATEADD(day,4,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,5,DATEADD(day,@i%80,'2026-08-01')),'Cruce horario',DATEADD(day,3,DATEADD(day,@i%80,'2026-08-01')));
      INSERT HITO_CRONOGRAMA(customer_id,entregable_id,capitulo,fecha_pactada,fecha_entrega_real,estado)
      VALUES(@customer,1+((@i-1)%4),CONCAT('Capitulo ',1+(@i%4)),DATEADD(day,15,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,14+(@i%4),DATEADD(day,@i%80,'2026-08-01')),'ENTREGADO'); SET @hito=SCOPE_IDENTITY();
      UPDATE CUOTA_PAGO SET hito_id=@hito WHERE cuota_id=@cuota;
      INSERT REPORTE_CALIDAD(hito_id,fecha_emision,porcentaje_similitud,porcentaje_ia,umbral_vigente,cumple_umbral,costo_turnitin)
      VALUES(@hito,DATEADD(day,16,DATEADD(day,@i%80,'2026-08-01')),10+(@i%12),5+(@i%8),20,CASE WHEN (10+(@i%12))<=20 THEN 1 ELSE 0 END,25);
      IF @i%3=0 INSERT OBSERVACION_UNIVERSITARIA(hito_id,fecha_recepcion,fecha_levantamiento,estado,es_ronda_extra,monto_extra,detalle)
           VALUES(@hito,DATEADD(day,17,DATEADD(day,@i%80,'2026-08-01')),DATEADD(day,19+(@i%5),DATEADD(day,@i%80,'2026-08-01')),'LEVANTADA',CASE WHEN @i%9=0 THEN 1 ELSE 0 END,CASE WHEN @i%9=0 THEN 150 ELSE 0 END,'Ajustar referencias');
      INSERT ENCUESTA_SATISFACCION(customer_id,fecha_encuesta,puntaje,comentario) VALUES(@customer,DATEADD(day,30,DATEADD(day,@i%80,'2026-08-01')),3.5+((@i%4)*0.4),'Servicio demo');
      INSERT HONORARIO(customer_id,asesor_id,honorario_tarifa_id,fecha_devengo,monto,estado) VALUES(@customer,CASE WHEN @i%2=0 THEN 2 ELSE 3 END,1,DATEADD(day,20,DATEADD(day,@i%80,'2026-08-01')),500,'DEVENGADO');
      IF @i%12=0 INSERT ALERTA_SERVICIO(customer_id,sesion_id,hito_id,plantilla_msg_id,fecha_generacion,tipo,estado) VALUES(@customer,@sesion,@hito,4,DATEADD(day,4,DATEADD(day,@i%80,'2026-08-01')),'RECORDATORIO','ENVIADA');
      IF @i%10=0 INSERT EVALUACION_RIESGO(customer_id,fecha_evaluacion,nivel,puntaje,motivo) VALUES(@customer,DATEADD(day,10,DATEADD(day,@i%80,'2026-08-01')),'MEDIO',50,'Riesgo de retraso');
      IF @i%15=0 BEGIN INSERT CIERRE_SERVICIO(customer_id,fecha_cierre,motivo,estado_final) VALUES(@customer,DATEADD(day,60,DATEADD(day,@i%80,'2026-08-01')),'Completado','CERRADO'); INSERT CERTIFICADO_GARANTIA(customer_id,fecha_emision,vigencia_dias,condiciones,estado) VALUES(@customer,DATEADD(day,60,DATEADD(day,@i%80,'2026-08-01')),90,'Garantia de observaciones','VIGENTE'); END
    END
  END
  SET @i+=1;
END;

INSERT META(periodo,fase,indicador,carrera_id,valor_meta,valor_real)
SELECT '2026-08-01','BUYERS','B01',carrera_id,25,26 FROM CARRERA WHERE carrera_id<=5;
INSERT META(periodo,fase,indicador,carrera_id,valor_meta,valor_real)
SELECT '2026-08-01','LEADS','L05',carrera_id,20,22 FROM CARRERA WHERE carrera_id<=5;
INSERT META(periodo,fase,indicador,carrera_id,valor_meta,valor_real)
SELECT '2026-08-01','PAYERS','P04',carrera_id,90,91 FROM CARRERA WHERE carrera_id<=5;
INSERT META(periodo,fase,indicador,carrera_id,valor_meta,valor_real)
SELECT '2026-08-01','CUSTOMERS','C03',carrera_id,80,82 FROM CARRERA WHERE carrera_id<=5;

PRINT 'Poblamiento transaccional completado.';
GO
