import React from 'react';
import { UserCheck, Sparkles, AlertTriangle, Coins } from 'lucide-react';

export default function KpiCards({ kpis }) {
  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
      {/* KPI B01 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-emerald-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-emerald-600 uppercase tracking-wider bg-emerald-50 px-2 py-0.5 rounded">
              KPI B01 · Oficial
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Tasa Conversión a LEAD</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-emerald-100 text-emerald-600 flex items-center justify-center">
            <UserCheck className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-900">{kpis?.b01}%</span>
          <span className="text-xs text-slate-500 font-medium">efectividad</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-emerald-500 h-2 rounded-full" style={{ width: `${Math.min(kpis?.b01 || 0, 100)}%` }}></div>
        </div>
        <p className="text-xs text-slate-500 mt-3 flex justify-between">
          <span>{kpis?.total_leads} leads generados</span>
          <span className="font-medium text-slate-700">de {kpis?.total_buyers} buyers</span>
        </p>
      </div>

      {/* KPI B02 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-blue-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-blue-600 uppercase tracking-wider bg-blue-50 px-2 py-0.5 rounded">
              KPI B02 · Oficial
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Tasa Interacción de Valor</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-600 flex items-center justify-center">
            <Sparkles className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-900">{kpis?.b02}%</span>
          <span className="text-xs text-slate-500 font-medium">relevancia</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-blue-500 h-2 rounded-full" style={{ width: `${Math.min(kpis?.b02 || 0, 100)}%` }}></div>
        </div>
        <p className="text-xs text-slate-500 mt-3 flex justify-between">
          <span>{kpis?.interacciones_valor} interacciones clave</span>
          <span className="font-medium text-slate-700">en WhatsApp</span>
        </p>
      </div>

      {/* KPI B06 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-rose-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-rose-600 uppercase tracking-wider bg-rose-50 px-2 py-0.5 rounded">
              KPI B06 · Demanda
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Fuera de Cobertura</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-600 flex items-center justify-center">
            <AlertTriangle className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-rose-600">{kpis?.b06}</span>
          <span className="text-xs text-slate-500 font-medium">en lista de espera</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-rose-500 h-2 rounded-full" style={{ width: `${Math.min((kpis?.b06 / (kpis?.total_buyers || 1)) * 100, 100)}%` }}></div>
        </div>
        <p className="text-xs text-slate-500 mt-3">
          💡 <span className="font-semibold text-rose-700">Oportunidad:</span> aperturar nuevas carreras
        </p>
      </div>

      {/* KPI B07 */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-200 border-l-4 border-l-indigo-500 hover:shadow-md transition">
        <div className="flex justify-between items-start">
          <div>
            <span className="text-[11px] font-bold text-indigo-600 uppercase tracking-wider bg-indigo-50 px-2 py-0.5 rounded">
              KPI B07 · CAC
            </span>
            <h3 className="text-sm font-semibold text-slate-600 mt-2">Costo por Buyer</h3>
          </div>
          <div className="w-10 h-10 rounded-xl bg-indigo-100 text-indigo-600 flex items-center justify-center">
            <Coins className="w-5 h-5" />
          </div>
        </div>
        <div className="mt-4 flex items-baseline space-x-2">
          <span className="text-3xl font-extrabold text-slate-900">S/ {kpis?.b07}</span>
          <span className="text-xs text-slate-500 font-medium">unitario</span>
        </div>
        <div className="w-full bg-slate-100 rounded-full h-2 mt-3 overflow-hidden">
          <div className="bg-indigo-500 h-2 rounded-full w-3/4"></div>
        </div>
        <p className="text-xs text-slate-500 mt-3 flex justify-between">
          <span>Inversión total:</span>
          <span className="font-bold text-slate-800">S/ {kpis?.total_inversion?.toLocaleString()}</span>
        </p>
      </div>
    </div>
  );
}

