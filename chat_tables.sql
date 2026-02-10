-- Tablas para chat usuario <-> nutricionista
CREATE TABLE chat_conversation (
  id INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id INT NOT NULL,
  nutricionista_id INT NOT NULL,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_usuario_nutri (usuario_id, nutricionista_id),
  KEY idx_nutri (nutricionista_id),
  CONSTRAINT fk_chat_conv_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(codigo) ON DELETE CASCADE,
  CONSTRAINT fk_chat_conv_nutri FOREIGN KEY (nutricionista_id) REFERENCES usuario(codigo) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE chat_message (
  id INT AUTO_INCREMENT PRIMARY KEY,
  conversation_id INT NOT NULL,
  sender_id INT NOT NULL,
  receiver_id INT NOT NULL,
  cuerpo TEXT NULL,
  imagen_base64 MEDIUMTEXT NULL,
  imagen_mime VARCHAR(60) NULL,
  leido TINYINT(1) NOT NULL DEFAULT 0,
  leido_fecha DATETIME NULL,
  borrado_por_emisor TINYINT(1) NOT NULL DEFAULT 0,
  borrado_por_receptor TINYINT(1) NOT NULL DEFAULT 0,
  creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_conversation (conversation_id),
  KEY idx_receiver_leido (receiver_id, leido),
  CONSTRAINT fk_chat_msg_conv FOREIGN KEY (conversation_id) REFERENCES chat_conversation(id) ON DELETE CASCADE,
  CONSTRAINT fk_chat_msg_sender FOREIGN KEY (sender_id) REFERENCES usuario(codigo) ON DELETE CASCADE,
  CONSTRAINT fk_chat_msg_receiver FOREIGN KEY (receiver_id) REFERENCES usuario(codigo) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
