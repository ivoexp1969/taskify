// Stub файл за web компилация
// Този файл се използва само когато приложението се компилира за web
// На mobile се използва истинският purchases_flutter пакет

/// Stub за PurchasesConfiguration
class PurchasesConfiguration {
  final String apiKey;
  PurchasesConfiguration(this.apiKey);
}

/// Stub за CustomerInfo
class CustomerInfo {
  final EntitlementInfos entitlements = EntitlementInfos();
}

/// Stub за EntitlementInfos
class EntitlementInfos {
  final Map<String, EntitlementInfo> all = {};
}

/// Stub за EntitlementInfo
class EntitlementInfo {
  final bool isActive = false;
  final String? productIdentifier;
  EntitlementInfo({this.productIdentifier});
}

/// Stub за StoreProduct
class StoreProduct {
  final String identifier;
  final String title;
  final String description;
  final String priceString;
  final double price;
  final String currencyCode;
  final IntroductoryPrice? introductoryPrice;

  StoreProduct({
    required this.identifier,
    this.title = '',
    this.description = '',
    this.priceString = '',
    this.price = 0.0,
    this.currencyCode = '',
    this.introductoryPrice,
  });
}

/// Stub за PeriodUnit
enum PeriodUnit { day, week, month, year, unknown }

/// Stub за IntroductoryPrice
class IntroductoryPrice {
  final double price;
  final String priceString;
  final String period;
  final int cycles;
  final PeriodUnit periodUnit;
  final int periodNumberOfUnits;

  IntroductoryPrice({
    this.price = 0.0,
    this.priceString = '',
    this.period = '',
    this.cycles = 0,
    this.periodUnit = PeriodUnit.unknown,
    this.periodNumberOfUnits = 0,
  });
}

/// Stub за Package
class Package {
  final String identifier;
  final StoreProduct storeProduct;
  final PackageType packageType;
  
  Package({
    required this.identifier,
    required this.storeProduct,
    this.packageType = PackageType.unknown,
  });
}

/// Stub за PackageType
enum PackageType {
  unknown,
  custom,
  lifetime,
  annual,
  sixMonth,
  threeMonth,
  twoMonth,
  monthly,
  weekly,
}

/// Stub за Offerings
class Offerings {
  final Offering? current;
  final Map<String, Offering> all;
  
  Offerings({this.current, this.all = const {}});
}

/// Stub за Offering
class Offering {
  final String identifier;
  final List<Package> availablePackages;
  final Package? lifetime;
  final Package? annual;
  final Package? sixMonth;
  final Package? threeMonth;
  final Package? twoMonth;
  final Package? monthly;
  final Package? weekly;
  
  Offering({
    required this.identifier,
    this.availablePackages = const [],
    this.lifetime,
    this.annual,
    this.sixMonth,
    this.threeMonth,
    this.twoMonth,
    this.monthly,
    this.weekly,
  });
}

/// Stub за Purchases
class Purchases {
  static Future<void> configure(PurchasesConfiguration configuration) async {}
  
  static void addCustomerInfoUpdateListener(Function(CustomerInfo) listener) {}
  
  static Future<CustomerInfo> getCustomerInfo() async {
    return CustomerInfo();
  }
  
  static Future<List<StoreProduct>> getProducts(List<String> productIds) async {
    return [];
  }
  
  static Future<Offerings> getOfferings() async {
    return Offerings();
  }
  
  static Future<CustomerInfo> purchaseStoreProduct(StoreProduct product) async {
    return CustomerInfo();
  }
  
  static Future<CustomerInfo> purchasePackage(Package package) async {
    return CustomerInfo();
  }
  
  static Future<CustomerInfo> restorePurchases() async {
    return CustomerInfo();
  }
}
