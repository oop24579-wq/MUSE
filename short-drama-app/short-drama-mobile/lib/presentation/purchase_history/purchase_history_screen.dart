import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import 'package:drama_now/models/user/order_history_item.dart';
import 'package:drama_now/services/api/api_client.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import '../../widgets/top_toast.dart';

/// Screen displaying list of purchase/subscription history
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<OrderHistoryItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPurchaseHistory();
  }

  Future<void> _loadPurchaseHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = AuthService.instance.currentUserId;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final data = await ApiClient.instance.get('/user/orders');
      final orders = (data['orders'] as List?) ?? const [];
      // SIM-B F2/F3: parsing lives in parseOrderHistoryItem — it uses the
      // API's periodEnd verbatim (no fabricated createdAt+30d), and keeps
      // kind/productId/amountCents/currency for display.
      final items = orders
          .whereType<Map>()
          .map((raw) => parseOrderHistoryItem(
                Map<String, dynamic>.from(raw),
                userId: userId,
              ))
          .toList();

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading purchase history: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Purchase History',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppTheme.error,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 2.h),
                      ElevatedButton(
                        onPressed: _loadPurchaseHistory,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: secondaryTextColor,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'No Purchase History',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'Your purchase history will appear here',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppTheme.accentBlue,
                      onRefresh: _loadPurchaseHistory,
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          top: 1.h,
                          // Clear the gesture nav bar in Android 15 edge-to-edge
                          bottom: 1.h + MediaQuery.of(context).padding.bottom,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) =>
                            PurchaseHistoryCard(item: _items[index]),
                      ),
                    ),
    );
  }
}

/// One purchase-history row. Stateless and driven entirely by
/// [OrderHistoryItem]'s display mapping, so it is widget-testable without
/// the API layer (SIM-B F2/F3).
class PurchaseHistoryCard extends StatelessWidget {
  const PurchaseHistoryCard({super.key, required this.item});

  final OrderHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final dividerColor = isDark ? AppTheme.dividerDark : AppTheme.dividerLight;

    final subscription = item.subscription;
    final state = item.badgeState();
    final isActive = state == OrderBadgeState.active;
    final isCoins = state == OrderBadgeState.coins;
    final isCancelledRunning = state == OrderBadgeState.cancelledActiveUntil;
    final badgeColor = isActive
        ? AppTheme.success
        : isCoins
            ? AppTheme.accentBlue
            : isCancelledRunning
                ? Colors.orange
                : Colors.grey;
    final badgeIcon = isActive
        ? Icons.check_circle
        : isCoins
            ? Icons.monetization_on_outlined
            : isCancelledRunning
                ? Icons.schedule
                : Icons.cancel;
    // Coin orders have no period; the period-type badge is VIP-only.
    final expirationText = item.expiryText();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dividerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: Badges and expiration
          Row(
            children: [
              // Status badge — coin orders get a neutral "Coins" state,
              // never Active/Expired (SIM-B F3).
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeIcon,
                      size: 3.5.w,
                      color: badgeColor,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      item.badgeLabel(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              // Period type badge - clean color
              if (!item.isCoinOrder && subscription.periodType != null)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue
                        .withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subscription.periodType!.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppTheme.accentBlueLight
                          : AppTheme.accentBlueDark,
                    ),
                  ),
                ),
              Spacer(),
              // Expiration info - simple text near badges. Only rendered
              // when the API supplied a real periodEnd (SIM-B F2).
              if (expirationText != null)
                Text(
                  expirationText,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: secondaryTextColor,
                  ),
                ),
            ],
          ),
          // Second row: product label + price (SIM-B F3)
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productLabel,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (item.priceLabel != null)
                Text(
                  item.priceLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
            ],
          ),
          // Third row: Transaction ID (copyable)
          SizedBox(height: 1.5.h),
          Row(
            children: [
              Icon(
                Icons.receipt_outlined,
                size: 3.5.w,
                color: secondaryTextColor,
              ),
              SizedBox(width: 1.5.w),
              Expanded(
                child: Text(
                  subscription.transactionId,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: secondaryTextColor,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 1.w),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: subscription.transactionId));
                  showTopToastInfo(context, 'Transaction ID copied',
                      duration: const Duration(seconds: 2));
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.all(1.w),
                  child: Icon(
                    Icons.copy_outlined,
                    size: 4.w,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
