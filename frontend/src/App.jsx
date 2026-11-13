import React, { useState, useEffect, useMemo } from 'react';
import Header from './components/Header';
import KpiCards from './components/KpiCards';
import ChartsSection from './components/ChartsSection';
import BuyersTable from './components/BuyersTable';
import ChatAuditor from './components/ChatAuditor';

/**
 * Componente Principal del Dashboard BI en React (Fase BUYER)
 * Conectado en tiempo real con la API REST de SQL Server (INBESTIGA_TESIS).
 */
export default function App() {
  const [activeTab, setActiveTab] = useState('resumen'); // 'resumen' | 'trazabilidad' | 'chats'
  const [kpis, setKpis] = useState(null);
  const [buyers, setBuyers] = useState([]);
  const [conversaciones, setConversaciones] = useState([]);
  const [loading, setLoading] = useState(true);
  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lastUpdated, setLastUpdated] = useState('');
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('ALL');
  const [selectedPhone, setSelectedPhone] = useState(null);

  // Sincronización con el backend REST API
  const fetchData = async (showSpinner = false) => {
    if (showSpinner) setIsRefreshing(true);
    try {
      const [kpiRes, buyersRes, convRes] = await Promise.all([
        fetch('/api/kpis').then(r => r.json()),
        fetch('/api/buyers').then(r => r.json()),
        fetch('/api/conversaciones').then(r => r.json())
      ]);

      setKpis(kpiRes);
      setBuyers(buyersRes || []);
      setConversaciones(convRes || []);
      setLastUpdated(new Date().toLocaleTimeString());
    } catch (err) {
      console.error('Error al sincronizar con SQL Server:', err);
    } finally {
      setLoading(false);
      if (showSpinner) setTimeout(() => setIsRefreshing(false), 500);
    }
  };

  useEffect(() => {
    fetchData(false);
    let interval = null;
    if (autoRefresh) {
      interval = setInterval(() => {
        fetchData(false);
      }, 3000);
    }
    return () => {
      if (interval) clearInterval(interval);
    };
  }, [autoRefresh]);

  if (loading && !kpis) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center bg-slate-50">
        <div className="w-16 h-16 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin"></div>
        <p className="mt-4 text-slate-600 font-semibold text-lg">Cargando métricas de SQL Server...</p>
        <p className="text-sm text-slate-400">INBESTIGA_TESIS · Fase BUYER</p>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <Header
        lastUpdated={lastUpdated}
        autoRefresh={autoRefresh}
        setAutoRefresh={setAutoRefresh}
        onRefresh={() => fetchData(true)}
        isRefreshing={isRefreshing}
      />

      {/* Tabs Bar */}
      <div className="bg-white border-b border-slate-200 sticky top-0 z-20 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex justify-between items-center">
          <nav className="flex space-x-1 sm:space-x-8">
            <button
              onClick={() => setActiveTab('resumen')}
              className={`py-4 px-3 border-b-2 font-medium text-sm sm:text-base flex items-center space-x-2 transition ${
                activeTab === 'resumen'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-slate-500 hover:text-slate-700'
              }`}
            >
              <span>📊 Resumen & KPIs</span>
            </button>
            <button
              onClick={() => setActiveTab('trazabilidad')}
              className={`py-4 px-3 border-b-2 font-medium text-sm sm:text-base flex items-center space-x-2 transition ${
                activeTab === 'trazabilidad'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-slate-500 hover:text-slate-700'
              }`}
            >
              <span>📋 Trazabilidad de Buyers</span>
              <span className="ml-2 bg-slate-100 text-slate-700 px-2.5 py-0.5 rounded-full text-xs font-bold">
                {buyers.length}
              </span>
            </button>
            <button
              onClick={() => setActiveTab('chats')}
              className={`py-4 px-3 border-b-2 font-medium text-sm sm:text-base flex items-center space-x-2 transition ${
                activeTab === 'chats'
                  ? 'border-indigo-600 text-indigo-600'
                  : 'border-transparent text-slate-500 hover:text-slate-700'
              }`}
            >
              <span>💬 Auditoría de WhatsApp</span>
            </button>
          </nav>

          <div className="hidden sm:flex items-center space-x-2 text-xs text-slate-500">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse"></span>
            <span>SQL Server Conectado (3s)</span>
          </div>
        </div>
      </div>

      {/* Contenido Principal */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {activeTab === 'resumen' && (
          <div className="space-y-6">
            <KpiCards kpis={kpis} />
            <ChartsSection buyers={buyers} kpis={kpis} />
          </div>
        )}

        {activeTab === 'trazabilidad' && (
          <BuyersTable
            buyers={buyers}
            searchTerm={searchTerm}
            setSearchTerm={setSearchTerm}
            filterStatus={filterStatus}
            setFilterStatus={setFilterStatus}
            onOpenChat={(phone) => {
              setSelectedPhone(phone);
              setActiveTab('chats');
            }}
          />
        )}

        {activeTab === 'chats' && (
          <ChatAuditor
            conversaciones={conversaciones}
            buyers={buyers}
            selectedPhone={selectedPhone}
            setSelectedPhone={setSelectedPhone}
          />
        )}
      </main>
    </div>
  );
}

