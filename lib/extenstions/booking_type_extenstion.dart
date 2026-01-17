// ignore_for_file: constant_identifier_names

enum BookingStatusType {
  PENDING_REQUEST,
  ACCEPTED,
  DRIVER_REACHED,
  RIDE_STARTED,
  DESTINATION_REACHED,
  RIDE_COMPLETE,
  CANCELLED, // Added CANCELLED state
  CANCELLED_BY_RIDER, // Added CANCELLED_BY_RIDER state
}

extension BookingStatusTypeExtension on BookingStatusType {
  int get value {
    switch (this) {
      case BookingStatusType.PENDING_REQUEST:
        return 0;
      case BookingStatusType.ACCEPTED:
        return 1;
      case BookingStatusType.DRIVER_REACHED:
        return 2;
      case BookingStatusType.RIDE_STARTED:
        return 3;
      case BookingStatusType.DESTINATION_REACHED:
        return 4;
      case BookingStatusType.RIDE_COMPLETE:
        return 5;
      case BookingStatusType.CANCELLED: // Added CANCELLED state
        return 6; // Assign a new value
      case BookingStatusType.CANCELLED_BY_RIDER: // Added CANCELLED_BY_RIDER state
        return 7; // Assign a new value
      default:
        return 0;
    }
  }

  static BookingStatusType fromValue(int value) {
    switch (value) {
      case 0:
        return BookingStatusType.PENDING_REQUEST;
      case 1:
        return BookingStatusType.ACCEPTED;
      case 2:
        return BookingStatusType.DRIVER_REACHED;
      case 3:
        return BookingStatusType.RIDE_STARTED;
      case 4:
        return BookingStatusType.DESTINATION_REACHED;
      case 5:
        return BookingStatusType.RIDE_COMPLETE;
      case 6: // Added CANCELLED state
        return BookingStatusType.CANCELLED;
      case 7: // Added CANCELLED_BY_RIDER state
        return BookingStatusType.CANCELLED_BY_RIDER;
      default:
        return BookingStatusType.PENDING_REQUEST;
    }
  }
}
