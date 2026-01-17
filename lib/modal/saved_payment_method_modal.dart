class SavedPaymentMethodModal {
  final String name;
  final String id;
  final String mobileNumber;
  final String icons;
  final Function()? onTap;
  final Function()? onDeleteTap;
  final Function()? onEditTap;
  bool showDivider;
  bool isSelected;
  bool showCheckBox;
  bool showEditIcon;
  bool showDeleteIcon;

  SavedPaymentMethodModal({
    required this.icons,
    required this.isSelected,
    required this.name,
    required this.id,
    required this.mobileNumber,
    required this.onDeleteTap,
    required this.onEditTap,
    required this.onTap,
    required this.showCheckBox,
    required this.showDeleteIcon,
    required this.showDivider,
    required this.showEditIcon,
  });
}
