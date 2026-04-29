import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_image_url.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/modal/user_social_login_detail_modal.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/forget_password_screen.dart';
import 'package:rider_ride_hailing_app/pages/view_module/privacy_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/services/share_prefrence_service.dart';
import 'package:rider_ride_hailing_app/services/social_login_service.dart';

enum WebAuthMode { login, signup }

/// Carte centrée d'authentification pour la version web.
///
/// Conçue pour être ouverte par [showGeneralDialog] depuis la home, afin que
/// la barre supérieure et la carte du fond restent visibles derrière un
/// backdrop assombri.
class WebAuthScreen extends StatefulWidget {
  final WebAuthMode initialMode;
  const WebAuthScreen({super.key, this.initialMode = WebAuthMode.login});

  @override
  State<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends State<WebAuthScreen> {
  static const Color _coral = Color(0xFFFF5357);
  static const Color _coralDark = Color(0xFFD93B40);

  late WebAuthMode _mode;

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _signupFirstName = TextEditingController();
  final _signupLastName = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPhone = TextEditingController();
  final _signupPassword = TextEditingController();

  final _loginPasswordVisible = ValueNotifier<bool>(false);
  final _signupPasswordVisible = ValueNotifier<bool>(false);
  final _loginIsEmail = ValueNotifier<bool>(true);

  String _loginCountryCode = "+261";
  String _signupCountryCode = "+261";
  String _signupCountryName = "Madagasikara";

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _signupFirstName.dispose();
    _signupLastName.dispose();
    _signupEmail.dispose();
    _signupPhone.dispose();
    _signupPassword.dispose();
    _loginPasswordVisible.dispose();
    _signupPasswordVisible.dispose();
    _loginIsEmail.dispose();
    super.dispose();
  }

  void _switchTo(WebAuthMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: size.height < 700 ? 40 : 88,
          bottom: 32,
          left: 16,
          right: 16,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: Colors.white,
              elevation: 18,
              shadowColor: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/icons/misy_logo_rose.png',
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildModeTabs(),
                        const SizedBox(height: 22),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) =>
                              FadeTransition(opacity: anim, child: child),
                          child: _mode == WebAuthMode.login
                              ? _buildLoginForm(key: const ValueKey('login'))
                              : _buildSignupForm(key: const ValueKey('signup')),
                        ),
                        const SizedBox(height: 18),
                        _buildSocialSection(),
                        const SizedBox(height: 18),
                        _buildLegalFooter(),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      tooltip: "Fermer",
                      icon: const Icon(Icons.close,
                          color: Color(0xFF8A8A8E), size: 22),
                      onPressed: _close,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Tabs ─────────────────────────

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              label: translate("signIn"),
              selected: _mode == WebAuthMode.login,
              onTap: () => _switchTo(WebAuthMode.login),
            ),
          ),
          Expanded(
            child: _buildModeTab(
              label: translate("signUp"),
              selected: _mode == WebAuthMode.signup,
              onTap: () => _switchTo(WebAuthMode.signup),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  selected ? const Color(0xFF1D1D1F) : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Login form ─────────────────────────

  Widget _buildLoginForm({Key? key}) {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel("E-mail ou téléphone"),
          Consumer<CustomAuthProvider>(
            builder: (context, auth, _) => ValueListenableBuilder<bool>(
              valueListenable: _loginIsEmail,
              builder: (context, isEmail, __) => _styledField(
                controller: auth.emailAddressCont,
                hintText: isEmail ? "vous@exemple.com" : "34 12 345 67",
                keyboardType: isEmail
                    ? TextInputType.emailAddress
                    : const TextInputType.numberWithOptions(signed: true),
                inputFormatters: isEmail
                    ? null
                    : [
                        LengthLimitingTextInputFormatter(10),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                prefix: isEmail
                    ? const Padding(
                        padding: EdgeInsets.only(left: 12, right: 8),
                        child: Icon(Icons.alternate_email_rounded,
                            color: Color(0xFF8A8A8E), size: 20),
                      )
                    : SizedBox(
                        width: 90,
                        child: CountryCodePicker(
                          flagWidth: 22,
                          initialSelection: 'Madagasikara',
                          onChanged: (v) =>
                              _loginCountryCode = v.dialCode.toString(),
                          onInit: (c) =>
                              _loginCountryCode = c?.dialCode ?? "+261",
                          showCountryOnly: false,
                          showFlag: true,
                          alignLeft: false,
                          padding: EdgeInsets.zero,
                          flagDecoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                onChanged: (val) {
                  if (val.isNotEmpty && val.startsWith(RegExp(r'[0-9]'))) {
                    if (_loginIsEmail.value) _loginIsEmail.value = false;
                  } else {
                    if (!_loginIsEmail.value) _loginIsEmail.value = true;
                  }
                },
                validator: (val) => isEmail
                    ? ValidationFunction.emailValidation(val)
                    : ValidationFunction.mobileNumberValidation(val),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Mot de passe"),
          Consumer<CustomAuthProvider>(
            builder: (context, auth, _) => ValueListenableBuilder<bool>(
              valueListenable: _loginPasswordVisible,
              builder: (context, visible, __) => _styledField(
                controller: auth.passwordCont,
                hintText: "••••••••",
                obscureText: !visible,
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12, right: 8),
                  child: Icon(Icons.lock_outline_rounded,
                      color: Color(0xFF8A8A8E), size: 20),
                ),
                suffix: IconButton(
                  icon: Icon(
                    visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF8A8A8E),
                    size: 20,
                  ),
                  onPressed: () => _loginPasswordVisible.value =
                      !_loginPasswordVisible.value,
                ),
                validator: (v) => ValidationFunction.passwordValidation(v),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: _coral,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  push(context: context, screen: const ForgetScreen()),
              child: Text(
                translate("forgotPassword"),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Consumer<CustomAuthProvider>(
            builder: (context, auth, _) => _primaryButton(
              label: translate("login"),
              onPressed: () => _submitLogin(auth),
            ),
          ),
        ],
      ),
    );
  }

  void _submitLogin(CustomAuthProvider auth) {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_loginIsEmail.value) {
      auth.loginFunction(
        context: context,
        emailId: auth.emailAddressCont.text.trim(),
        password: auth.passwordCont.text,
      );
    } else {
      auth.logInWithPhoneNumberAndPassword(
        context: context,
        countryCode: _loginCountryCode,
        password: auth.passwordCont.text,
        phoneNumber: auth.emailAddressCont.text.trim(),
      );
    }
  }

  // ───────────────────────── Signup form ─────────────────────────

  Widget _buildSignupForm({Key? key}) {
    return Form(
      key: _signupFormKey,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel(translate("firstName")),
                    _styledField(
                      controller: _signupFirstName,
                      hintText: "Jean",
                      validator: (v) =>
                          ValidationFunction.requiredValidation(v ?? ""),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel(translate("lastName")),
                    _styledField(
                      controller: _signupLastName,
                      hintText: "Rakoto",
                      validator: (v) =>
                          ValidationFunction.requiredValidation(v ?? ""),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel("Adresse e-mail"),
          _styledField(
            controller: _signupEmail,
            hintText: "vous@exemple.com",
            keyboardType: TextInputType.emailAddress,
            validator: (v) => ValidationFunction.emailValidation(v),
            prefix: const Padding(
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Icon(Icons.alternate_email_rounded,
                  color: Color(0xFF8A8A8E), size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel(translate("phoneNumber")),
          _styledField(
            controller: _signupPhone,
            hintText: "34 12 345 67",
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              LengthLimitingTextInputFormatter(10),
              FilteringTextInputFormatter.digitsOnly,
            ],
            validator: (v) => ValidationFunction.mobileNumberValidation(v),
            prefix: SizedBox(
              width: 90,
              child: CountryCodePicker(
                flagWidth: 22,
                initialSelection: 'Madagasikara',
                onChanged: (v) {
                  _signupCountryName = v.name?.toString() ?? _signupCountryName;
                  _signupCountryCode = v.dialCode.toString();
                },
                onInit: (c) {
                  _signupCountryName = c?.name?.toString() ?? _signupCountryName;
                  _signupCountryCode = c?.dialCode ?? "+261";
                },
                showCountryOnly: false,
                showFlag: true,
                alignLeft: false,
                padding: EdgeInsets.zero,
                flagDecoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _fieldLabel("Mot de passe"),
          ValueListenableBuilder<bool>(
            valueListenable: _signupPasswordVisible,
            builder: (context, visible, _) => _styledField(
              controller: _signupPassword,
              hintText: "Au moins 6 caractères",
              obscureText: !visible,
              validator: (v) => ValidationFunction.passwordValidation(v),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.lock_outline_rounded,
                    color: Color(0xFF8A8A8E), size: 20),
              ),
              suffix: IconButton(
                icon: Icon(
                  visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF8A8A8E),
                  size: 20,
                ),
                onPressed: () => _signupPasswordVisible.value =
                    !_signupPasswordVisible.value,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Consumer<CustomAuthProvider>(
            builder: (context, auth, _) => _primaryButton(
              label: translate("signUp"),
              onPressed: () => _submitSignup(auth),
            ),
          ),
        ],
      ),
    );
  }

  void _submitSignup(CustomAuthProvider auth) {
    if (!(_signupFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    DevFestPreferences().setVerificationCode("");
    DevFestPreferences().setUserVerificationRequest({});
    auth.numberVerificationOTP = '';

    final request = <String, dynamic>{
      'name':
          "${_signupFirstName.text.trim()} ${_signupLastName.text.trim()}",
      'firstName': _signupFirstName.text.trim(),
      'lastName': _signupLastName.text.trim(),
      'email': _signupEmail.text.trim(),
      'verified': true,
      'isBlocked': false,
      'isCustomer': true,
      'phoneNo': _signupPhone.text.trim(),
      'countryName': _signupCountryName,
      'countryCode': _signupCountryCode,
      'password': _signupPassword.text,
      'profileImage': dummyUserImage,
    };
    auth.checkMobileNumberAndEmailExist(context, request);
  }

  // ───────────────────────── Shared bits ─────────────────────────

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3D3D3F),
        ),
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    Widget? prefix,
    Widget? suffix,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1D1D1F)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        prefixIcon: prefix,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _coral, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _coral,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? _coralDark.withOpacity(0.15)
                : null,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildSocialSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "ou continuer avec",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _socialButton(
                label: "Google",
                iconSvg: MyImagesUrl.google,
                onTap: _onGoogleTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _socialButton(
                label: "Facebook",
                iconAsset: MyImagesUrl.facebook,
                onTap: _onFacebookTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _socialButton({
    required String label,
    String? iconSvg,
    String? iconAsset,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1D1D1F),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconSvg != null)
              SvgPicture.asset(iconSvg, width: 18, height: 18)
            else if (iconAsset != null)
              ClipOval(
                child: Image.asset(
                  iconAsset,
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onGoogleTap() async {
    EasyLoading.show(
      status: 'Connexion avec Google...',
      maskType: EasyLoadingMaskType.black,
      dismissOnTap: false,
    );
    try {
      final UserSocialLoginDeatilModal? res =
          await SocialLoginServices().signInWithGoogle();
      EasyLoading.dismiss();
      if (res != null) {
        myCustomPrintStatement("Google login: ${res.toJson()}");
      }
    } catch (e) {
      EasyLoading.dismiss();
      myCustomPrintStatement("Google login error: $e");
    }
  }

  Future<void> _onFacebookTap() async {
    EasyLoading.show(
      status: 'Connexion avec Facebook...',
      maskType: EasyLoadingMaskType.black,
      dismissOnTap: false,
    );
    try {
      final UserSocialLoginDeatilModal? res =
          await SocialLoginServices().facebookLogin();
      EasyLoading.dismiss();
      if (res != null) {
        myCustomPrintStatement("Facebook login: ${res.toJson()}");
      }
    } catch (e) {
      EasyLoading.dismiss();
      myCustomPrintStatement("Facebook login error: $e");
    }
  }

  Widget _buildLegalFooter() {
    return Row(
      children: [
        const Icon(Icons.lock_outline_rounded, size: 13, color: Colors.green),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            textAlign: TextAlign.start,
            text: TextSpan(
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: "Données chiffrées. En continuant, j'accepte la "),
                TextSpan(
                  text: "Politique de confidentialité",
                  style: const TextStyle(
                    color: _coral,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => push(
                        context: context,
                        screen: const PrivacyPolicyScreen()),
                ),
                const TextSpan(text: " et les "),
                TextSpan(
                  text: "Conditions générales",
                  style: const TextStyle(
                    color: _coral,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => push(
                        context: context,
                        screen: const PrivacyPolicyScreen()),
                ),
                const TextSpan(text: "."),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
