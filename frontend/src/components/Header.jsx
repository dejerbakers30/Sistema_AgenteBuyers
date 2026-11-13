import React from 'react';
import { RefreshCw, Radio } from 'lucide-react';

export default function Header({ lastUpdated, autoRefresh, setAutoRefresh, onRefresh, isRefreshing }) {
  return (
    <header className="bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 text-white shadow-lg">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4 sm:py-5 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div className="flex items-center space-x-3.5">
          <div className="w-12 h-12 rounded-xl bg-indigo-600 flex items-center justify-center shadow-inner font-black text-2xl text-white">
            🎓
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <h1 className="text-xl sm:text-2xl font-bold tracking-tight text-white">INBESTIGA BI</h1>
              <span className="bg-indigo-500/30 text-indigo-200 border border-indigo-400/30 px-2 py-0.5 rounded text-xs font-semibold tracking-wide uppercase">
                Fase BUYER (React)
              </span>
            </div>
            <p className="text-xs sm:text-sm text-slate-300">
              Panel de Inteligencia de Negocios & Monitoreo del Agente IA en Tiempo Real
            </p>
          </div>
        </div>

        {/* Controles de Sincronización */}
        <div className="flex items-center space-x-3 self-end md:self-auto bg-slate-800/80 backdrop-blur p-2 rounded-xl border border-slate-700">
          <div className="flex items-center space-x-2 px-2">
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={autoRefresh}
                onChange={(e) => setAutoRefresh(e.target.checked)}
                className="sr-only peer"
              />
              <div className="w-9 h-5 bg-slate-600 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-emerald-500"></div>
            </label>
            <span className="text-xs text-slate-300 font-medium">Auto-refresco (3s)</span>
          </div>

          <div className="h-5 w-px bg-slate-700"></div>

          <button
            onClick={onRefresh}
            className="flex items-center space-x-1.5 px-3 py-1.5 bg-indigo-600 hover:bg-indigo-500 active:scale-95 text-white text-xs font-semibold rounded-lg shadow transition"
            title="Refrescar datos ahora"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin' : ''}`} />
            <span>Refrescar</span>
          </button>

          <div className="text-right pl-2 hidden sm:block">
            <div className="text-[10px] text-slate-400">Última lectura</div>
            <div className="text-xs font-mono font-bold text-emerald-400">{lastUpdated || '--:--:--'}</div>
          </div>
        </div>
      </div>
    </header>
  );
}

