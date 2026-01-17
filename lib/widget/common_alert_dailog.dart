import 'package:flutter/material.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/widget/round_edged_button.dart';
import '../contants/my_colors.dart';
import '../contants/sized_box.dart';
import 'custom_text.dart';

showCommonAlertDailog(context,
    {String? message,
    String? headingText,
    String? cancelButtonText,
    String? confirmButtonText,
    bool successIcon = true,
    MainAxisAlignment buttonAlignMent = MainAxisAlignment.end,
    bool showCancelButton = true,
    String? imageUrl,
    Icon? icon,
    List<Widget>? actions}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (BuildContext context) {
      return Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Container(
          decoration: BoxDecoration(
            color: MyColors.whiteThemeColor(),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Titre/Icône moderne avec design épuré
                if (imageUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Image.asset(
                      imageUrl,
                      height: 64,
                      width: 64,
                    ),
                  )
                else if (icon != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                    ),
                    child: icon,
                  )
                else if (successIcon)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: MyColors.coralPink.withOpacity(0.1),
                      border: Border.all(color: MyColors.coralPink.withOpacity(0.3), width: 2),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: MyColors.coralPink,
                      size: 48,
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                
                // Titre avec typographie moderne
                if (headingText != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      headingText,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Message avec design épuré
                if (message != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54,
                        height: 1.5,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Boutons modernes
                if (actions != null)
                  ...actions
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (showCancelButton) ...[
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                cancelButtonText ?? translate("cancel"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: MyColors.coralPink,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(
                              confirmButtonText ?? translate("ok"),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}