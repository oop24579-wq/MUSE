import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/user/coin_transaction.dart';
import '../../services/account_service.dart';

/// Coin balance header + paginated transaction history
/// (`GET /me/transactions?limit=50&offset=0`).
class CoinHistoryScreen extends StatefulWidget {
  const CoinHistoryScreen({
    super.key,
    required this.balance,
    this.service,
  });

  final int balance;

  /// Injectable seam for tests; defaults to the real [AccountService].
  final AccountServiceBase? service;

  @override
  State<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends State<CoinHistoryScreen> {
  static const _pageSize = 50;
  final List<CoinTransaction> _items = [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  AccountServiceBase get _service => widget.service ?? AccountService.instance;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    setState(() {
      if (first) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final result = await _service.fetchTransactions(
        limit: _pageSize,
        offset: first ? 0 : _items.length,
      );
      if (!mounted) return;
      setState(() {
        if (first) _items.clear();
        _items.addAll(result.items);
        _total = result.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  bool get _hasMore => _items.length < _total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My coins')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF2A1512), Color(0xFF4A241A)],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.monetization_on_rounded,
                    color: Color(0xFFFFB300), size: 32),
                const SizedBox(height: 8),
                Text(
                  '${widget.balance}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('Coin balance',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your coin history.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _load(first: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('No transactions yet.\nEarn coins by watching and '
            'completing rewards!'),
      );
    }
    final dateFmt = DateFormat.yMMMd().add_jm();
    return ListView.separated(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: () => _load(),
                      child: const Text('Load more'),
                    ),
            ),
          );
        }
        final tx = _items[i];
        final positive = tx.isCredit;
        return ListTile(
          leading: Icon(
            positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: positive ? Colors.green : Colors.redAccent,
          ),
          title: Text(tx.typeLabel),
          subtitle: Text(
              '${dateFmt.format(tx.createdAt.toLocal())} • Balance: ${tx.balanceAfter}'),
          trailing: Text(
            positive ? '+${tx.amount}' : '${tx.amount}',
            style: TextStyle(
              color: positive ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        );
      },
    );
  }
}
