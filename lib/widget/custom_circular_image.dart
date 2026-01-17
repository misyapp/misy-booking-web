import 'package:rider_ride_hailing_app/utils/platform.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rider_ride_hailing_app/utils/file_image_provider.dart';

import 'custom_loader.dart';

// import 'loader.dart';
enum CustomFileType { asset, network, file }

class CustomCircularImage extends StatelessWidget {
  final double height;
  final double width;
  final double? borderRadius;
  final String imageUrl;
  final CustomFileType fileType;
  final File? image;
  final BoxFit? fit;
  const CustomCircularImage(
      {Key? key,
      required this.imageUrl,
      this.image,
      this.height = 60,
      this.width = 60,
      this.borderRadius,
      this.fileType = CustomFileType.network,
      this.fit})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius ?? height),
          image: fileType == CustomFileType.asset
              ? DecorationImage(fit: fit, image: AssetImage(imageUrl))
              : fileType == CustomFileType.file
                  ? DecorationImage(image: getFileImageProvider(image!))
                  :
                  // DecorationImage(
                  //   image: NetworkImage(
                  //     imageUrl
                  //   ),
                  //
                  //   fit: fit??BoxFit.cover,
                  // ),
                  null),
      child: fileType == CustomFileType.network
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              fit: fit,
              filterQuality: FilterQuality.high,
              placeholder: (context, url) => const Padding(
                padding: EdgeInsets.all(14.0),
                child: CustomLoader(),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            )
          : null,
    );
  }
}
