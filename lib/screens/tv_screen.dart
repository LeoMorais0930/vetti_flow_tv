import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../widgets/order_card.dart';

const kVettiBlue  = Color(0xFF0073BB);
const kVettiGray  = Color(0xFFE1E1E1);
const kBg         = Color(0xFFF4F6F8);

class TvDashboardScreen extends StatefulWidget {
  const TvDashboardScreen({super.key});

  @override
  State<TvDashboardScreen> createState() => _TvDashboardScreenState();
}

class _TvDashboardScreenState extends State<TvDashboardScreen> {
  final PageController _pageController = PageController();
  final ScrollController _activeScroll = ScrollController();
  final ScrollController _historyScroll = ScrollController();
  List<ProductionOrder> _orders = [];
  List<ProductionOrder> _completedRecent = [];
  DateTime _now = DateTime.now();
  bool _loading = true;
  int _currentPage = 0;
  Timer? _scrollTimer;

  // Ticker
  final List<String> _tickerMessages = [
    'VETTI Flow — Monitoramento em tempo real',
    'Segurança em primeiro lugar',
    'Qualidade é responsabilidade de todos',
  ];
  int _tickerIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _connectSignalR();

    // Relógio
    Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Ticker rotativo
    Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _tickerIndex = (_tickerIndex + 1) % _tickerMessages.length);
    });

    // Transição de tela a cada 10 segundos para dar tempo de ler
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _currentPage = (_currentPage + 1) % 3; // 3 telas agora
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutExpo,
        );
      }
    });

    // NOVO: Heartbeat de segurança - Força um refresh a cada 30 segundos se estiver vazio ou SignalR instável
    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_orders.isEmpty || !SignalRService.instance.isConnected) {
        _load();
      }
    });

    _startAutoScroll();
  }

  void _startAutoScroll() {
    _scrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      
      ScrollController? current;
      if (_currentPage == 0) current = _activeScroll;
      if (_currentPage == 2) current = _historyScroll;
      
      if (current != null && current.hasClients) {
        final max = current.position.maxScrollExtent;
        if (max > 0) {
          final target = current.offset >= max ? 0.0 : current.offset + 200.0;
          current.animateTo(
            target,
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Future<void> _load() async {
    try {
      final all = await ApiService.getActiveOrders();
      final now = DateTime.now();

      if (mounted) {
        setState(() {
          _orders = all.where((o) => !o.isCompleted).toList();
          
          // Carrega histórico do dia logo no início
          _completedRecent = all.where((o) {
            if (!o.isCompleted) return false;
            final date = (o.completedAt ?? o.createdAt ?? DateTime.now()).toLocal();
            
            // Filtro mais robusto para "Hoje" na TV também
            return date.year == now.year && 
                   date.month == now.month && 
                   date.day == now.day;
          }).toList();
          
          // Ordena os mais recentes primeiro
          _completedRecent.sort((a, b) {
            final da = a.completedAt ?? a.createdAt ?? DateTime(2000);
            final db = b.completedAt ?? b.createdAt ?? DateTime(2000);
            return db.compareTo(da);
          });

          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      // Tenta novamente em 5s se falhar
      Future.delayed(const Duration(seconds: 5), _load);
    }
  }

  void _connectSignalR() {
    SignalRService.instance.addListener(_onOrderUpdated);
    SignalRService.instance.addRefreshListener(_load); // Escuta o RefreshAll
    SignalRService.instance.connect();
  }

  void _onOrderUpdated(ProductionOrder updated) {
    if (!mounted) return;
    setState(() {
      final idx = _orders.indexWhere((o) => o.id == updated.id);
      if (updated.isCompleted) {
        if (idx >= 0) _orders.removeAt(idx);
        // Adiciona ao histórico recente se for novo
        if (!_completedRecent.any((o) => o.id == updated.id)) {
          _completedRecent.insert(0, updated);
          if (_completedRecent.length > 15) _completedRecent.removeLast();
        }
      } else if (idx >= 0) {
        _orders[idx] = updated;
      } else {
        _orders.insert(0, updated);
      }
      // Alta prioridade sempre no topo
      _orders.sort((a, b) {
        if (a.isHighPriority == b.isHighPriority) return 0;
        return a.isHighPriority ? -1 : 1;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _activeScroll.dispose();
    _historyScroll.dispose();
    _scrollTimer?.cancel();
    SignalRService.instance.removeListener(_onOrderUpdated);
    SignalRService.instance.removeRefreshListener(_load);
    super.dispose();
  }

  String get _timeStr {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get _dateStr {
    const months = ['Jan','Fev','Mar','Abr','Mai','Jun',
                    'Jul','Ago','Set','Out','Nov','Dez'];
    const days   = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];
    return '${days[_now.weekday % 7]}, ${_now.day} ${months[_now.month - 1]} ${_now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              children: [
                _buildBody(), // Tela de Lista
                _buildSummaryPage(), // Tela de Resumo (Power BI)
                _buildHistoryPage(), // Tela de Histórico Recente
              ],
            ),
          ),
          _buildTicker(),
        ],
      ),
    );
  }

  // ── Tela de Resumo (Power BI Style) ──────────────────────────────────────────
  Widget _buildSummaryPage() {
    final highPriority = _orders.where((o) => o.isHighPriority).length;
    final totalUnits = _orders.fold<int>(0, (sum, o) {
      if (o.kitStatuses.isNotEmpty) {
        // Para Kits, somamos as quantidades totais dos componentes diretamente
        return sum + o.kitStatuses.fold<int>(0, (kSum, k) => kSum + k.quantity);
      }
      return sum + o.totalQty;
    });
    
    // Cálculo de progresso médio real
    double avgProgress = 0;
    if (_orders.isNotEmpty) {
      avgProgress = _orders.fold<double>(0, (sum, o) {
        if (o.stageNames.isEmpty) return sum;
        return sum + ((o.currentStageIndex + 1) / o.stageNames.length);
      }) / _orders.length;
    }

    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VISÃO GERAL DA PRODUÇÃO',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: kVettiBlue, letterSpacing: 1.5)),
          const SizedBox(height: 40),
          Expanded(
            child: Row(
              children: [
                // KPI 1: Total de Lotes
                _buildKpiCard('LOTES ATIVOS', _orders.length.toString(), Icons.conveyor_belt, Colors.blue),
                const SizedBox(width: 24),
                // KPI 2: Alta Prioridade
                _buildKpiCard('ALTA PRIORIDADE', highPriority.toString(), Icons.priority_high, Colors.orange),
                const SizedBox(width: 24),
                // KPI 3: Total de Peças
                _buildKpiCard('PEÇAS EM PRODUÇÃO', totalUnits.toString(), Icons.inventory_2, Colors.teal),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Container(
            height: 200,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
            ),
            child: Row(
              children: [
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROGRESSO GERAL DA FÁBRICA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('Eficiência de fluxo atual', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 60),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: avgProgress,
                          minHeight: 40,
                          backgroundColor: kVettiGray,
                          valueColor: const AlwaysStoppedAnimation(kVettiBlue),
                        ),
                      ),
                      Text('${(avgProgress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPage() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LOTES CONCLUÍDOS RECENTEMENTE',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.green, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(30)),
                child: const Text('Ótimo trabalho equipe! 🚀', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: _completedRecent.isEmpty
                ? const Center(child: Text('Nenhum lote concluído nesta sessão.', style: TextStyle(fontSize: 24, color: kVettiGray)))
                : ListView.separated(
                    controller: _historyScroll,
                    itemCount: _completedRecent.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final o = _completedRecent[i];
                      final displayQty = o.kitStatuses.isNotEmpty 
                          ? o.kitStatuses.fold<int>(0, (kSum, k) => kSum + k.quantity)
                          : o.totalQty;
                      
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 32),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.productCode.isNotEmpty 
                                        ? '${o.productCode} — ${o.productName}'
                                        : o.label,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kVettiBlue)
                                  ),
                                  if (o.productCode.isNotEmpty)
                                    Text('Lote: ${o.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  if (o.componentCodes.isNotEmpty)
                                    Text('Kit: ${o.componentCodes}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text('$displayQty un', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kVettiBlue)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('“O sucesso é a soma de pequenos esforços repetidos dia após dia”',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
          border: Border(left: BorderSide(color: color, width: 8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.7), size: 40),
            const SizedBox(height: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Cabeçalho ───────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 72,
      color: kVettiBlue,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Logo
          const Text('VETTI',
              style: TextStyle(color: Colors.white, fontSize: 28,
                  fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(width: 12),
          Container(width: 2, height: 32, color: Colors.white38),
          const SizedBox(width: 12),
          const Text('FLOW',
              style: TextStyle(color: Colors.white70, fontSize: 22,
                  fontWeight: FontWeight.w300, letterSpacing: 4)),

          const Spacer(),

          // Status de conexão
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('AO VIVO',
                  style: TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
            ]),
          ),

          const SizedBox(width: 24),

          // Data e hora
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_timeStr,
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w700, letterSpacing: 2)),
              Text(_dateStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Corpo ────────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: kVettiBlue, strokeWidth: 3),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: kVettiGray),
            SizedBox(height: 16),
            Text('Nenhum lote em produção',
                style: TextStyle(fontSize: 22, color: Color(0xFFBBBBBB),
                    fontWeight: FontWeight.w300)),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _activeScroll,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _orders.length,
      itemBuilder: (_, i) => OrderCard(order: _orders[i]),
    );
  }

  // ── Ticker ───────────────────────────────────────────────────────────────────
  Widget _buildTicker() {
    return Container(
      height: 38,
      color: const Color(0xFF005A94),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('AVISO',
                style: TextStyle(color: Colors.white, fontSize: 11,
                    fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(width: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: Text(
              _tickerMessages[_tickerIndex],
              key: ValueKey(_tickerIndex),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const Spacer(),
          Text('${_orders.length} lote(s) ativo(s)',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
