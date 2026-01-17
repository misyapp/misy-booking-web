import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:rider_ride_hailing_app/contants/language_strings.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'package:rider_ride_hailing_app/modal/file_upload_modal.dart';
import 'package:rider_ride_hailing_app/widget/custom_appbar.dart';
import 'package:rider_ride_hailing_app/widget/custom_circular_image.dart';

class ImagePreviewWidget extends StatefulWidget {
  final List<FileUploadModal> image;
  final int imageIndex;
  final double? width;
  final double borderRadius;
  final Color? color;
  final bool isBoxShadow;
  final bool isDownloadIcon;
  final bool isShareIcon;
  final Function()? onTap;
  const ImagePreviewWidget(
      {super.key,
      required this.image,
      required this.imageIndex,
      this.color,
      this.borderRadius = 12.0,
      this.isBoxShadow = true,
      this.isDownloadIcon = false,
      this.isShareIcon = true,
      this.onTap,
      this.width = 30});

  @override
  State<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends State<ImagePreviewWidget> {
  PageController photoPagecontroller = PageController();
  ValueNotifier<int> activeImageIndex = ValueNotifier(0);
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      photoPagecontroller.jumpToPage(widget.imageIndex);
      activeImageIndex.value = widget.imageIndex;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isBackIcon: true,
        isNotificationIcon: false,
        title: translate("Image preview"),
        titleFontSize: 18,
        titleFontWeight: FontWeight.w600,
      ),
      backgroundColor: MyColors.whiteColor,
      body: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                boxShadow: [
                  if (widget.isBoxShadow)
                    BoxShadow(
                        color: MyColors.blackColor50,
                        blurRadius: 0.0,
                        spreadRadius: 0.0,
                        offset: const Offset(0, 0))
                ],
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: widget.color,
              ),
              child: PhotoViewGallery.builder(
                pageController: photoPagecontroller,
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  return widget.image[index].fileType == CustomFileType.network
                      ? PhotoViewGalleryPageOptions(
                          imageProvider: NetworkImage(
                              widget.image[index].type == "2"
                                  ? widget.image[index].thumbnail
                                  : widget.image[index].filePath),
                          initialScale: PhotoViewComputedScale.contained * 1,
                          minScale: 0.2)
                      : PhotoViewGalleryPageOptions(
                          imageProvider:
                              // widget.image[index]
                              // ?
                              FileImage(widget.image[index].type == "2"
                                  ? widget.image[index].thumbnail
                                  : widget.image[index].filePath),
                          //  :

                          initialScale: PhotoViewComputedScale.contained * 1,
                          minScale: 0.2);
                },
                itemCount: widget.image.length,
                loadingBuilder: (context, event) => Center(
                  child: LoadingAnimationWidget.twistingDots(
                    leftDotColor: MyColors.coralPink,
                    rightDotColor: MyColors.horizonBlue,
                    size: 30.0,
                  ),
                ),
                // backgroundDecoration: widget.backgroundDecoration,
                // pageController: widget.pageController,
                onPageChanged: (int index) {
                  activeImageIndex.value = index;
                },
              ),
            ),
            ValueListenableBuilder(
                valueListenable: activeImageIndex,
                builder: (context, activeIndexValue, child) =>
                    widget.image[activeIndexValue].type == "2"
                        ? Center(
                            // left: 50,
                            // right: 50,
                            // top: 50,
                            // bottom: 50,
                            child: IconButton(
                              onPressed: () {
                                // push(
                                //   context: context,
                                //   screen: VideoPlayerWidget(
                                //     documentData:
                                //         widget.image[activeIndexValue],
                                //   ),
                                // );
                              },
                              icon: Icon(
                                Icons.play_circle,
                                size: 35,
                                color: MyColors.primaryColor,
                              ),
                            ),
                          )
                        : Container()),
          ],
        ),
      ),
    );
  }
}
