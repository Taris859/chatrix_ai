import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../auth/auth_service.dart';
import 'ambient_sound_manager.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();

  factory IAPService() => _instance;

  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final List<String> _productIds = [
    'chatrix_premium_1_week',
    'chatrix_premium_1_month',
    'chatrix_premium_3_months',
    'chatrix_premium_1_year',
  ];

  List<ProductDetails> products = [];
  
  // Callbacks for UI updates
  Function(PurchaseStatus, String?)? onPurchaseStatusChanged;

  Future<void> initialize() async {
    final available = await _iap.isAvailable();

    if (!available) {
      print('Google Play Billing unavailable');
      return;
    }

    final response = await _iap.queryProductDetails(_productIds.toSet());
    products = response.productDetails;

    // Sort products by price to display them in logical order
    products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

    _subscription = _iap.purchaseStream.listen(
      _listenToPurchases,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        print('Purchase stream error: $error');
      },
    );
  }

  Future<void> buySubscription(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    
    // As per user requirement, use buyNonConsumable for Google Play subscriptions internally
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> _listenToPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        onPurchaseStatusChanged?.call(PurchaseStatus.pending, null);
      } else if (purchase.status == PurchaseStatus.error) {
        print("Purchase error: ${purchase.error?.message}");
        onPurchaseStatusChanged?.call(PurchaseStatus.error, purchase.error?.message);
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        // [Backend Verification Stub]
        // TODO: Send purchase.verificationData.serverVerificationData to backend to verify token.
        // For now, we will grant premium access upon successful callback.
        print("Purchase successful/restored. Verifying...");
        
        await AuthService().setPremium(true);
        
        // Play triumphant ambient chime sound if it's a new purchase (optional for restored)
        if (purchase.status == PurchaseStatus.purchased) {
          await AmbientSoundManager().setAmbient(AmbientType.thunder);
          Future.delayed(const Duration(seconds: 2), () {
            AmbientSoundManager().setAmbient(AmbientType.rain);
          });
        }
        
        onPurchaseStatusChanged?.call(purchase.status, null);

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
