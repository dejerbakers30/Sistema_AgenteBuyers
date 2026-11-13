import React, { useMemo, useRef, useEffect } from 'react';
import { MessageSquare, MessagesSquare, CheckCheck } from 'lucide-react';

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
          </h3>
          <p className="text-[11px] text-slate-500">Historial auditado en la tabla MENSAJE</p>
        </div>

        <div className="flex-1 overflow-y-auto divide-y divide-slate-100">
          {chatsPorTelefono.map(chat => {
            const isSelected = activeChat && activeChat.whatsapp === chat.whatsapp;
            const ultimoMsg = chat.mensajes[chat.mensajes.length - 1];
            return (
              <div
                key={chat.whatsapp}
                onClick={() => setSelectedPhone(chat.whatsapp)}
                className={`p-3.5 cursor-pointer transition flex items-start space-x-3 ${
                  isSelected ? 'bg-indigo-50/80 border-l-4 border-indigo-600' : 'hover:bg-slate-50'
                }`}
              >
                <div className="w-10 h-10 rounded-full bg-slate-200 text-slate-600 flex items-center justify-center font-bold text-sm shrink-0">
                  👤
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between items-baseline">
                    <h4 className="text-xs font-bold text-slate-900 truncate">
                      {chat.nombre || 'Estudiante'}
                    </h4>
                    <span className="text-[10px] text-slate-400 font-mono">
                      {ultimoMsg ? new Date(ultimoMsg.fecha_mensaje).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-500 font-mono">+{chat.whatsapp}</p>
                  <p className="text-xs text-slate-600 truncate mt-1">
                    {ultimoMsg ? (ultimoMsg.emisor === 'BOT' ? '🤖 Vicky: ' : '👤 ') + ultimoMsg.contenido : ''}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Ventana de Chat estilo WhatsApp */}
      <div className="flex-1 flex flex-col bg-[#efeae2] relative">
        {activeChat ? (
          <React.Fragment>
            <div className="bg-white p-3.5 border-b border-slate-200 flex justify-between items-center z-10 shadow-sm">
              <div className="flex items-center space-x-3">
                <div className="w-10 h-10 rounded-full bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-base">
                  🎓
                </div>
                <div>
                  <div className="font-bold text-sm text-slate-900 flex items-center gap-2">
                    <span>{activeChat.nombre || 'Estudiante'}</span>
                    {buyerRelacionado && (
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        buyerRelacionado.estado_buyer === 'ACTIVO'
                          ? 'bg-emerald-100 text-emerald-800'
                          : 'bg-rose-100 text-rose-800'
                      }`}>
                        {buyerRelacionado.estado_buyer}
                      </span>
                    )}
                  </div>
                  <div className="text-xs text-slate-500 font-mono">
                    WhatsApp: +{activeChat.whatsapp} {buyerRelacionado ? `· ${buyerRelacionado.carrera || ''} (${buyerRelacionado.universidad || ''})` : ''}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2 text-xs text-emerald-700 font-semibold bg-emerald-50 px-3 py-1 rounded-full border border-emerald-200">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                <span>Auditoría en Vivo</span>
              </div>
            </div>

            <div className="flex-1 p-4 sm:p-6 overflow-y-auto space-y-4">
              {activeChat.mensajes.map((m, idx) => {
                const isBot = m.emisor === 'BOT';
                return (
                  <div
                    key={m.mensaje_id || idx}
                    className={`flex ${isBot ? 'justify-end' : 'justify-start'}`}
                  >
                    <div
                      className={`max-w-[85%] sm:max-w-[70%] rounded-2xl px-4 py-2.5 shadow-sm text-sm relative ${
                        isBot
                          ? 'bg-[#d9fdd3] text-slate-900 rounded-tr-none'
                          : 'bg-white text-slate-900 rounded-tl-none border border-slate-200'
                      }`}
                    >
                      <div className="text-[10px] font-bold uppercase tracking-wider mb-1 flex items-center gap-1.5 opacity-75">
                        <span>{isBot ? '🤖 Vicky (Asistente IA)' : `👤 ${activeChat.nombre || 'Estudiante'}`}</span>
                      </div>
                      <p className="whitespace-pre-line leading-relaxed text-[13.5px]">
                        {m.contenido}
                      </p>
                      <div className="text-right mt-1 text-[10px] text-slate-500 font-mono flex items-center justify-end gap-1">
                        <span>{new Date(m.fecha_mensaje).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                        {isBot && <CheckCheck className="w-3.5 h-3.5 text-sky-600 inline" />}
                      </div>
                    </div>
                  </div>
                );
              })}
              <div ref={messagesEndRef} />
            </div>

            <div className="bg-white p-3 border-t border-slate-200 text-center text-xs text-slate-400">
              🔒 Conversación encriptada e indexada en tiempo real en la tabla <code className="font-mono bg-slate-100 px-1 py-0.5 rounded text-slate-600">MENSAJE</code>.
            </div>
          </React.Fragment>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center text-slate-400">
            <MessageSquare className="w-12 h-12 mb-2 stroke-1" />
            <p>Selecciona una conversación a la izquierda para ver el chat auditado.</p>
          </div>
        )}
      </div>
    </div>
  );
}

