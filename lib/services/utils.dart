import 'package:cloud_firestore/cloud_firestore.dart';

class DateTools {
  static DateTime tryToParseDate(dynamic dateTimeString) {
    try {
      // check if Timestamp
      if (dateTimeString is Timestamp) {
        return dateTimeString.toDate();
      }
    } catch (e) {}

    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {}

    try {
      return DateTime.parse(dateTimeString.split(' ').first);
    } catch (e) {}

    try {
      // parse epoch time like 1676505600
      final epoch = int.parse(dateTimeString);
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    } catch (e) {}

    try {
      // parse from timestamp in seconds like 1676505600.0
      final epoch = double.parse(dateTimeString).toInt();
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    } catch (e) {
      return DateTime.now();
    }
  }
}
