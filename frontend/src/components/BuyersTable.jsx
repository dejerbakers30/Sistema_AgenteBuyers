import React, { useMemo } from 'react';
import { Search, MessageCircle } from 'lucide-react';

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
              <th className="py-3.5 px-4">ID</th>
              <th className="py-3.5 px-4">Fecha y Hora</th>
              <th className="py-3.5 px-4">Estudiante</th>
              <th className="py-3.5 px-4">WhatsApp</th>
              <th className="py-3.5 px-4">Universidad</th>
              <th className="py-3.5 px-4">Carrera</th>
              <th className="py-3.5 px-4">Estado</th>
              <th className="py-3.5 px-4 text-center">Acciones</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-100 bg-white">
            {filtered.map(b => (
              <tr key={b.buyer_id} className="hover:bg-slate-50/80 transition">
                <td className="py-3 px-4 font-mono font-bold text-slate-700">#{b.buyer_id}</td>
                <td className="py-3 px-4 text-slate-500 font-mono text-xs">
                  {new Date(b.fecha_buyer).toLocaleString()}
                </td>
                <td className="py-3 px-4">
                  <div className="font-bold text-slate-900">{b.nombre_completo || 'Estudiante'}</div>
                  <div className="text-[11px] text-slate-400">{b.etapa_academica || 'Pregrado'}</div>
                </td>
                <td className="py-3 px-4 font-mono font-medium text-slate-600">
                  +{b.whatsapp}
                </td>
                <td className="py-3 px-4 font-medium text-slate-800">{b.universidad}</td>
                <td className="py-3 px-4 text-slate-700">{b.carrera}</td>
                <td className="py-3 px-4">
                  {b.estado_buyer === 'ACTIVO' ? (
                    <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 border border-emerald-200">
                      <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 mr-1.5"></span>
                      ACTIVO
                    </span>
                  ) : (
                    <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-rose-100 text-rose-800 border border-rose-200">
                      <span className="w-1.5 h-1.5 rounded-full bg-rose-500 mr-1.5"></span>
                      SIN_COBERTURA
                    </span>
                  )}
                </td>
                <td className="py-3 px-4 text-center">
                  <button
                    onClick={() => onOpenChat(b.whatsapp)}
                    className="inline-flex items-center space-x-1 px-2.5 py-1 bg-slate-100 hover:bg-indigo-50 hover:text-indigo-600 text-slate-600 rounded-lg text-xs font-semibold transition"
                  >
                    <MessageCircle className="w-3.5 h-3.5" />
                    <span>Chat</span>
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

