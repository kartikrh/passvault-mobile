// Shapes returned by PassVaultapi's profile/package, activity, plan and page
// endpoints -- see services/vaultAuth.js, vaultActivity.js,
// vaultPlanUpgrade.js and page.js (publicPagesService).

/// GET /vault/auth/profile/package -- the client's current plan (null when
/// none is assigned, e.g. accounts predating packages).
class ClientPackage {
  final int? packageId;
  final String name;
  final String? description;
  final num? price;
  final String? currency;
  final String? intervalType;
  final int? intervalCount;
  final int? maxAccounts;
  final int? maxNotes;
  final DateTime? expiryDate;
  final int? daysRemaining;
  final bool isExpired;

  const ClientPackage({
    required this.packageId,
    required this.name,
    this.description,
    this.price,
    this.currency,
    this.intervalType,
    this.intervalCount,
    this.maxAccounts,
    this.maxNotes,
    this.expiryDate,
    this.daysRemaining,
    this.isExpired = false,
  });

  factory ClientPackage.fromJson(Map<String, dynamic> json) => ClientPackage(
        packageId: (json['packageId'] as num?)?.toInt(),
        name: json['name'] as String? ?? 'Plan',
        description: json['description'] as String?,
        price: _toNum(json['price']),
        currency: json['currency'] as String?,
        intervalType: json['intervalType']?.toString(),
        intervalCount: (json['intervalCount'] as num?)?.toInt(),
        maxAccounts: (json['maxAccounts'] as num?)?.toInt(),
        maxNotes: (json['maxNotes'] as num?)?.toInt(),
        expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'] as String) : null,
        daysRemaining: (json['daysRemaining'] as num?)?.toInt(),
        isExpired: json['isExpired'] == true,
      );
}

/// One upgradeable plan (GET /vault/plan/packages).
class Plan {
  final int id;
  final String name;
  final String? description;
  final num? price;
  final String? currency;
  final String? intervalType;
  final int? intervalCount;
  final int? maxAccounts;
  final int? maxNotes;

  const Plan({
    required this.id,
    required this.name,
    this.description,
    this.price,
    this.currency,
    this.intervalType,
    this.intervalCount,
    this.maxAccounts,
    this.maxNotes,
  });

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Plan',
        description: json['description'] as String?,
        price: _toNum(json['price']),
        currency: json['currency'] as String?,
        intervalType: json['intervalType']?.toString(),
        intervalCount: (json['intervalCount'] as num?)?.toInt(),
        maxAccounts: (json['maxAccounts'] as num?)?.toInt(),
        maxNotes: (json['maxNotes'] as num?)?.toInt(),
      );
}

/// The admin's default QR/bank payment method (GET /vault/plan/paymentMethod).
class PaymentMethod {
  final String? label;
  final String? qrImageUrl;
  final String? upiId;
  final String? bankName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? branch;
  final String? instructions; // rich text (HTML) from the panel's editor

  const PaymentMethod({
    this.label,
    this.qrImageUrl,
    this.upiId,
    this.bankName,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.branch,
    this.instructions,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
        label: json['label'] as String?,
        qrImageUrl: json['qrImageUrl'] as String?,
        upiId: json['upiId'] as String?,
        bankName: json['bankName'] as String?,
        accountHolderName: json['accountHolderName'] as String?,
        accountNumber: json['accountNumber'] as String?,
        ifscCode: json['ifscCode'] as String?,
        branch: json['branch'] as String?,
        instructions: json['instructions'] as String?,
      );
}

/// The client's latest upgrade request (GET /vault/plan/upgradeRequest/mine).
class UpgradeRequest {
  final String status; // PENDING | APPROVED | REJECTED
  final String? requestedPackageName;
  final String? transferCode;
  final String? rejectionReason;
  final DateTime? createdAt;

  const UpgradeRequest({
    required this.status,
    this.requestedPackageName,
    this.transferCode,
    this.rejectionReason,
    this.createdAt,
  });

  bool get isPending => status == 'PENDING';

  factory UpgradeRequest.fromJson(Map<String, dynamic> json) => UpgradeRequest(
        status: json['status'] as String? ?? 'PENDING',
        requestedPackageName: json['requestedPackageName'] as String?,
        transferCode: json['transferCode'] as String?,
        rejectionReason: json['rejectionReason'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      );
}

/// Mirrors passvault-client's activityConstants.js.
abstract class ActivityType {
  static const int accountCreated = 110;
  static const int accountUpdated = 111;
  static const int accountDeleted = 112;
  static const int noteCreated = 160;
  static const int noteUpdated = 161;
  static const int noteDeleted = 162;
  static const int accountPasswordViewed = 170;
  static const int pageViewed = 171;

  static const entryTypes = {
    accountCreated,
    accountUpdated,
    accountDeleted,
    noteCreated,
    noteUpdated,
    noteDeleted,
    accountPasswordViewed,
  };
}

/// One row of GET /vault/auth/activity.
class ActivityItem {
  final int activityType;
  final String label;
  final String? refId;
  final String? entryName;
  final String? ipAddress;
  final double? latitude;
  final double? longitude;
  final DateTime createdDate;

  const ActivityItem({
    required this.activityType,
    required this.label,
    required this.createdDate,
    this.refId,
    this.entryName,
    this.ipAddress,
    this.latitude,
    this.longitude,
  });

  /// Same "Details" column passvault-client's activity page shows.
  String? get details {
    if (activityType == ActivityType.pageViewed) return refId;
    if (ActivityType.entryTypes.contains(activityType)) return entryName;
    return null;
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        activityType: (json['activityType'] as num?)?.toInt() ?? 0,
        label: json['activityLabel'] as String? ?? 'Activity',
        refId: json['refId']?.toString(),
        entryName: json['entryName'] as String?,
        ipAddress: json['ipAddress'] as String?,
        latitude: (_toNum(json['latitude']))?.toDouble(),
        longitude: (_toNum(json['longitude']))?.toDouble(),
        createdDate: DateTime.tryParse(json['createdDate'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class ActivityPage {
  final List<ActivityItem> items;
  final int page;
  final int totalPages;
  final int total;
  const ActivityPage(this.items, this.page, this.totalPages, this.total);
}

/// A CMS page (POST /vault/page) -- terms, privacy, help, ...
class CmsPage {
  final String title;
  final String? alias;
  final String? content; // HTML
  final bool isLink;
  final String? linkUrl;
  final bool isDefault;

  const CmsPage({
    required this.title,
    this.alias,
    this.content,
    this.isLink = false,
    this.linkUrl,
    this.isDefault = false,
  });

  factory CmsPage.fromJson(Map<String, dynamic> json) => CmsPage(
        title: (json['pageHeading'] ?? json['pageTitle'] ?? json['pageName'] ?? 'Page') as String,
        alias: json['alias'] as String?,
        content: json['pageContent'] as String?,
        isLink: json['isLink'] == true,
        linkUrl: json['linkURL'] as String?,
        isDefault: json['isDefault'] == true,
      );
}

num? _toNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

/// "₹499 / 1 month" style label shared by the plan screens.
String formatPrice(num? price, String? currency, String? intervalType, int? intervalCount) {
  if (price == null || price == 0) return 'Free';
  final amount = price % 1 == 0 ? price.toInt().toString() : price.toStringAsFixed(2);
  final symbol = switch (currency?.toUpperCase()) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    null => '',
    final other => '$other ',
  };
  final count = intervalCount ?? 1;
  // PassVaultapi's IntervalType (utilities/index.js): 1 = day, 2 = month, 3 = year.
  final unit = switch (intervalType) {
    '1' => 'day',
    '2' => 'month',
    '3' => 'year',
    _ => null,
  };
  final interval = unit == null ? '' : ' / ${count == 1 ? unit : '$count ${unit}s'}';
  return '$symbol$amount$interval';
}
