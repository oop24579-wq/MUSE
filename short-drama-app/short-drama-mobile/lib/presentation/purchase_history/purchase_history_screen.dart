import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import 'package:drama_now/models/user/subscription_model.dart';
import 'package:drama_now/services/api/api_client.dart';
import 'package:drama_now/services/auth/auth_service.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/top_toast.dart';

/// Screen displaying list of purchase/subscription history
class PurchaseHistoryScreen extends StatefulWidget {
  const PurchaseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseHistoryScreen> createState() => _PurchaseHistoryScreenState();
}

class _PurchaseHistoryScreenState extends State<PurchaseHistoryScreen> {
  List<SubscriptionModel> _subscriptions = [];
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
      final subscriptions = orders.map((raw) {
        final o = Map<String, dynamic>.from(raw as Map);
        final created = o['createdAt']?.toString() ??
            DateTime.now().toUtc().toIso8601String();
        final status =
            (o['paymentStatus'] ?? o['status'] ?? 'pending') as String;
        final planId = (o['subscriptionPlanId'] ??
                o['type'] ??
                o['coinPackageId'] ??
                'order')
            .toString();
        final mappedStatus =
            (status == 'paid' || status == 'delivered') ? 'active' : status;
        return SubscriptionModel(
          id: o['id'] as String,
          userId: (o['userId'] as String?) ?? userId,
          paymentProvider:
              (o['paymentMethod'] ?? o['paymentProvider'] ?? 'revenuecat')
                  as String,
          planId: planId,
          status: mappedStatus,
          currentPeriodStart:
              DateTime.tryParse(created)?.toUtc() ?? DateTime.now().toUtc(),
          currentPeriodEnd: DateTime.tryParse(created)
                  ?.toUtc()
                  .add(const Duration(days: 30)) ??
              DateTime.now().toUtc(),
          cancelAtPeriodEnd: false,
          revenueCatTransactionId: o['revenueCatTransactionId'] as String?,
          createdAt:
              DateTime.tryParse(created)?.toUtc() ?? DateTime.now().toUtc(),
          updatedAt:
              DateTime.tryParse(created)?.toUtc() ?? DateTime.now().toUtc(),
        );
      }).toList();

      setState(() {
        _subscriptions = subscriptions;
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
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
    final surfaceColor = isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight;
    final textColor =
        isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    final dividerColor = isDark ? AppTheme.dividerDark : AppTheme.dividerLight;

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
              : _subscriptions.isEmpty
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
                        itemCount: _subscriptions.length,
                        itemBuilder: (context, index) {
                          final subscription = _subscriptions[index];
                          return _buildPurchaseItem(
                            context,
                            subscription,
                            isDark,
                            surfaceColor,
                            textColor,
                            secondaryTextColor,
                            dividerColor,
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildPurchaseItem(
    BuildContext context,
    SubscriptionModel subscription,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color secondaryTextColor,
    Color dividerColor,
  ) {
    // Format expiration date
    String? expirationText;
    if (subscription.expirationDate != null) {
      try {
        final expDate = DateTime.parse(subscription.expirationDate!);
        expirationText =
            'Expires ${expDate.day}/${expDate.month}/${expDate.year}';
      } catch (e) {
        expirationText = null;
      }
    }

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
              // Status badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: subscription.isActive
                      ? AppTheme.success.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      subscription.isActive ? Icons.check_circle : Icons.cancel,
                      size: 3.5.w,
                      color: subscription.isActive
                          ? AppTheme.success
                          : Colors.grey,
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      subscription.isActive ? 'Active' : 'Expired',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: subscription.isActive
                            ? AppTheme.success
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 2.w),
              // Period type badge - clean color
              if (subscription.periodType != null)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: AppTheme.accentBlue.withValues(alpha: isDark ? 0.2 : 0.1),
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
              // Expiration info - simple text near badges
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
          // Second row: Transaction ID (copyable)
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
                  showTopToastInfo(context, 'Transaction ID copied', duration: const Duration(seconds: 2));
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
