-- Ejemplo de datos para el sistema de consejos
-- Este script es opcional y sirve para crear datos de prueba

-- Insertar algunos consejos de ejemplo
INSERT INTO nu_consejo (titulo, texto, activo, fecha_inicio, fecha_fin, mostrar_portada, fechaa, codusuarioa) VALUES
('Hidratación: Clave para tu Salud', 'El agua es fundamental para el correcto funcionamiento de nuestro organismo. Se recomienda beber al menos 2 litros de agua al día, aunque esta cantidad puede variar según tu peso, actividad física y clima.\n\nBeneficios de una buena hidratación:\n- Mejora la función renal\n- Ayuda en la digestión\n- Mantiene la piel saludable\n- Regula la temperatura corporal\n- Mejora el rendimiento físico y mental\n\nRecuerda llevar siempre una botella de agua contigo!', 'S', '2024-01-01', '2024-12-31', 'S', NOW(), 1),

('5 Alimentos que Debes Incluir en tu Dieta', 'Una alimentación balanceada es esencial para mantener un estilo de vida saludable. Aquí te presento 5 alimentos que no pueden faltar en tu dieta diaria:\n\n1. **Verduras de hoja verde**: Espinacas, lechuga, acelgas - ricas en vitaminas y minerales\n2. **Frutas cítricas**: Naranjas, mandarinas, pomelos - alto contenido en vitamina C\n3. **Legumbres**: Lentejas, garbanzos, frijoles - excelente fuente de proteína vegetal\n4. **Frutos secos**: Almendras, nueces, avellanas - grasas saludables y energía\n5. **Pescado azul**: Salmón, atún, sardinas - omega-3 para el corazón\n\nIncorpora estos alimentos de forma variada y disfruta de sus beneficios!', 'S', '2024-01-15', '2024-12-31', 'S', NOW(), 1),

('Ejercicio Cardiovascular: Beneficios y Recomendaciones', 'El ejercicio cardiovascular es fundamental para mantener tu corazón saludable y mejorar tu condición física general.\n\nBeneficios principales:\n- Fortalece el corazón y los pulmones\n- Ayuda a controlar el peso\n- Reduce el estrés y la ansiedad\n- Mejora la calidad del sueño\n- Aumenta los niveles de energía\n\nRecomendaciones:\n- Mínimo 150 minutos semanales de actividad moderada\n- O 75 minutos de actividad intensa\n- Combina diferentes actividades: caminar, correr, nadar, bicicleta\n- Comienza de forma gradual si eres principiante\n- Consulta con tu médico antes de iniciar un programa intenso\n\nRecuerda: La constancia es más importante que la intensidad al principio!', 'S', '2024-02-01', '2024-12-31', 'N', NOW(), 1),

('La Importancia del Descanso en tu Entrenamiento', 'Muchas personas piensan que entrenar todos los días sin descanso es la mejor forma de obtener resultados, pero esto es un error común.\n\nEl descanso es esencial porque:\n- Permite la recuperación muscular\n- Previene lesiones por sobreuso\n- Mejora el rendimiento a largo plazo\n- Reduce el riesgo de burnout\n- Ayuda a mantener la motivación\n\nRecomendaciones de descanso:\n- Al menos 1-2 días completos de descanso por semana\n- Alterna grupos musculares en días consecutivos\n- Duerme 7-9 horas diarias\n- Escucha a tu cuerpo: si estás muy cansado, descansa\n- El descanso activo (caminar, yoga suave) también es válido\n\nTu cuerpo necesita tiempo para adaptarse y fortalecerse!', 'S', NOW(), NULL, 'N', NOW(), 1),

('Planificación de Comidas: Tu Aliado para el Éxito', 'La planificación de comidas puede marcar la diferencia entre lograr tus objetivos nutricionales o desviarte de ellos.\n\nVentajas de planificar:\n- Ahorras tiempo durante la semana\n- Controlas mejor las porciones\n- Evitas decisiones impulsivas\n- Reduces el desperdicio de alimentos\n- Ahorras dinero en compras\n\nPasos para una buena planificación:\n1. Dedica 1-2 horas el fin de semana\n2. Revisa tu agenda de la semana\n3. Elige recetas equilibradas y variadas\n4. Haz una lista de compras completa\n5. Prepara ingredientes básicos por adelantado\n6. Guarda en recipientes apropiados\n\nConsejo: Empieza con 3-4 comidas y ve aumentando gradualmente!', 'S', NOW(), NULL, 'S', NOW(), 1);

-- Nota: Para asignar estos consejos a pacientes específicos, necesitas ejecutar INSERT en nu_consejo_paciente
-- con los códigos de consejo generados y los códigos de tus pacientes.

-- Ejemplo de asignación (ajusta los códigos según tu base de datos):
-- INSERT INTO nu_consejo_paciente (codigo_consejo, codigo_paciente, me_gusta, fechaa, codusuarioa) VALUES
-- (1, 1, 'N', NOW(), 1),
-- (1, 2, 'N', NOW(), 1),
-- (2, 1, 'N', NOW(), 1);

-- Ejemplo de documentos/URLs (ajusta los códigos según tu base de datos):
-- INSERT INTO nu_consejo_documento (codigo_consejo, tipo, nombre, url, orden, fechaa, codusuarioa) VALUES
-- (1, 'url', 'Calculadora de hidratación', 'https://www.ejemplo.com/calculadora-agua', 1, NOW(), 1),
-- (2, 'url', 'Recetas saludables', 'https://www.ejemplo.com/recetas', 1, NOW(), 1);
