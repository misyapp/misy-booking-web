import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/functions/loading_functions.dart';
import 'package:rider_ride_hailing_app/functions/print_function.dart';
import 'package:rider_ride_hailing_app/services/firestore_services.dart';
import '../../contants/global_data.dart';
import '../../contants/sized_box.dart';
import '../../widget/custom_appbar.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  ValueNotifier<String?> privacyPolicy = ValueNotifier(null);
  ValueNotifier<bool> isLoading = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      var res = await FirestoreServices.content.get();
      if (res.docs.isNotEmpty) {
        var privacy = res.docs[0].data() as Map;
        myCustomPrintStatement("privacy is that $privacy");
        privacyPolicy.value = privacy[
                'privacyPolicyTermsCondition${selectedLanguageNotifier.value["key"]}'] ??
            '<br><br><br> <h2 style="text-align: center;">No Data Found</h2>';
      } else {
        privacyPolicy.value = '<br><br><br> <h2 style="text-align: center;">No Data Found</h2>';
      }
      isLoading.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translate("privacyPolicy"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: isLoading,
              builder: (context, loading, child) {
                if (loading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return ValueListenableBuilder(
                  valueListenable: privacyPolicy,
                  builder: (context, privacyPolicyValue, child) =>
                      SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: globalHorizontalPadding, vertical: 2),
                      child: HtmlWidget(
                        '''${privacyPolicy.value ?? ''} ''',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          vSizedBox6,
        ],
      ),
    );
  }
}
