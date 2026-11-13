import React, { useEffect, useRef } from 'react';
import Chart from 'chart.js/auto';

export default function ChartsSection({ buyers, kpis }) {
  const barRef = useRef(null);
  const donutRef = useRef(null);

  useEffect(() => {
    if (!buyers || buyers.length === 0) return;

    // 1. Datos Universidad y Cobertura
    const uniMap = {};
    buyers.forEach(b => {
      const uni = b.universidad || 'Otra';
      if (!uniMap[uni]) uniMap[uni] = { activo: 0, sin: 0 };
      if (b.estado_buyer === 'ACTIVO') uniMap[uni].activo++;
      else uniMap[uni].sin++;
    });

    const labels = Object.keys(uniMap);
    const dataActivo = labels.map(u => uniMap[u].activo);
    const dataSin = labels.map(u => uniMap[u].sin);

    // Destruir gráficos previos
    if (barRef.current && barRef.current._chartInstance) {
      barRef.current._chartInstance.destroy();
    }
    if (donutRef.current && donutRef.current._chartInstance) {
      donutRef.current._chartInstance.destroy();
    }

    // Gráfico de Barras
    if (barRef.current) {
      const ctx = barRef.current.getContext('2d');
      barRef.current._chartInstance = new Chart(ctx, {
        type: 'bar',
        data: {
          labels,
          datasets: [
            { label: 'Con Cobertura (ACTIVO)', data: dataActivo, backgroundColor: '#10b981', borderRadius: 6 },
            { label: 'Sin Cobertura (LISTA ESPERA)', data: dataSin, backgroundColor: '#ef4444', borderRadius: 6 }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { position: 'top', labels: { boxWidth: 12 } }
          },
          scales: {
            x: { stacked: true, grid: { display: false } },
            y: { stacked: true, beginAtZero: true, grid: { color: '#f1f5f9' } }
          }
        }
      });
    }

    // Gráfico de Dona
    if (donutRef.current) {
      const ctx = donutRef.current.getContext('2d');
      const activos = buyers.filter(b => b.estado_buyer === 'ACTIVO').length;
      const sin = buyers.filter(b => b.estado_buyer === 'SIN_COBERTURA').length;

      donutRef.current._chartInstance = new Chart(ctx, {
        type: 'doughnut',
        data: {
          labels: ['Con Cobertura (ACTIVO)', 'Sin Cobertura (ESPERA)'],
          datasets: [{
            data: [activos, sin],
            backgroundColor: ['#10b981', '#ef4444'],
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '70%',
          plugins: {
            legend: { position: 'bottom', labels: { boxWidth: 12 } }
          }
        }
      });
    }
  }, [buyers]);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div className="lg:col-span-2 bg-white rounded-2xl p-6 shadow-sm border border-slate-200">
        <h3 className="text-base font-bold text-slate-900 mb-1">Demanda por Universidad</h3>
        <p className="text-xs text-slate-500 mb-4">Volumen comparativo de cobertura activa vs demanda insatisfecha</p>
        <div className="h-64 sm:h-72 w-full relative">
          <canvas ref={barRef}></canvas>
        </div>
      </div>

      <div className="bg-white rounded-2xl p-6 shadow-sm border border-slate-200 flex flex-col">
        <h3 className="text-base font-bold text-slate-900 mb-1">Efectividad de Catálogo</h3>
        <p className="text-xs text-slate-500 mb-4">Proporción general de atención</p>
        <div className="h-60 w-full relative flex-1">
          <canvas ref={donutRef}></canvas>
        </div>
        <div className="mt-4 pt-3 border-t border-slate-100 flex justify-around text-center text-xs">
          <div>
            <span className="text-slate-400 block">Tasa Cobertura</span>
            <span className="font-bold text-emerald-600 text-sm">{kpis?.tasa_cobertura || 0}%</span>
          </div>
          <div className="w-px h-8 bg-slate-200"></div>
          <div>
            <span className="text-slate-400 block">Tasa Descarte</span>
            <span className="font-bold text-rose-600 text-sm">{(100 - (kpis?.tasa_cobertura || 0)).toFixed(1)}%</span>
          </div>
        </div>
      </div>
    </div>
  );
}

