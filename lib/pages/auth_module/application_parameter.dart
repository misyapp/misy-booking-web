// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/contants/sized_box.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/provider/dark_theme_provider.dart';
import 'package:rider_ride_hailing_app/provider/google_map_provider.dart';
import 'package:rider_ride_hailing_app/provider/internet_connectivity_provider.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/services/sunrise_sunset_service.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ApplicationParameters extends StatefulWidget {
  const ApplicationParameters({super.key});

  @override
  State<ApplicationParameters> createState() => _ApplicationParametersState();
}

class _ApplicationParametersState extends State<ApplicationParameters>
    with SingleTickerProviderStateMixin {
  ValueNotifier<bool> automaticenableModeNoti = ValueNotifier(false);
  ValueNotifier<bool> phoneSettingModeNoti = ValueNotifier(false);
  ValueNotifier<bool> darkModeNoti = ValueNotifier(false);
  ValueNotifier<bool> darkModeOffNoti = ValueNotifier(false);
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      int settingValue = await DevFestPreferences().getDarkModeSetting();
      if (settingValue == 1) {
        automaticenableModeNoti.value = true;
      } else if (settingValue == 2) {
        darkModeNoti.value = true;
      } else if (settingValue == 3) {
        phoneSettingModeNoti.value = true;
      } else {
        darkModeOffNoti.value = true;
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeChange = Provider.of<DarkThemeProvider>(context);
    final mapProvider = Provider.of<GoogleMapProvider>(context, listen: false);
    final isDarkMode = themeChange.darkTheme;

    return Scaffold(
      backgroundColor: MyColors.whiteThemeColor(),
      appBar: CustomAppBar(
        title: translate("settings"),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: globalHorizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // NOTE: Section mode nuit masquée temporairement (v2.1.36)
                // _buildSectionCard(
                //   isDarkMode: isDarkMode,
                //   child: Column(
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       ... dark mode options ...
                //     ],
                //   ),
                // ),
                // const SizedBox(height: 20),
                _buildSectionCard(
                  isDarkMode: isDarkMode,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.language,
                            color: MyColors.primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SubHeadingText(
                                  translate("Change language"),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                const SizedBox(height: 4),
                                ParagraphText(
                                  translate("ChangeHoleAppLanguage"),
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder(
                        valueListenable: selectedLanguage,
                        builder: (context, selectedLanguageValue, child) => _buildLanguageOption(
                          isDarkMode: isDarkMode,
                          isSelected: selectedLanguageValue == 'French',
                          onTap: () {
                            selectedLanguage.value = "French";
                            selectedLanguageNotifier.value = languagesList[2];
                            selectedLocale.value = const Locale('fr');
                            DevFestPreferences().setLanguageCode("fr");
                            updateUserPreferedLanguage(preferedLanguageCode: "fr");
                            Provider.of<DarkThemeProvider>(context, listen: false)
                                .notifyListeners();
                          },
                          language: translate("French"),
                          flag: "🇫🇷",
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: selectedLanguage,
                        builder: (context, selectedLanguageValue, child) => _buildLanguageOption(
                          isDarkMode: isDarkMode,
                          isSelected: selectedLanguageValue == 'Malagasy',
                          onTap: () {
                            selectedLanguage.value = "Malagasy";
                            selectedLanguageNotifier.value = languagesList[1];
                            selectedLocale.value = const Locale('mg');
                            DevFestPreferences().setLanguageCode("mg");
                            updateUserPreferedLanguage(preferedLanguageCode: "mg");
                            Provider.of<DarkThemeProvider>(context, listen: false)
                                .notifyListeners();
                          },
                          language: translate("Malagasy"),
                          flag: "🇲🇬",
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: selectedLanguage,
                        builder: (context, selectedLanguageValue, child) => _buildLanguageOption(
                          isDarkMode: isDarkMode,
                          isSelected: selectedLanguageValue == 'English',
                          onTap: () {
                            selectedLanguage.value = "English";
                            selectedLanguageNotifier.value = languagesList[0];
                            DevFestPreferences().setLanguageCode("en");
                            selectedLocale.value = const Locale('en');
                            updateUserPreferedLanguage(preferedLanguageCode: "en");
                            Provider.of<DarkThemeProvider>(context, listen: false)
                                .notifyListeners();
                          },
                          language: translate("English"),
                          flag: "🇬🇧",
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: selectedLanguage,
                        builder: (context, selectedLanguageValue, child) => _buildLanguageOption(
                          isDarkMode: isDarkMode,
                          isSelected: selectedLanguageValue == 'Italian',
                          onTap: () {
                            selectedLanguage.value = "Italian";
                            selectedLanguageNotifier.value = languagesList[3];
                            DevFestPreferences().setLanguageCode("it");
                            selectedLocale.value = const Locale('it');
                            updateUserPreferedLanguage(preferedLanguageCode: "it");
                            Provider.of<DarkThemeProvider>(context, listen: false)
                                .notifyListeners();
                          },
                          language: translate("Italian"),
                          flag: "🇮🇹",
                        ),
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder(
                        valueListenable: selectedLanguage,
                        builder: (context, selectedLanguageValue, child) => _buildLanguageOption(
                          isDarkMode: isDarkMode,
                          isSelected: selectedLanguageValue == 'Polish',
                          onTap: () {
                            selectedLanguage.value = "Polish";
                            selectedLanguageNotifier.value = languagesList[4];
                            DevFestPreferences().setLanguageCode("pl");
                            selectedLocale.value = const Locale('pl');
                            updateUserPreferedLanguage(preferedLanguageCode: "pl");
                            Provider.of<DarkThemeProvider>(context, listen: false)
                                .notifyListeners();
                          },
                          language: translate("Polish"),
                          flag: "🇵🇱",
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDarkMode,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final container = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: container,
      );
    }

    return container;
  }

  Widget _buildRadioOption({
    required bool isDarkMode,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? MyColors.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? MyColors.primaryColor
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? MyColors.primaryColor
                        : isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MyColors.primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? MyColors.primaryColor
                    : isDarkMode
                        ? Colors.grey[400]
                        : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubHeadingText(
                      title,
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? MyColors.primaryColor
                          : isDarkMode
                              ? Colors.white
                              : Colors.black87,
                    ),
                    const SizedBox(height: 2),
                    ParagraphText(
                      subtitle,
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLanguageOption({
    required bool isDarkMode,
    required bool isSelected,
    required VoidCallback onTap,
    required String language,
    required String flag,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? MyColors.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? MyColors.primaryColor
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? MyColors.primaryColor
                        : isDarkMode
                            ? Colors.grey[600]!
                            : Colors.grey[400]!,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MyColors.primaryColor,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                flag,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              SubHeadingText(
                language,
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? MyColors.primaryColor
                    : isDarkMode
                        ? Colors.white
                        : Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }

  darkModeSettingConfig(
      {required bool currentValue, required int settingIndex}) {
    if (currentValue) {
      DevFestPreferences().setDarkModeSetting(settingIndex);
    } else {
      DevFestPreferences().setDarkModeSetting(-1);
    }
  }

  phoneSettingDeafultFunction() {
    final themeChange = Provider.of<DarkThemeProvider>(context, listen: false);
    darkModeSettingConfig(currentValue: true, settingIndex: 3);
    Brightness platformBrightness = MediaQuery.of(context).platformBrightness;
    if (platformBrightness == Brightness.dark) {
      themeChange.darkTheme = true;
    } else {
      themeChange.darkTheme = false;
    }
  }

  updateUserPreferedLanguage({required String preferedLanguageCode}) async {
    Provider.of<CustomAuthProvider>(context, listen: false)
        .editProfile({"preferedLanguage": preferedLanguageCode},showLoader: isInternetConnect);
  }
}
