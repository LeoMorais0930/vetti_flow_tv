import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const _defaultBase = 'http://10.36.0.75:5000';

  static Future<String> get _base async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip') ?? _defaultBase;
  }

  static Future<List<ProductionOrder>> getActiveOrders() async {
    final res = await http.get(Uri.parse('${await _base}/api/orders'));
    if (res.statusCode != 200) throw Exception('Erro API');
    final list = jsonDecode(res.body) as List;
    return list.map((j) => ProductionOrder.fromJson(j)).toList();
  }
}

class SignalRService {
  static SignalRService? _instance;
  static SignalRService get instance => _instance ??= SignalRService._();
  SignalRService._();

  HubConnection? _connection;
  final List<void Function(ProductionOrder)> _listeners = [];
  final List<void Function()> _refreshListeners = [];

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> connect() async {
    if (isConnected) return;

    final baseUrl = await ApiService._base;
    _connection = HubConnectionBuilder()
        .withUrl('$baseUrl/hubs/production')
        .withAutomaticReconnect()
        .build();

    _connection!.on('OrderUpdated', (args) {
      if (args != null && args.isNotEmpty) {
        final order = ProductionOrder.fromSignalR(args[0] as Map<String, dynamic>);
        for (var l in _listeners) {
          l(order);
        }
      }
    });

    _connection!.on('RefreshAll', (args) {
      for (var l in _refreshListeners) {
        l();
      }
    });

    await _connection!.start();
  }

  void addListener(void Function(ProductionOrder) l) => _listeners.add(l);
  void removeListener(void Function(ProductionOrder) l) => _listeners.remove(l);
  
  void addRefreshListener(void Function() l) => _refreshListeners.add(l);
  void removeRefreshListener(void Function() l) => _refreshListeners.remove(l);
}
