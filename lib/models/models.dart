class ProductionOrder {
  final int id;
  final String label;
  final int totalQty;
  final bool isHighPriority;
  final int currentStageIndex;
  final bool isCompleted;
  final String componentCodes;
  final List<KitComponentStatus> kitStatuses;
  final List<String> stageNames;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const ProductionOrder({
    required this.id,
    required this.label,
    required this.totalQty,
    required this.isHighPriority,
    required this.currentStageIndex,
    required this.isCompleted,
    required this.componentCodes,
    required this.kitStatuses,
    required this.stageNames,
    this.createdAt,
    this.completedAt,
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> j) {
    final blueprint = j['blueprint'] as Map<String, dynamic>?;
    final stages = blueprint != null
        ? (blueprint['stages'] as List)
            .map<String>((s) => s['name'] as String)
            .toList()
        : <String>[];
    return ProductionOrder(
      id: j['id'],
      label: j['label'],
      totalQty: j['totalQty'],
      isHighPriority: j['isHighPriority'],
      currentStageIndex: j['currentStageIndex'],
      isCompleted: j['isCompleted'],
      componentCodes: j['componentCodes'] ?? '',
      kitStatuses: (j['kitStatuses'] as List?)?.map((x) => KitComponentStatus.fromJson(x)).toList() ?? [],
      stageNames: stages,
      createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      completedAt: j['completedAt'] != null ? DateTime.tryParse(j['completedAt']) : null,
    );
  }

  factory ProductionOrder.fromSignalR(Map<String, dynamic> j) => ProductionOrder(
        id: j['orderId'] ?? j['id'],
        label: j['label'],
        totalQty: j['totalQty'],
        isHighPriority: j['isHighPriority'],
        currentStageIndex: j['currentStageIndex'],
        isCompleted: j['isCompleted'],
        componentCodes: j['componentCodes'] ?? '',
        kitStatuses: (j['kitStatuses'] as List?)?.map((x) => KitComponentStatus.fromJson(x)).toList() ?? [],
        stageNames: List<String>.from(j['stageNames'] ?? []),
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
        completedAt: j['completedAt'] != null ? DateTime.tryParse(j['completedAt']) : null,
      );

  String get currentStageName =>
      stageNames.isNotEmpty && currentStageIndex < stageNames.length
          ? stageNames[currentStageIndex]
          : '—';
}

class KitComponentStatus {
  final String productCode;
  final String productName;
  final int quantity;
  final int currentStageIndex;
  final bool isCompleted;

  const KitComponentStatus({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.currentStageIndex,
    required this.isCompleted,
  });

  factory KitComponentStatus.fromJson(Map<String, dynamic> j) => KitComponentStatus(
        productCode: j['productCode'],
        productName: j['productName'],
        quantity: j['quantity'] ?? 1,
        currentStageIndex: j['currentStageIndex'],
        isCompleted: j['isCompleted'],
      );
}
// teste