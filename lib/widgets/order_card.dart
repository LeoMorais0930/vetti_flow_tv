import 'package:flutter/material.dart';
import '../models/models.dart';

const kVettiBlue  = Color(0xFF0073BB);
const kVettiGray  = Color(0xFFE1E1E1);
const kVettiDGray = Color(0xFF9E9E9E);
const kDone       = Color(0xFF2E7D32);

class OrderCard extends StatefulWidget {
  final ProductionOrder order;
  const OrderCard({super.key, required this.order});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    // Apenas inicia animação se for ALTA PRIORIDADE para economizar CPU
    if (widget.order.isHighPriority) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200), // Pulsação mais lenta
      )..repeat(reverse: true);
      _opacity = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulse!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o      = widget.order;
    final total  = o.stageNames.length;
    final curr   = o.currentStageIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: o.isHighPriority ? kVettiBlue : kVettiGray,
          width: o.isHighPriority ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          children: [
            Row(
              children: [
                // ── Lado esquerdo: info do pedido ───────────────────────────────
                SizedBox(
                  width: 320, // Aumentado um pouco para acomodar nomes maiores
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (o.isHighPriority)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: kVettiBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('ALTA PRIORIDADE',
                              style: TextStyle(color: Colors.white, fontSize: 11,
                                  fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                        ),
                      Text(
                          o.productCode.isNotEmpty 
                              ? '${o.productCode} — ${o.productName}'
                              : o.label,
                          style: const TextStyle(fontSize: 24,
                              fontWeight: FontWeight.w900, color: kVettiBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                      if (o.productCode.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Lote: ${o.label}',
                              style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                        ),
                      const SizedBox(height: 8),
                      Text('${o.totalQty} unidades',
                          style: const TextStyle(fontSize: 18, color: kVettiDGray, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // ── Centro: barra de progresso com etapas (Apenas se NÃO for KIT) ──
                if (o.kitStatuses.isEmpty)
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(total * 2 - 1, (i) {
                          if (i.isOdd) {
                            final stageIdx = i ~/ 2;
                            final passed   = stageIdx < curr;
                            return Expanded(
                              child: Container(
                                height: 6,
                                color: passed ? kVettiBlue : kVettiGray,
                              ),
                            );
                          }
                          final idx   = i ~/ 2;
                          final done  = idx < curr;
                          final isCurr = idx == curr;

                          Widget circle = Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: done
                                  ? kDone
                                  : isCurr ? kVettiBlue : kVettiGray,
                              border: Border.all(
                                color: isCurr ? kVettiBlue : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: done
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : isCurr
                                    ? const Icon(Icons.play_arrow, color: Colors.white, size: 20)
                                    : Center(
                                        child: Text('${idx + 1}',
                                            style: const TextStyle(
                                                color: kVettiDGray,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800)),
                                      ),
                          );

                          if (isCurr) {
                            circle = Stack(alignment: Alignment.center, children: [
                              if (o.isHighPriority && _opacity != null)
                              FadeTransition(
                                opacity: _opacity!,
                                child: Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: kVettiBlue.withValues(alpha: 0.25),
                                  ),
                                ),
                              ),
                              circle,
                            ]);
                          }

                          return circle;
                        }),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: o.stageNames.asMap().entries.map((e) {
                          final done  = e.key < curr;
                          final isCurr = e.key == curr;
                          return Expanded(
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isCurr ? FontWeight.w800 : FontWeight.w600,
                                color: done
                                    ? kDone
                                    : isCurr ? kVettiBlue : kVettiDGray,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Rodapé: Detalhes do KIT (Se for KIT) ──
            if (o.kitStatuses.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1, color: kVettiGray),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: o.kitStatuses.map((comp) {
                  final compProgress = o.stageNames.isEmpty
                      ? 0.0
                      : (comp.currentStageIndex + 1) / o.stageNames.length;
                  final stageName = o.stageNames.length > comp.currentStageIndex
                      ? o.stageNames[comp.currentStageIndex]
                      : '—';

                  return Container(
                    width: 420,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kVettiGray, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(comp.productCode, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kVettiBlue)),
                            Text(stageName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kVettiDGray)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(comp.productName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text('Qtd: ${comp.quantity}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: compProgress,
                          minHeight: 8,
                          backgroundColor: kVettiGray,
                          valueColor: AlwaysStoppedAnimation(comp.isCompleted ? kDone : kVettiBlue),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

const kBg = Color(0xFFF4F6F8);
