enum DayActivityStatus { completed, frozen, missed, upcoming }

class DayActivity {
  final String dayLabel;
  final DateTime date;
  final DayActivityStatus status;
  final int minutesTrained;

  const DayActivity({
    required this.dayLabel,
    required this.date,
    required this.status,
    this.minutesTrained = 0,
  });
}

class WeeklyProgressModel {
  final String childName;
  final String? childAvatarUrl;
  final String weekPeriod;
  final int startOvr;
  final int currentOvr;
  final int xpEarnedThisWeek;
  final int totalWorkouts;
  final int totalBallMinutes;
  final int coachApprovedTasks;
  final List<DayActivity> weekDays;
  final Map<String, int> statIncrements;
  final String coachFeedback;

  const WeeklyProgressModel({
    required this.childName,
    this.childAvatarUrl,
    required this.weekPeriod,
    required this.startOvr,
    required this.currentOvr,
    required this.xpEarnedThisWeek,
    required this.totalWorkouts,
    required this.totalBallMinutes,
    required this.coachApprovedTasks,
    required this.weekDays,
    required this.statIncrements,
    required this.coachFeedback,
  });

  int get ovrDelta => currentOvr - startOvr;
}
