
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:rider_ride_hailing_app/contants/my_colors.dart';
import 'custom_loader.dart';
import 'dynamic_height_grid_view.dart';




class CustomPaginatedGridView<T> extends StatefulWidget {
  final Widget Function(BuildContext, int) itemBuilder;
  final int? itemCount;
  final int? crossAxisCount;
  final bool load;
  final String noDataText;
  final double? noDataHeight;
  final double? mainAxisSpacing;
  final double? crossAxisSpacing;
  final Color? noDataColor;
  final VoidCallback? onMaxScrollExtent;
  final bool isLastPage;
  final ScrollPhysics? physics;
  final bool wantLoadMore;
  final EdgeInsets? padding;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  // final SliverGridDelegate gridDelegate;

  const CustomPaginatedGridView({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    this.crossAxisCount,
    // required this.gridDelegate,
    this.load = false,
    this.physics ,
    this.noDataText = 'No data found',
    this.noDataHeight,
    this.noDataColor,
    this.onMaxScrollExtent,
    this.isLastPage = false,
    this.wantLoadMore = true,
    this.padding,
    this.onRefresh,
    this.onLoadMore,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
  });

  @override
  _CustomPaginatedGridViewState<T> createState() => _CustomPaginatedGridViewState<T>();
}

class _CustomPaginatedGridViewState<T> extends State<CustomPaginatedGridView<T>> {
  late ScrollController _scrollController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() async {
        if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent && !_isLoading) {
          setState(() => _isLoading = true);
          await widget.onLoadMore?.call();
          setState(() => _isLoading = false);
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildNoDataView(BuildContext context) => RefreshIndicator(
    onRefresh: widget.onRefresh ?? () async {},
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: widget.noDataHeight ?? MediaQuery.of(context).size.height - 280,
        child: Center(
          child: Text(widget.noDataText, style: TextStyle(color: widget.noDataColor)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (widget.load) {
      return const CustomLoader();
    }

    if (widget.itemCount == 0) return _buildNoDataView(context);

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: widget.padding??EdgeInsets.zero,
            child: DynamicHeightGridView(
              crossAxisCount:widget.crossAxisCount?? 2,
              shrinkWrap: true,
              controller: _scrollController,
              physics: widget.physics,
              crossAxisSpacing: widget.crossAxisSpacing??18,
              mainAxisSpacing: widget.mainAxisSpacing??18,
              itemCount: widget.itemCount!,
              builder: widget.itemBuilder,
            ),
          ),
          if (_isLoading)
             Positioned(
              bottom: 10,
              child: LoadingAnimationWidget.twistingDots(
                leftDotColor: MyColors.coralPink,
                rightDotColor: MyColors.horizonBlue,
                size: 30.0,
              ),
            ),
          if (widget.isLastPage)
            const Positioned(
              bottom: 10,
              child: Text('All caught up!', style: TextStyle(fontSize: 18)),
            ),
        ],
      ),
    );
  }
}


//
// class CustomPaginatedGridView<T> extends StatefulWidget {
//   final NullableIndexedWidgetBuilder? itemBuilder;
//   final int? itemCount;
//   final bool load;
//   final String noDataText;
//   final double? noDataHeight;
//   final Color? noDataColor;
//   final Function()? onMaxScrollExtent;
//   final bool isLastPage;
//   final bool wantLoadMore;
//   final EdgeInsets? padding;
//   final Future<void> Function()? onRefresh;
//   final Future<void> Function()? onLoadMore;
//   final SliverGridDelegate gridDelegate;
//
//   const CustomPaginatedGridView({
//     super.key,
//     required this.itemBuilder,
//     required this.itemCount,
//     required this.gridDelegate,
//     this.load = false,
//     this.noDataText = 'No data found',
//     this.noDataHeight,
//     this.noDataColor,
//     this.onMaxScrollExtent,
//     this.isLastPage = false,
//     this.wantLoadMore = true,
//     this.padding,
//     this.onRefresh,
//     this.onLoadMore,
//
//   });
//
//   @override
//   _CustomPaginatedGridViewState<T> createState() =>
//       _CustomPaginatedGridViewState<T>();
// }
//
// class _CustomPaginatedGridViewState<T> extends State<CustomPaginatedGridView<T>> {
//   ScrollController scrollController = ScrollController();
//   bool _isLoading = false;
//
//   initializeListener() {
//     scrollController.addListener(() async {
//       if (scrollController.position.pixels >= scrollController.position.maxScrollExtent) {
//         if (_isLoading) return;
//
//         if (mounted) {
//           setState(() {
//             _isLoading = true;
//           });
//         }
//
//         if (!widget.isLastPage) {
//           try {
//             await widget.onLoadMore!();
//           } catch (e) {
//             myCustomPrintStatement('Error in catch block in grid view: $e');
//           }
//         }
//
//         if (mounted) {
//           setState(() {
//             _isLoading = false;
//           });
//         }
//       }
//     });
//   }
//
//   @override
//   void initState() {
//     initializeListener();
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (widget.load) {
//       return const CustomLoader();
//     }
//
//     if (widget.itemCount == 0) {
//       return RefreshIndicator(
//         onRefresh: () async {
//           try {
//             await widget.onRefresh!();
//           } catch (e) {
//             print('Error in catch block: $e');
//           }
//         },
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: SizedBox(
//             height: widget.noDataHeight ?? MediaQuery.of(context).size.height - 280,
//             child: Center(
//               child: CustomText.bodyText1(
//                 widget.noDataText,
//                 color: widget.noDataColor,
//               ),
//             ),
//           ),
//         ),
//       );
//     }
//
//     return RefreshIndicator(
//       onRefresh: () async {
//         try {
//           await widget.onRefresh!();
//         } catch (e) {
//           print('Error in catch block: $e');
//         }
//       },
//       child: NotificationListener<ScrollUpdateNotification>(
//         onNotification: (scroll) {
//           if (scroll.metrics.maxScrollExtent == scroll.metrics.pixels) {
//             if (widget.onMaxScrollExtent != null) {
//               widget.onMaxScrollExtent!();
//             }
//           }
//           return true;
//         },
//         child: Stack(
//           alignment: Alignment.topCenter,
//           children: [
//             GridView.builder(
//               controller: scrollController,
//               padding: widget.padding,
//               gridDelegate: widget.gridDelegate,
//               itemCount: widget.itemCount,
//               itemBuilder: widget.itemBuilder!,
//             ),
//             // if (widget.wantLoadMore && !_isLoading && !widget.isLastPage)
//             //   const Positioned(
//             //     bottom: 10,
//             //     child: CupertinoActivityIndicator(color: MyColors.primaryColor),
//             //   ),
//             if (widget.isLastPage)
//               const Positioned(
//                 bottom: 10,
//                 child: Text(
//                   'All caught up!',
//                   style: TextStyle(
//                     fontSize: 18,
//                     color: MyColors.primaryColor,
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
