import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rider_ride_hailing_app/contants/global_data.dart';
import 'package:rider_ride_hailing_app/contants/web_theme.dart';
import 'package:rider_ride_hailing_app/functions/navigation_functions.dart';
import 'package:rider_ride_hailing_app/functions/validation_functions.dart';
import 'package:rider_ride_hailing_app/pages/auth_module/phone_number_screen.dart';
import 'package:rider_ride_hailing_app/provider/auth_provider.dart';
import 'package:rider_ride_hailing_app/widget/show_snackbar.dart';

/// Section « Profil » de l'espace compte web : édition du nom/e-mail via
/// `CustomAuthProvider.editProfile` (même payload complet que
/// PhoneNumberScreen pour éviter les nulls au parsing UserModal).
/// Le numéro de téléphone se modifie par le flux dédié (PhoneNumberScreen
/// → OTP), pas ici.
class AccountProfileSection extends StatefulWidget {
  const AccountProfileSection({super.key});

  @override
  State<AccountProfileSection> createState() => _AccountProfileSectionState();
}

class _AccountProfileSectionState extends State<AccountProfileSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = userData.value;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = userData.value;
    final auth = Provider.of<CustomAuthProvider>(context, listen: false);
    if (user == null || auth.currentUser == null) return;

    setState(() => _saving = true);
    try {
      await auth.editProfile({
        "id": auth.currentUser!.uid,
        "name": "${_firstName.text.trim()} ${_lastName.text.trim()}".trim(),
        "firstName": _firstName.text.trim(),
        "lastName": _lastName.text.trim(),
        "email": _email.text.trim(),
        "verified": user.verified,
        "isBlocked": user.isBlocked,
        "isCustomer": user.isCustomer,
        "profileImage": user.profileImage,
        "phoneNo": user.phoneNo,
        "countryName": user.countryName,
        "countryCode": user.countryCode,
      });
      showSnackbar('Profil mis à jour.');
      if (mounted) setState(() {});
    } catch (e) {
      showSnackbar('Erreur lors de la mise à jour du profil.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: userData,
      builder: (context, user, _) {
        if (user == null) return const SizedBox.shrink();
        final phone = (user.phoneNo == null || user.phoneNo!.isEmpty)
            ? 'Non renseigné'
            : '${user.countryCode} ${user.phoneNo}';
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mon profil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // En-tête identité
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: kWebPageBackground,
                        backgroundImage: user.profileImage.isNotEmpty
                            ? NetworkImage(user.profileImage)
                            : null,
                        child: user.profileImage.isEmpty
                            ? Icon(Icons.person,
                                size: 32, color: Colors.grey.shade400)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          // Changement de numéro = flux dédié avec
                          // vérification (PhoneNumberScreen carte web).
                          push(
                              context: context,
                              screen: const PhoneNumberScreen());
                        },
                        icon: const Icon(Icons.phone_outlined, size: 16),
                        label: const Text('Modifier le numéro'),
                        style: TextButton.styleFrom(
                          foregroundColor: kWebCoralDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Formulaire identité
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations personnelles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                label: 'Prénom',
                                controller: _firstName,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Prénom requis'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _field(
                                label: 'Nom',
                                controller: _lastName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _field(
                          label: 'E-mail',
                          controller: _email,
                          validator: (v) =>
                              ValidationFunction.emailValidation(v),
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: kWebCoral,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: kWebPageBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kWebCoral),
        ),
      ),
    );
  }
}
