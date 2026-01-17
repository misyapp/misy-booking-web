import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/ammount_show_function.dart';
import 'package:rider_ride_hailing_app/provider/promocodes_provider.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:rider_ride_hailing_app/widget/input_text_field_widget.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rider_ride_hailing_app/widget/circular_back_button.dart';

class MyPromoCodesScreen extends StatefulWidget {
  const MyPromoCodesScreen({super.key});

  @override
  State<MyPromoCodesScreen> createState() => _MyPromoCodesScreenState();
}

class _MyPromoCodesScreenState extends State<MyPromoCodesScreen> {
  final TextEditingController _promocodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PromocodesProvider>(context, listen: false).getPromoCodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.backgroundThemeColor(),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildPromoInputCard(context),
                      vSizedBox3,
                      _buildPromoList(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bouton retour avec cercle blanc
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: const CircularBackButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height / 4, // 1/4 de l'écran
      width: double.infinity,
      child: Image.asset(
        'assets/images/promotions banner.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback si l'image n'est pas trouvée
          return Container(
            color: MyColors.oldPrimaryColor,
            child: Center(
              child: Icon(
                Icons.card_giftcard,
                size: 80,
                color: MyColors.whiteColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoInputCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: MyColors.cardThemeColor(),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: MyColors.textPrimary),
              hSizedBox,
              SubHeadingText(
                translate('myPromotions'),
                fontWeight: FontWeight.w600,
              ),
            ],
          ),
          vSizedBox2,
          Form(
            key: _formKey,
            child: Row(
              children: [
                Expanded(
                  child: InputTextFieldWidget(
                    controller: _promocodeController,
                    hintText: translate('Enter promo code'),
                    fillColor: MyColors.backgroundThemeColor(),
                    borderColor: MyColors.borderThemeColor(),
                  ),
                ),
                hSizedBox,
                Consumer<PromocodesProvider>(
                  builder: (context, promocodes, child) => ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        promocodes.applyForPromocode(
                            code: _promocodeController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MyColors.oldPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      translate('addPromo'),
                      style: TextStyle(color: MyColors.whiteColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoList(BuildContext context) {
    return Consumer<PromocodesProvider>(
      builder: (context, promocodesProvider, child) {
        if (promocodesProvider.promocodes.isEmpty) {
          return _buildEmptyState(context);
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: promocodesProvider.promocodes.length,
          itemBuilder: (context, index) {
            final promo = promocodesProvider.promocodes[index];
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12.0),
              child: Stack(
                children: [
                  // Coupon principal avec effet de bords dentelés
                  CustomPaint(
                    painter: CouponPainter(color: MyColors.cardThemeColor()),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MyColors.primaryColor.withOpacity(0.08),
                            MyColors.cardThemeColor(),
                            MyColors.cardThemeColor(),
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MyColors.primaryColor.withOpacity(0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Partie gauche - Badge de réduction
                          Container(
                            width: 120,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  MyColors.primaryColor,
                                  MyColors.primaryColor.withOpacity(0.8),
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${promo.discountPercent}%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  translate('reduction'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.local_offer,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Ligne de découpe en pointillés
                          Container(
                            width: 1,
                            height: 160,
                            child: CustomPaint(
                              painter: DashedLinePainter(),
                            ),
                          ),
                          
                          // Partie droite - Informations
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // En-tête avec titre et bouton supprimer
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              translate('promoCodeLabel'),
                                              style: TextStyle(
                                                color: MyColors.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              "${promo.discountPercent}% ${translate('percentDiscount')}",
                                              style: TextStyle(
                                                color: MyColors.blackThemeColor(),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Bouton supprimer amélioré
                                      GestureDetector(
                                        onTap: () {
                                          _showDeleteConfirmation(context, promo);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.red.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 14,
                                                color: Colors.red.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                translate('delete'),
                                                style: TextStyle(
                                                  color: Colors.red.shade600,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Détails
                                  _buildDetailRow(
                                    Icons.directions_car_outlined,
                                    translate('vehicle'),
                                    promo.vehicleCategory.isEmpty
                                        ? translate("All Vehicle")
                                        : vehicleMap[promo.vehicleCategory.first]?.name ?? "",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.account_balance_wallet_outlined,
                                    translate('maxAmount'),
                                    "${formatAriary(promo.maxRideAmount)} ${globalSettings.currency}",
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.schedule_outlined,
                                    translate('expires'),
                                    DateFormat("dd/MM/yyyy").format(promo.expiryDate.toDate()),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Code promo à copier
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: promo.code));
                                      showSnackbar(translate('codeCopied'));
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: MyColors.primaryColor.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: MyColors.primaryColor.withOpacity(0.2),
                                          width: 1,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Code avec icône
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.content_copy,
                                                size: 16,
                                                color: MyColors.primaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  promo.code,
                                                  style: TextStyle(
                                                    color: MyColors.primaryColor,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    fontFamily: 'monospace',
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Instruction en dessous
                                          Text(
                                            translate('tapToCopy'),
                                            style: TextStyle(
                                              color: MyColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Description si présente
                                  if (promo.description.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      promo.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: MyColors.textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Cercles de découpe (effet perforations)
                  Positioned(
                    left: 115,
                    top: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: MyColors.backgroundThemeColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 115,
                    bottom: -5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: MyColors.backgroundThemeColor(),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          vSizedBox4,
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: MyColors.borderLight,
          ),
          vSizedBox2,
          SubHeadingText(
            translate('noPromoCodesYet'),
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
          ),
          vSizedBox,
          ParagraphText(
            translate('stayInformedPromos'),
            textAlign: TextAlign.center,
            color: MyColors.textSecondary,
          ),
          vSizedBox2,
          TextButton(
            onPressed: () async {
              await _openFacebookPage();
            },
            child: Text(
              translate('followUsOnSocial'),
              style: TextStyle(
                color: MyColors.oldPrimaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Ouvre la page Facebook - priorité à l'app FB si installée, sinon navigateur
  Future<void> _openFacebookPage() async {
    const facebookPageId = '61555432697794';
    
    // URL pour ouvrir l'app Facebook directement
    final facebookAppUrl = Uri.parse('fb://profile/$facebookPageId');
    
    // URL de secours pour le navigateur web
    final facebookWebUrl = Uri.parse('https://www.facebook.com/profile.php?id=$facebookPageId');
    
    try {
      // Tenter d'ouvrir avec l'app Facebook en priorité
      if (await canLaunchUrl(facebookAppUrl)) {
        await launchUrl(facebookAppUrl);
      } else {
        // Si l'app FB n'est pas installée, utiliser le navigateur
        await launchUrl(facebookWebUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // En cas d'erreur, forcer l'ouverture dans le navigateur
      await launchUrl(facebookWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: MyColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          "$label:",
          style: TextStyle(
            color: MyColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: MyColors.blackThemeColor(),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, dynamic promo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                translate('deletePromoCodeTitle'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            '${translate('deletePromoCodeConfirm')} "${promo.code}" ?',
            style: TextStyle(
              fontSize: 14,
              color: MyColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                translate('cancel'),
                style: TextStyle(
                  color: MyColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deletePromoCode(promo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                translate('delete'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deletePromoCode(dynamic promo) {
    final promocodesProvider = Provider.of<PromocodesProvider>(context, listen: false);
    promocodesProvider.removePromocode(promo.id);
  }
}

// CustomPainter pour créer l'effet de coupon avec bords dentelés
class CouponPainter extends CustomPainter {
  final Color color;
  CouponPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    
    // Commencer en haut à gauche
    path.moveTo(12, 0);
    
    // Bord supérieur avec effet dentelé
    double x = 12;
    while (x < size.width - 12) {
      path.lineTo(x + 6, 0);
      path.arcToPoint(
        Offset(x + 12, 0),
        radius: const Radius.circular(3),
        clockwise: false,
      );
      x += 12;
    }
    
    // Coin supérieur droit
    path.lineTo(size.width - 12, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 12);
    
    // Bord droit avec effet dentelé
    double y = 12;
    while (y < size.height - 12) {
      path.lineTo(size.width, y + 6);
      path.arcToPoint(
        Offset(size.width, y + 12),
        radius: const Radius.circular(3),
        clockwise: false,
      );
      y += 12;
    }
    
    // Coin inférieur droit
    path.lineTo(size.width, size.height - 12);
    path.quadraticBezierTo(size.width, size.height, size.width - 12, size.height);
    
    // Bord inférieur avec effet dentelé
    x = size.width - 12;
    while (x > 12) {
      path.lineTo(x - 6, size.height);
      path.arcToPoint(
        Offset(x - 12, size.height),
        radius: const Radius.circular(3),
        clockwise: false,
      );
      x -= 12;
    }
    
    // Coin inférieur gauche
    path.lineTo(12, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - 12);
    
    // Bord gauche avec effet dentelé
    y = size.height - 12;
    while (y > 12) {
      path.lineTo(0, y - 6);
      path.arcToPoint(
        Offset(0, y - 12),
        radius: const Radius.circular(3),
        clockwise: false,
      );
      y -= 12;
    }
    
    // Coin supérieur gauche
    path.lineTo(0, 12);
    path.quadraticBezierTo(0, 0, 12, 0);
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// CustomPainter pour créer la ligne en pointillés
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double dashHeight = 4;
    double dashSpace = 3;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
