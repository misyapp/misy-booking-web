import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../contants/global_data.dart';
import '../../contants/sized_box.dart';
import '../../functions/validation_functions.dart';
import '../../provider/auth_provider.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/input_text_field_widget.dart';
import '../../widget/round_edged_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  TextEditingController oldPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmPassController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  ValueNotifier currentP = ValueNotifier(true);
  ValueNotifier newP = ValueNotifier(true);
  ValueNotifier confirmP = ValueNotifier(true);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate("changePassword"),
      ),
      bottomNavigationBar: Consumer<CustomAuthProvider>(
          builder: (context, customAuthProvider, child) {
        return SafeArea(
          child: RoundEdgedButton(
            text: translate("save"),
            width: double.infinity,
            verticalMargin: 20,
            horizontalMargin: globalHorizontalPadding,
            onTap: () {
              if (formKey.currentState!.validate()) {
                customAuthProvider.changePasswordFunction(
                    oldpassword: oldPasswordController.text,
                    newpassword: newPasswordController.text,
                    context: context);
              }
            },
          ),
        );
      }),
      body: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: globalHorizontalPadding, vertical: 18),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              children: [
                ValueListenableBuilder(
                  valueListenable: currentP,
                  builder: (context, value, child) => InputTextFieldWidget(
                    controller: oldPasswordController,
                    hintText: translate("oldPassword"),
                    obscureText: value,
                    suffix: IconButton(
                      onPressed: () {
                        currentP.value = !value;
                      },
                      icon: Icon(
                        value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    ),
                    validator: (val) {
                      return ValidationFunction.passwordValidation(val);
                    },
                  ),
                ),
                vSizedBox2,
                ValueListenableBuilder(
                  valueListenable: newP,
                  builder: (context, value, child) => InputTextFieldWidget(
                    controller: newPasswordController,
                    hintText: translate("enterNewPassword"),
                    obscureText: value,
                    suffix: IconButton(
                      onPressed: () {
                        newP.value = !value;
                      },
                      icon: Icon(
                        value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    ),
                    validator: (val) {
                      return ValidationFunction.passwordValidation(val);
                    },
                  ),
                ),
                vSizedBox2,
                ValueListenableBuilder(
                  valueListenable: confirmP,
                  builder: (context, value, child) => InputTextFieldWidget(
                    controller: confirmPassController,
                    obscureText: value,
                    suffix: IconButton(
                      onPressed: () {
                        confirmP.value = !value;
                      },
                      icon: Icon(
                        value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    ),
                    hintText: translate("confirmNewPassword"),
                    validator: (val) =>
                        ValidationFunction.confirmPasswordValidation(
                            val, newPasswordController.text),
                  ),
                ),
                vSizedBox2,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
